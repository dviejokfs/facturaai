import { Hono } from "hono";
import { z } from "zod";
import { sql } from "../db/client";
import { serializeExpense } from "../db/serialize";

export const contactRoutes = new Hono();

const ContactSchema = z.object({
  name: z.string().min(1),
  taxId: z.string().nullable().optional(),
  email: z.string().nullable().optional(),
  phone: z.string().nullable().optional(),
  address: z.string().nullable().optional(),
  notes: z.string().nullable().optional(),
});

/**
 * List counterparties (vendors + clients) aggregated straight from expenses.
 *
 * Each row is a distinct `(name, tax_id)` pair with per-transaction-type stats
 * so the iOS app can render "Jason Crawforth — 5 invoices · 12.000 €" etc.
 *
 * Filters:
 *   - role=vendor → only counterparties we've bought from (user's expenses)
 *   - role=client → only counterparties we've invoiced (user's income)
 *   - role omitted → both, merged on (name, tax_id)
 *   - q=<term>    → case-insensitive substring on name or tax_id
 */
contactRoutes.get("/counterparties", async (c) => {
  const user = c.get("user");
  const role = c.req.query("role"); // "vendor" | "client" | undefined
  const q = c.req.query("q");
  const pattern = q ? `%${q}%` : null;

  // Pagination — default 50, hard cap 200.
  const limit = Math.min(
    Math.max(parseInt(c.req.query("limit") ?? "50", 10) || 50, 1),
    200,
  );
  const offset = Math.max(parseInt(c.req.query("offset") ?? "0", 10) || 0, 0);

  // Single-pass aggregation:
  //   1. `parties` flattens each expense into one row per "side" we care about
  //      (vendor for expenses, client for income). Rejected rows are dropped.
  //   2. `by_ccy` groups on (name, tax_id, currency) in one pass — no
  //      correlated subquery, so this scales linearly with rows, not N*M.
  //   3. The outer SELECT rolls currencies into a JSON array per counterparty.
  // Indexes `idx_expenses_user_vendor` and `idx_expenses_user_client` back
  // the user_id + grouping-key lookups; trigram GIN indexes back the ILIKE.
  const rows = await sql`
    WITH parties AS (
      SELECT
        CASE WHEN type = 'income' THEN COALESCE(client, '') ELSE vendor END AS name,
        CASE WHEN type = 'income' THEN client_tax_id ELSE vendor_tax_id END AS tax_id,
        CASE WHEN type = 'income' THEN 'client' ELSE 'vendor' END AS party_role,
        currency,
        total,
        date,
        type
      FROM expenses
      WHERE user_id = ${user.sub}
        AND status <> 'rejected'
    ),
    filtered AS (
      SELECT * FROM parties
      WHERE name <> ''
        AND (${role ?? null}::text IS NULL OR party_role = ${role ?? null}::text)
        AND (${pattern}::text IS NULL OR name ILIKE ${pattern}::text OR COALESCE(tax_id, '') ILIKE ${pattern}::text)
    ),
    by_ccy AS (
      SELECT
        name,
        tax_id,
        currency,
        COALESCE(SUM(total) FILTER (WHERE type = 'expense'), 0) AS expense_total,
        COALESCE(SUM(total) FILTER (WHERE type = 'income'), 0) AS income_total,
        COUNT(*) AS n,
        COUNT(*) FILTER (WHERE type = 'expense') AS expense_n,
        COUNT(*) FILTER (WHERE type = 'income') AS income_n,
        COUNT(*) FILTER (WHERE party_role = 'vendor') AS vendor_n,
        COUNT(*) FILTER (WHERE party_role = 'client') AS client_n,
        MAX(date) AS last_date
      FROM filtered
      GROUP BY name, tax_id, currency
    )
    SELECT
      name,
      tax_id,
      CASE
        WHEN SUM(vendor_n) > 0 AND SUM(client_n) > 0 THEN 'both'
        WHEN SUM(vendor_n) > 0 THEN 'vendor'
        ELSE 'client'
      END AS role,
      SUM(n)::int         AS invoice_count,
      SUM(expense_n)::int AS expense_count,
      SUM(income_n)::int  AS income_count,
      json_agg(json_build_object(
        'currency', currency,
        'expense_total', expense_total,
        'income_total', income_total
      ) ORDER BY currency) AS totals_by_currency,
      MAX(last_date)::text AS last_invoice_date
    FROM by_ccy
    GROUP BY name, tax_id
    ORDER BY MAX(last_date) DESC NULLS LAST, name
    LIMIT ${limit} OFFSET ${offset}
  `;

  return c.json(rows);
});

