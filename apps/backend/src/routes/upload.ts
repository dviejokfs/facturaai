import { Hono } from "hono";
import { sql } from "../db/client";
import { extractAuto } from "../services/extract";
import { uploadFile, keyForUpload } from "../services/storage";

export const uploadRoutes = new Hono();

uploadRoutes.post("/", async (c) => {
  const user = c.get("user");
  const form = await c.req.formData();
  const file = form.get("file");
  if (!(file instanceof File)) {
    return c.json({ error: "file field required" }, 400);
  }

  const bytes = Buffer.from(await file.arrayBuffer());
  const mime = file.type || "application/octet-stream";

  let extracted;
  try {
    extracted = await extractAuto(bytes, mime);
  } catch (err) {
    return c.json({ error: "extraction_failed", details: String(err) }, 422);
  }

  if (!extracted.isValidInvoice) {
    return c.json({ error: "not_an_invoice" }, 422);
  }

  const key = keyForUpload(user.sub, file.name || "upload");
  await uploadFile(key, bytes, mime);

  const [row] = await sql`
    INSERT INTO expenses (
      user_id, vendor, cif, date, invoice_number,
      subtotal, iva_rate, iva_amount, irpf_rate, irpf_amount, total,
      currency, category, status, confidence, source, attachment_key
    ) VALUES (
      ${user.sub}, ${extracted.vendor}, ${extracted.cif}, ${extracted.date},
      ${extracted.invoiceNumber}, ${extracted.subtotal}, ${extracted.ivaRate},
      ${extracted.ivaAmount}, ${extracted.irpfRate}, ${extracted.irpfAmount},
      ${extracted.total}, ${extracted.currency}, ${extracted.category},
      'pending', ${extracted.confidence}, 'camera', ${key}
    )
    RETURNING *
  `;

  return c.json(row);
});
