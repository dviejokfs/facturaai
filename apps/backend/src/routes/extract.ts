import { Hono } from "hono";
import { extractAuto } from "../services/extract";
import { signAnonymousToken, verifyToken } from "../auth/jwt";
import { sql } from "../db/client";
import { MAX_UPLOAD_BYTES, tooLargePayload } from "../services/uploadLimits";

export const extractRoutes = new Hono();

const ANONYMOUS_EXTRACTION_LIMIT = 3;

/**
 * POST /api/extract
 *
 * Anonymous extraction endpoint for onboarding.
 * - If no Authorization header: creates an anonymous user, returns a temp JWT + extracted data.
 * - If Authorization header with anonymous token: reuses that user, checks rate limit.
 * - Rate limited to 3 extractions per anonymous user.
 */
extractRoutes.post("/", async (c) => {
  let userId: string;
  let currentExtractions: number;

  const authHeader = c.req.header("Authorization");

  if (authHeader?.startsWith("Bearer ")) {
    // Existing anonymous token — verify and reuse
    try {
      const payload = await verifyToken(authHeader.slice(7));
      userId = payload.sub;

      // Verify user exists and is anonymous
      const [user] = await sql`
        SELECT id, anonymous_extractions FROM users
        WHERE id = ${userId} AND is_anonymous = TRUE
      `;
      if (!user) {
        return c.json({ error: "invalid_anonymous_user" }, 401);
      }
      currentExtractions = user.anonymous_extractions;
    } catch {
      return c.json({ error: "invalid_token" }, 401);
    }
  } else {
    // No token — create a new anonymous user
    const [user] = await sql`
      INSERT INTO users (is_anonymous, anonymous_extractions)
      VALUES (TRUE, 0)
      RETURNING id, anonymous_extractions
    `;
    userId = user.id;
    currentExtractions = 0;
  }

  // Rate limit check
  if (currentExtractions >= ANONYMOUS_EXTRACTION_LIMIT) {
    return c.json(
      {
        error: "rate_limited",
        message: "Free extraction limit reached. Sign in to continue.",
        limit: ANONYMOUS_EXTRACTION_LIMIT,
      },
      429,
    );
  }

  // Reject oversized uploads (Content-Length pre-check)
  const contentLength = parseInt(c.req.header("content-length") ?? "0", 10);
  if (contentLength > MAX_UPLOAD_BYTES) {
    return c.json(tooLargePayload(contentLength), 413);
  }

  // Parse the uploaded file
  const form = await c.req.formData();
  const file = form.get("file");
  if (!(file instanceof File)) {
    return c.json({ error: "file_required", message: "No file was attached to the request." }, 400);
  }

  const bytes = Buffer.from(await file.arrayBuffer());

  // Double-check actual file size after reading
  if (bytes.byteLength > MAX_UPLOAD_BYTES) {
    return c.json(tooLargePayload(bytes.byteLength), 413);
  }
  const mime = file.type || "application/octet-stream";

  // Company name hint for expense/income detection (sent by iOS from onboarding)
  const companyName = (form.get("company_name") as string | null) || null;

  // Also save company name to anonymous user if provided
  if (companyName) {
    await sql`UPDATE users SET company_name = ${companyName} WHERE id = ${userId}`;
  }

  // Sign token early so we can return it even on extraction failure
  const token = await signAnonymousToken(userId);

  let extracted;
  try {
    extracted = await extractAuto(bytes, mime, companyName);
  } catch (err) {
    console.error("[extract] anonymous extraction failed:", err);
    return c.json(
      { error: "extraction_failed", message: "Failed to extract invoice data. Please try a clearer image.", anonymous_token: token },
      422,
    );
  }

  if (!extracted.isValidInvoice) {
    return c.json(
      { error: "not_an_invoice", message: "The uploaded document does not appear to be an invoice or receipt.", anonymous_token: token },
      422,
    );
  }

  // Increment extraction count
  await sql`
    UPDATE users SET anonymous_extractions = anonymous_extractions + 1
    WHERE id = ${userId}
  `;

  // Determine type from AI's isExpense field
  const type = extracted.isExpense === false ? "income" : "expense";

  // Save the expense to DB so it can be merged later
  const expenseData = extracted as Record<string, any>;
  const [inserted] = await sql`
    INSERT INTO expenses (
      user_id, type, vendor, vendor_tax_id, client, client_tax_id, cif,
      date, invoice_number, subtotal, iva_rate, iva_amount,
      irpf_rate, irpf_amount, total, currency, category,
      confidence, source, status
    ) VALUES (
      ${userId},
      ${type},
      ${expenseData.vendor ?? "Unknown"},
      ${expenseData.vendorTaxId ?? null},
      ${expenseData.client ?? null},
      ${expenseData.clientTaxId ?? null},
      ${expenseData.vendorTaxId ?? expenseData.cif ?? null},
      ${expenseData.date ?? new Date().toISOString().slice(0, 10)},
      ${expenseData.invoiceNumber ?? null},
      ${expenseData.subtotal ?? 0},
      ${expenseData.ivaRate ?? 0},
      ${expenseData.ivaAmount ?? 0},
      ${expenseData.irpfRate ?? 0},
      ${expenseData.irpfAmount ?? 0},
      ${expenseData.total ?? 0},
      ${expenseData.currency ?? "EUR"},
      ${expenseData.category ?? "otros"},
      ${expenseData.confidence ?? 0},
      ${"camera"},
      ${"pending"}
    )
    RETURNING id, type
  `;

  // Return the DB row's id (and its actual type) so the client can PATCH it
  // later — e.g. to reclassify expense↔income once the user picks their company.
  return c.json({
    ...extracted,
    id: inserted.id,
    type: inserted.type,
    anonymous_token: token,
  });
});
