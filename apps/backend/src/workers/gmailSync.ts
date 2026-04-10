import { sql } from "../db/client";
import { listInvoiceMessageIds, getMessageAttachments } from "../services/gmail";
import { extractAuto } from "../services/extract";
import { uploadFile, keyForUpload } from "../services/storage";
import { resolveTransaction } from "../services/resolve";
import { sendPushToUser } from "../services/push";

/**
 * Reset any sync jobs that have been stuck in "running" state for more than 10 minutes.
 * Should be called before starting a new sync to recover from crashed workers.
 */
export async function recoverStuckSyncs(): Promise<number> {
  const result = await sql`
    UPDATE gmail_syncs
    SET status = 'idle', error = 'Reset: stuck for over 10 minutes', updated_at = NOW()
    WHERE status = 'running'
      AND updated_at < NOW() - INTERVAL '10 minutes'
    RETURNING id
  `;
  if (result.length > 0) {
    console.warn(`[gmailSync] Recovered ${result.length} stuck sync job(s): ${result.map((r: any) => r.id).join(", ")}`);
  }
  return result.length;
}

export async function runGmailSync(userId: string, syncId: string): Promise<void> {
  // Recover any stuck jobs before starting
  await recoverStuckSyncs();

  const [user] = await sql`
    SELECT id, google_access_token, google_refresh_token, company_name
    FROM users WHERE id = ${userId}
  `;
  if (!user) throw new Error("user not found");

  // Get last_sync_at to use as date filter
  const [sync] = await sql`
    SELECT last_sync_at FROM gmail_syncs WHERE id = ${syncId}
  `;
  const lastSyncAt: Date | null = sync?.last_sync_at ?? null;

  await sql`UPDATE gmail_syncs SET status = 'running', updated_at = NOW() WHERE id = ${syncId}`;

  try {
    // Phase 1: Get matching message IDs (paginated), filtered by last sync date
    const allRefs = await listInvoiceMessageIds(
      user.google_access_token,
      user.google_refresh_token,
      userId,
      lastSyncAt
    );

    console.log(`[gmailSync] Found ${allRefs.length} total emails matching invoice query`);

    // Filter out messages we've already processed (stored in expenses table)
    const existingIds = await sql`
      SELECT DISTINCT gmail_message_id FROM expenses
      WHERE user_id = ${userId} AND gmail_message_id IS NOT NULL
    `;
    const processedSet = new Set(existingIds.map((r: any) => r.gmail_message_id));
    const newRefs = allRefs.filter((ref) => !processedSet.has(ref.messageId));

    const total = newRefs.length;
    console.log(`[gmailSync] ${total} new emails to process (${processedSet.size} already synced)`);

    // Report total immediately so the client can show progress
    await sql`
      UPDATE gmail_syncs SET total_messages = ${total}, updated_at = NOW()
      WHERE id = ${syncId}
    `;

    if (total === 0) {
      await sql`
        UPDATE gmail_syncs
        SET status = 'completed', last_sync_at = NOW(),
            messages_processed = 0, invoices_found = 0,
            total_messages = 0, updated_at = NOW()
        WHERE id = ${syncId}
      `;
      return;
    }

    // Phase 2: Process each NEW message one by one
    let processed = 0;
    let found = 0;

    for (const ref of newRefs) {
      processed++;

      try {
        // Download attachments for this single message
        const attachments = await getMessageAttachments(
          user.google_access_token,
          user.google_refresh_token,
          ref.messageId,
          userId
        );

        for (const att of attachments) {
          try {
            const extracted = await extractAuto(att.data, att.mimeType, user.company_name as string | null);
            if (!extracted.isValidInvoice) continue;

            const resolved = await resolveTransaction(userId, extracted);

            const key = keyForUpload(userId, att.filename);
            try {
              await uploadFile(key, att.data, att.mimeType);
            } catch (err) {
              console.warn(`[gmailSync] S3 upload failed for ${att.filename} (continuing):`, err);
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
                ${att.messageId}, ${key}
              )
            `;
            found++;
          } catch (err) {
            console.error(`[gmailSync] Failed to extract ${att.filename} from msg ${ref.messageId}:`, err);
          }
        }
      } catch (err) {
        console.error(`[gmailSync] Failed to fetch attachments for msg ${ref.messageId}:`, err);
      }

      // Update progress after each message
      await sql`
        UPDATE gmail_syncs
        SET messages_processed = ${processed}, invoices_found = ${found}, updated_at = NOW()
        WHERE id = ${syncId}
      `;
    }

    await sql`
      UPDATE gmail_syncs
      SET status = 'completed', last_sync_at = NOW(),
          messages_processed = ${processed}, invoices_found = ${found},
          total_messages = ${total}, updated_at = NOW()
      WHERE id = ${syncId}
    `;

    console.log(`[gmailSync] Completed: ${found} invoices from ${processed} emails`);

    // Always send push notification on completion (app may be closed)
    const pushBody = found > 0
      ? `Found ${found} new invoice${found === 1 ? "" : "s"} from ${processed} emails`
      : `Scanned ${processed} emails — no new invoices found`;
    await sendPushToUser(userId, {
      title: "Gmail Sync Complete",
      body: pushBody,
      data: { action: "sync_complete", syncId },
    }).catch((err) => console.error("[gmailSync] Push notification failed:", err));
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    console.error(`[gmailSync] Fatal error:`, err);
    await sql`
      UPDATE gmail_syncs SET status = 'failed', error = ${msg}, updated_at = NOW()
      WHERE id = ${syncId}
    `;
    throw err;
  }
}
