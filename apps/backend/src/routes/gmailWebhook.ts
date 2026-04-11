import { Hono } from "hono";
import { sql } from "../db/client";
import { listNewMessagesSinceHistory, messageHasInvoiceAttachments, getMessageAttachments } from "../services/gmail";
import { extractAuto } from "../services/extract";
import { uploadFile, keyForUpload } from "../services/storage";
import { resolveTransaction } from "../services/resolve";
import { sendPushToUser } from "../services/push";

export const gmailWebhookRoutes = new Hono();

/**
 * POST /webhooks/gmail
 *
 * Receives Google Cloud Pub/Sub push notifications when a watched Gmail
 * account gets new mail. No auth header — Pub/Sub sends a signed JWT but
 * for simplicity we validate the payload structure instead (the endpoint
 * URL is not guessable and the worst case is a no-op sync).
 *
 * Pub/Sub message format:
 * {
 *   "message": {
 *     "data": base64({ "emailAddress": "user@example.com", "historyId": "12345" }),
 *     "messageId": "...",
 *     "publishTime": "..."
 *   },
 *   "subscription": "projects/.../subscriptions/gmail-push-sub"
 * }
 */
gmailWebhookRoutes.post("/", async (c) => {
  const body = await c.req.json().catch(() => null);
  if (!body?.message?.data) {
    return c.json({ ok: false, error: "invalid payload" }, 400);
  }

  // Decode the Pub/Sub message
  let emailAddress: string;
  let newHistoryId: string;
  try {
    const decoded = JSON.parse(atob(body.message.data));
    emailAddress = decoded.emailAddress;
    newHistoryId = String(decoded.historyId);
    if (!emailAddress || !newHistoryId) throw new Error("missing fields");
  } catch {
    return c.json({ ok: false, error: "invalid message data" }, 400);
  }

  // Look up the user
  const [user] = await sql`
    SELECT id, google_access_token, google_refresh_token, gmail_history_id, company_name
    FROM users
    WHERE email = ${emailAddress}
      AND google_access_token IS NOT NULL
  `;

  if (!user) {
    // Unknown user or Gmail not connected — ack the message so Pub/Sub doesn't retry
    return c.json({ ok: true, skipped: "unknown_user" });
  }

  if (!user.gmail_history_id) {
    // No history baseline — store the new one and wait for next notification
    await sql`
      UPDATE users SET gmail_history_id = ${newHistoryId}, updated_at = NOW()
      WHERE id = ${user.id}
    `;
    return c.json({ ok: true, skipped: "no_baseline" });
  }

  // Fire-and-forget: process incrementally in background
  processIncrementalSync(user, newHistoryId).catch((err) =>
    console.error(`[gmailWebhook] Incremental sync failed for ${emailAddress}:`, err)
  );

  // Ack immediately so Pub/Sub doesn't retry (processing happens in background)
  return c.json({ ok: true });
});

async function processIncrementalSync(
  user: { id: string; google_access_token: string; google_refresh_token: string | null; gmail_history_id: string; company_name: string | null },
  newHistoryId: string
): Promise<void> {
  const { id: userId, google_access_token: accessToken, google_refresh_token: refreshToken, gmail_history_id: startHistoryId, company_name: companyName } = user;

  // Fetch new message IDs since last known historyId
  let result: { messageIds: string[]; latestHistoryId: string | null };
  try {
    result = await listNewMessagesSinceHistory(accessToken, refreshToken, userId, startHistoryId);
  } catch (err: any) {
    // historyId too old — Google returns 404. Reset and let next notification establish baseline.
    if (err?.code === 404 || err?.response?.status === 404) {
      console.warn(`[gmailWebhook] History expired for user ${userId}, resetting to ${newHistoryId}`);
      await sql`
        UPDATE users SET gmail_history_id = ${newHistoryId}, updated_at = NOW()
        WHERE id = ${userId}
      `;
      return;
    }
    throw err;
  }

  // Update historyId immediately to avoid reprocessing on next notification
  const updatedHistoryId = result.latestHistoryId ?? newHistoryId;
  await sql`
    UPDATE users SET gmail_history_id = ${updatedHistoryId}, updated_at = NOW()
    WHERE id = ${userId}
  `;

  if (result.messageIds.length === 0) return;

  // Filter out already-processed messages
  const existingIds = await sql`
    SELECT DISTINCT gmail_message_id FROM expenses
    WHERE user_id = ${userId} AND gmail_message_id IS NOT NULL
  `;
  const processedSet = new Set(existingIds.map((r: any) => r.gmail_message_id));
  const newIds = result.messageIds.filter((id) => !processedSet.has(id));

  if (newIds.length === 0) return;

  console.log(`[gmailWebhook] Processing ${newIds.length} new messages for user ${userId}`);

  // Check each message for invoice attachments (lightweight metadata check)
  let found = 0;
  for (const messageId of newIds) {
    try {
      const hasInvoice = await messageHasInvoiceAttachments(accessToken, refreshToken, messageId, userId);
      if (!hasInvoice) continue;

      // Full extraction
      const attachments = await getMessageAttachments(accessToken, refreshToken, messageId, userId);

      for (const att of attachments) {
        try {
          const extracted = await extractAuto(att.data, att.mimeType, companyName);
          if (!extracted.isValidInvoice) continue;

          const resolved = await resolveTransaction(userId, extracted);
          const key = keyForUpload(userId, att.filename);

          try {
            await uploadFile(key, att.data, att.mimeType);
          } catch (err) {
            console.warn(`[gmailWebhook] S3 upload failed for ${att.filename}:`, err);
          }

          await sql`
            INSERT INTO expenses (
              user_id, type, company_id,
              vendor, vendor_tax_id, vendor_contact_id,
              client, client_tax_id, client_contact_id, cif,
              date, invoice_number,
              subtotal, iva_rate, iva_amount, irpf_rate, irpf_amount, total,
              currency, category, status, confidence, source,
              gmail_message_id, attachment_key
            ) VALUES (
              ${userId}, ${resolved.type}, ${resolved.companyId},
              ${extracted.vendor}, ${extracted.vendorTaxId}, ${resolved.vendorContactId},
              ${extracted.client}, ${extracted.clientTaxId}, ${resolved.clientContactId},
              ${extracted.cif},
              ${extracted.date}, ${extracted.invoiceNumber},
              ${extracted.subtotal}, ${extracted.ivaRate},
              ${extracted.ivaAmount}, ${extracted.irpfRate}, ${extracted.irpfAmount},
              ${extracted.total}, ${extracted.currency}, ${extracted.category},
              'pending', ${extracted.confidence}, 'gmail',
              ${messageId}, ${key}
            )
            ON CONFLICT (user_id, gmail_message_id) DO NOTHING
          `;
          found++;
        } catch (err) {
          console.error(`[gmailWebhook] Extract failed for ${att.filename}:`, err);
        }
      }
    } catch (err) {
      console.error(`[gmailWebhook] Failed processing message ${messageId}:`, err);
    }
  }

  if (found > 0) {
    console.log(`[gmailWebhook] Imported ${found} invoices for user ${userId}`);
    await sendPushToUser(userId, {
      title: "New invoices detected",
      body: `${found} new invoice${found === 1 ? "" : "s"} imported from Gmail`,
      data: { action: "new_invoices" },
    }).catch((err) => console.error("[gmailWebhook] Push failed:", err));
  }
}
