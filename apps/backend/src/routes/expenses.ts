import { Hono } from "hono";
import { z } from "zod";
import { sql } from "../db/client";

export const expenseRoutes = new Hono();

expenseRoutes.get("/", async (c) => {
  const user = c.get("user");
  const since = c.req.query("since");
  const status = c.req.query("status");

  const rows = await sql`
    SELECT * FROM expenses
    WHERE user_id = ${user.sub}
      ${since ? sql`AND updated_at > ${since}` : sql``}
      ${status ? sql`AND status = ${status}` : sql``}
    ORDER BY date DESC, created_at DESC
    LIMIT 500
  `;
  return c.json(rows);
});

expenseRoutes.get("/:id", async (c) => {
  const user = c.get("user");
  const id = c.req.param("id");
  const [row] = await sql`
    SELECT * FROM expenses WHERE id = ${id} AND user_id = ${user.sub}
  `;
  if (!row) return c.json({ error: "not_found" }, 404);
  return c.json(row);
});

const PatchSchema = z.object({
  vendor: z.string().optional(),
  cif: z.string().nullable().optional(),
  date: z.string().optional(),
  invoiceNumber: z.string().nullable().optional(),
  subtotal: z.number().optional(),
  ivaRate: z.number().optional(),
  ivaAmount: z.number().optional(),
  irpfRate: z.number().optional(),
  irpfAmount: z.number().optional(),
  total: z.number().optional(),
  category: z.string().optional(),
  status: z.enum(["pending", "confirmed", "rejected"]).optional(),
  notes: z.string().nullable().optional(),
});

expenseRoutes.patch("/:id", async (c) => {
  const user = c.get("user");
  const id = c.req.param("id");
  const body = PatchSchema.parse(await c.req.json());

  const [existing] = await sql`
    SELECT id FROM expenses WHERE id = ${id} AND user_id = ${user.sub}
  `;
  if (!existing) return c.json({ error: "not_found" }, 404);

  // Build dynamic update — one column at a time for clarity
  if (body.vendor !== undefined)
    await sql`UPDATE expenses SET vendor = ${body.vendor}, updated_at = NOW() WHERE id = ${id}`;
  if (body.cif !== undefined)
    await sql`UPDATE expenses SET cif = ${body.cif}, updated_at = NOW() WHERE id = ${id}`;
  if (body.date !== undefined)
    await sql`UPDATE expenses SET date = ${body.date}, updated_at = NOW() WHERE id = ${id}`;
  if (body.invoiceNumber !== undefined)
    await sql`UPDATE expenses SET invoice_number = ${body.invoiceNumber}, updated_at = NOW() WHERE id = ${id}`;
  if (body.subtotal !== undefined)
    await sql`UPDATE expenses SET subtotal = ${body.subtotal}, updated_at = NOW() WHERE id = ${id}`;
  if (body.ivaRate !== undefined)
    await sql`UPDATE expenses SET iva_rate = ${body.ivaRate}, updated_at = NOW() WHERE id = ${id}`;
  if (body.ivaAmount !== undefined)
    await sql`UPDATE expenses SET iva_amount = ${body.ivaAmount}, updated_at = NOW() WHERE id = ${id}`;
  if (body.irpfRate !== undefined)
    await sql`UPDATE expenses SET irpf_rate = ${body.irpfRate}, updated_at = NOW() WHERE id = ${id}`;
  if (body.irpfAmount !== undefined)
    await sql`UPDATE expenses SET irpf_amount = ${body.irpfAmount}, updated_at = NOW() WHERE id = ${id}`;
  if (body.total !== undefined)
    await sql`UPDATE expenses SET total = ${body.total}, updated_at = NOW() WHERE id = ${id}`;
  if (body.category !== undefined)
    await sql`UPDATE expenses SET category = ${body.category}, updated_at = NOW() WHERE id = ${id}`;
  if (body.status !== undefined)
    await sql`UPDATE expenses SET status = ${body.status}, updated_at = NOW() WHERE id = ${id}`;
  if (body.notes !== undefined)
    await sql`UPDATE expenses SET notes = ${body.notes}, updated_at = NOW() WHERE id = ${id}`;

  const [row] = await sql`SELECT * FROM expenses WHERE id = ${id}`;
  return c.json(row);
});

expenseRoutes.delete("/:id", async (c) => {
  const user = c.get("user");
  const id = c.req.param("id");
  await sql`DELETE FROM expenses WHERE id = ${id} AND user_id = ${user.sub}`;
  return c.json({ ok: true });
});
