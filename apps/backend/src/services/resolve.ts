import { sql } from "../db/client";
import type { ExtractedExpense } from "./extract";

export type ResolvedTransaction = {
  type: "expense" | "income";
  companyId: string | null;
  vendorContactId: string | null;
  clientContactId: string | null;
};

/**
 * After AI extraction, determine:
 * 1. Is this an expense or income? (from AI's isExpense field + server-side vendor/company match)
 * 2. Link or create vendor/client contacts
 * 3. Assign to default company if exists
 */
export async function resolveTransaction(
  userId: string,
  extracted: ExtractedExpense
): Promise<ResolvedTransaction> {
  // Start with AI's determination
  let type: "expense" | "income" = extracted.isExpense === false ? "income" : "expense";

  // Server-side override: if vendor matches user's company name, it's income
  const [userRow] = await sql`SELECT company_name FROM users WHERE id = ${userId}`;
  const companyName = (userRow?.company_name as string | null)?.trim().toLowerCase();
  if (companyName && extracted.vendor) {
    const vendorNorm = extracted.vendor.trim().toLowerCase();
    if (vendorNorm === companyName || vendorNorm.includes(companyName) || companyName.includes(vendorNorm)) {
      type = "income";
    }
  }

  // Find default company for the user
  const [defaultCompany] = await sql`
    SELECT id FROM companies WHERE user_id = ${userId} AND is_default = TRUE LIMIT 1
  `;
  const companyId: string | null = defaultCompany?.id ?? null;

  // Resolve contacts — auto-create from tax_ids
  let vendorContactId: string | null = null;
  let clientContactId: string | null = null;

  if (extracted.vendor && extracted.vendorTaxId) {
    vendorContactId = await findOrCreateContact(userId, extracted.vendor, extracted.vendorTaxId);
  }

  if (extracted.client && extracted.clientTaxId) {
    clientContactId = await findOrCreateContact(userId, extracted.client, extracted.clientTaxId);
  }

  console.log(`[resolve] vendor="${extracted.vendor}" company="${companyName}" ai_isExpense=${extracted.isExpense} → type=${type}`);
  return { type, companyId, vendorContactId, clientContactId };
}

/**
 * Find an existing contact by tax_id, or create a new one.
 * Uses ON CONFLICT to handle race conditions.
 */
async function findOrCreateContact(
  userId: string,
  name: string,
  taxId: string
): Promise<string> {
  const [existing] = await sql`
    SELECT id FROM contacts
    WHERE user_id = ${userId} AND tax_id = ${taxId}
  `;
  if (existing) {
    await sql`
      UPDATE contacts SET name = ${name}, updated_at = NOW()
      WHERE id = ${existing.id} AND name != ${name}
    `;
    return existing.id;
  }

  const [created] = await sql`
    INSERT INTO contacts (user_id, name, tax_id)
    VALUES (${userId}, ${name}, ${taxId})
    ON CONFLICT (user_id, tax_id) WHERE tax_id IS NOT NULL
    DO UPDATE SET name = EXCLUDED.name, updated_at = NOW()
    RETURNING id
  `;
  return created.id;
}