contactRoutes.get("/", async (c) => {
  const user = c.get("user");
  const q = c.req.query("q");

  let rows;
  if (q) {
    const pattern = `%${q}%`;
    rows = await sql`
      SELECT * FROM contacts
      WHERE user_id = ${user.sub}
        AND (name ILIKE ${pattern} OR tax_id ILIKE ${pattern} OR email ILIKE ${pattern})
      ORDER BY name
      LIMIT 100
    `;
  } else {
    rows = await sql`
      SELECT * FROM contacts WHERE user_id = ${user.sub} ORDER BY name LIMIT 200
    `;
  }
  return c.json(rows);
});

/**
 * Invoices for a given counterparty. Identified by name (+ optional tax_id,
 * since two suppliers may share a name but never a tax id).
 *
 *   GET /contacts/counterparties/invoices?name=Foo&taxId=B12345678
 */
contactRoutes.get("/counterparties/invoices", async (c) => {
  const user = c.get("user");
  const name = c.req.query("name");
  const taxId = c.req.query("taxId");
  if (!name) return c.json({ error: "name_required" }, 400);

  const rows = await sql`
    SELECT * FROM expenses
    WHERE user_id = ${user.sub}
      AND status <> 'rejected'
      AND (
        (type = 'expense' AND vendor = ${name}
          AND (${taxId ?? null}::text IS NULL OR vendor_tax_id = ${taxId ?? null}::text))
        OR
        (type = 'income' AND client = ${name}
          AND (${taxId ?? null}::text IS NULL OR client_tax_id = ${taxId ?? null}::text))
      )
    ORDER BY date DESC
    LIMIT 500
  `;
  return c.json(rows.map((r: Record<string, unknown>) => serializeExpense(r)));
});

contactRoutes.get("/:id", async (c) => {
  const user = c.get("user");
  const id = c.req.param("id");
  const [row] = await sql`
    SELECT * FROM contacts WHERE id = ${id} AND user_id = ${user.sub}
  `;
  if (!row) return c.json({ error: "not_found" }, 404);
  return c.json(row);
});

contactRoutes.post("/", async (c) => {
  const user = c.get("user");
  const body = ContactSchema.parse(await c.req.json());

  const [row] = await sql`
    INSERT INTO contacts (user_id, name, tax_id, email, phone, address, notes)
    VALUES (${user.sub}, ${body.name}, ${body.taxId ?? null}, ${body.email ?? null},
            ${body.phone ?? null}, ${body.address ?? null}, ${body.notes ?? null})
    RETURNING *
  `;
  return c.json(row, 201);
});

contactRoutes.patch("/:id", async (c) => {
  const user = c.get("user");
  const id = c.req.param("id");
  const body = ContactSchema.partial().parse(await c.req.json());

  const [existing] = await sql`
    SELECT id FROM contacts WHERE id = ${id} AND user_id = ${user.sub}
  `;
  if (!existing) return c.json({ error: "not_found" }, 404);

  if (body.name !== undefined)
    await sql`UPDATE contacts SET name = ${body.name}, updated_at = NOW() WHERE id = ${id}`;
  if (body.taxId !== undefined)
    await sql`UPDATE contacts SET tax_id = ${body.taxId ?? null}, updated_at = NOW() WHERE id = ${id}`;
  if (body.email !== undefined)
    await sql`UPDATE contacts SET email = ${body.email ?? null}, updated_at = NOW() WHERE id = ${id}`;
  if (body.phone !== undefined)
    await sql`UPDATE contacts SET phone = ${body.phone ?? null}, updated_at = NOW() WHERE id = ${id}`;
  if (body.address !== undefined)
    await sql`UPDATE contacts SET address = ${body.address ?? null}, updated_at = NOW() WHERE id = ${id}`;
  if (body.notes !== undefined)
    await sql`UPDATE contacts SET notes = ${body.notes ?? null}, updated_at = NOW() WHERE id = ${id}`;

  const [row] = await sql`SELECT * FROM contacts WHERE id = ${id}`;
  return c.json(row);
});

contactRoutes.delete("/:id", async (c) => {
  const user = c.get("user");
  const id = c.req.param("id");
  await sql`DELETE FROM contacts WHERE id = ${id} AND user_id = ${user.sub}`;
  return c.json({ ok: true });
});
