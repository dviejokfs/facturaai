import { sql } from "../db/client";
import { listInvoiceAttachments } from "../services/gmail";
import { extractAuto } from "../services/extract";
import { uploadFile, keyForUpload } from "../services/storage";

export async function runGmailSync(userId: string, syncId: string): Promise<void> {
  const [user] = await sql`
    SELECT id, google_access_token, google_refresh_token
    FROM users WHERE id = ${userId}
  `;
  if (!user) throw new Error("user not found");

  await sql`UPDATE gmail_syncs SET status = 'running', updated_at = NOW() WHERE id = ${syncId}`;

  try {
    const attachments = await listInvoiceAttachments(
      user.google_access_token,
      user.google_refresh_token
    );

    let processed = 0;
    let found = 0;

    for (const att of attachments) {
      processed++;

      // Dedupe: skip if we already have this message
      const [existing] = await sql`
        SELECT id FROM expenses
        WHERE user_id = ${userId} AND gmail_message_id = ${att.messageId}
        LIMIT 1
      `;
      if (existing) continue;

      try {
        const extracted = await extractAuto(att.data, att.mimeType);
        if (!extracted.isValidInvoice) continue;

        const key = keyForUpload(userId, att.filename);
        await uploadFile(key, att.data, att.mimeType);

        await sql`
          INSERT INTO expenses (
            user_id, vendor, cif, date, invoice_number,
            subtotal, iva_rate, iva_amount, irpf_rate, irpf_amount, total,
            currency, category, status, confidence, source,
            gmail_message_id, attachment_key
          ) VALUES (
            ${userId}, ${extracted.vendor}, ${extracted.cif}, ${extracted.date},
            ${extracted.invoiceNumber}, ${extracted.subtotal}, ${extracted.ivaRate},
            ${extracted.ivaAmount}, ${extracted.irpfRate}, ${extracted.irpfAmount},
            ${extracted.total}, ${extracted.currency}, ${extracted.category},
            'pending', ${extracted.confidence}, 'gmail',
            ${att.messageId}, ${key}
          )
        `;
        found++;
      } catch (err) {
        console.error(`Failed to process attachment from msg ${att.messageId}:`, err);
      }
    }

    await sql`
      UPDATE gmail_syncs
      SET status = 'completed', last_sync_at = NOW(),
          messages_processed = ${processed}, invoices_found = ${found},
          updated_at = NOW()
      WHERE id = ${syncId}
    `;
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    await sql`
      UPDATE gmail_syncs SET status = 'failed', error = ${msg}, updated_at = NOW()
      WHERE id = ${syncId}
    `;
    throw err;
  }
}
