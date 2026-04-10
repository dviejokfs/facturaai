import { Hono } from "hono";
import { sql } from "../db/client";
import { serializeExpense } from "../db/serialize";
import { extractAuto } from "../services/extract";
import { uploadFile, keyForUpload } from "../services/storage";
import { resolveTransaction } from "../services/resolve";
import { checkScanLimit } from "../services/entitlements";

export const uploadRoutes = new Hono();

uploadRoutes.post("/", async (c) => {
  const user = c.get("user");

  // Enforce scan limit for free/trial users
  const scanCheck = await checkScanLimit(user.sub);
  if (!scanCheck.allowed) {
    return c.json(
      { error: scanCheck.error, message: scanCheck.message, upgrade: scanCheck.upgrade },
      scanCheck.status as 403,
    );
  }

  // Reject oversized uploads (20 MB max)
  const contentLength = parseInt(c.req.header("content-length") ?? "0", 10);
  if (contentLength > 20 * 1024 * 1024) {
    return c.json({ error: "file_too_large", message: "Maximum upload size is 20 MB" }, 413);
  }

  const form = await c.req.formData();
  const file = form.get("file");
  if (!(file instanceof File)) {
    return c.json({ error: "file field required" }, 400);
  }

  const bytes = Buffer.from(await file.arrayBuffer());

  // Double-check actual file size after reading
  if (bytes.byteLength > 20 * 1024 * 1024) {
    return c.json({ error: "file_too_large", message: "Maximum upload size is 20 MB" }, 413);
  }
  const mime = file.type || "application/octet-stream";

  // Fetch user's company name for expense/income detection
  const [userRow] = await sql`SELECT company_name FROM users WHERE id = ${user.sub}`;
  const companyName = userRow?.company_name as string | null;

  let extracted;
  try {
    extracted = await extractAuto(bytes, mime, companyName);
  } catch (err) {
    return c.json({ error: "extraction_failed", details: String(err) }, 422);
  }

  if (!extracted.isValidInvoice) {
    return c.json({ error: "not_an_invoice", message: "The uploaded document does not appear to be an invoice or receipt." }, 422);
  }

  const key = keyForUpload(user.sub, file.name || "upload");
  let attachmentKey: string | null = null;
  try {
    await uploadFile(key, bytes, mime);
    attachmentKey = key;
  } catch (err) {
    console.warn("[upload] S3 upload failed (continuing without attachment):", err);
  }

  const resolved = await resolveTransaction(user.sub, extracted);

  const [row] = await sql`
    INSERT INTO expenses (
      user_id, type, company_id, vendor, vendor_tax_id, vendor_contact_id,
      client, client_tax_id, client_contact_id, cif,
      date, invoice_number,
      subtotal, iva_rate, iva_amount, irpf_rate, irpf_amount, total,
      currency, category, status, confidence, source, attachment_key
    ) VALUES (
      ${user.sub}, ${resolved.type}, ${resolved.companyId},
      ${extracted.vendor}, ${extracted.vendorTaxId}, ${resolved.vendorContactId},
      ${extracted.client}, ${extracted.clientTaxId}, ${resolved.clientContactId},
      ${extracted.cif},
      ${extracted.date}, ${extracted.invoiceNumber},
      ${extracted.subtotal}, ${extracted.ivaRate},
      ${extracted.ivaAmount}, ${extracted.irpfRate}, ${extracted.irpfAmount},
      ${extracted.total}, ${extracted.currency}, ${extracted.category},
      'pending', ${extracted.confidence}, 'camera', ${attachmentKey}
    )
    RETURNING *
  `;

  return c.json(serializeExpense(row as Record<string, unknown>));
});
