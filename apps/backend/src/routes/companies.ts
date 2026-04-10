import { Hono } from "hono";
import { z } from "zod";
import { sql } from "../db/client";

export const companyRoutes = new Hono();

const CompanySchema = z.object({
  name: z.string().min(1),
  taxId: z.string().min(1),
  taxIdType: z.string().nullable().optional(),
  address: z.string().nullable().optional(),
  isDefault: z.boolean().optional(),
});

companyRoutes.get("/", async (c) => {
  const user = c.get("user");
  const rows = await sql`
    SELECT * FROM companies WHERE user_id = ${user.sub} ORDER BY is_default DESC, name
  `;
  return c.json(rows);
});

companyRoutes.post("/", async (c) => {
  const user = c.get("user");
  const body = CompanySchema.parse(await c.req.json());

  // If this is the first company or isDefault, clear other defaults
  if (body.isDefault) {
    await sql`UPDATE companies SET is_default = FALSE WHERE user_id = ${user.sub}`;
  }

  const [existing] = await sql`
    SELECT COUNT(*)::int as count FROM companies WHERE user_id = ${user.sub}
  `;
  const isFirst = existing.count === 0;

  const [row] = await sql`
    INSERT INTO companies (user_id, name, tax_id, tax_id_type, address, is_default)
    VALUES (${user.sub}, ${body.name}, ${body.taxId}, ${body.taxIdType ?? null},
            ${body.address ?? null}, ${body.isDefault || isFirst})
    RETURNING *
  `;
  return c.json(row, 201);
});

companyRoutes.patch("/:id", async (c) => {
  const user = c.get("user");
  const id = c.req.param("id");
  const body = CompanySchema.partial().parse(await c.req.json());

  const [existing] = await sql`
    SELECT id FROM companies WHERE id = ${id} AND user_id = ${user.sub}
  `;
  if (!existing) return c.json({ error: "not_found" }, 404);

  if (body.isDefault) {
    await sql`UPDATE companies SET is_default = FALSE WHERE user_id = ${user.sub}`;
  }

  if (body.name !== undefined)
    await sql`UPDATE companies SET name = ${body.name}, updated_at = NOW() WHERE id = ${id}`;
  if (body.taxId !== undefined)
    await sql`UPDATE companies SET tax_id = ${body.taxId}, updated_at = NOW() WHERE id = ${id}`;
  if (body.taxIdType !== undefined)
    await sql`UPDATE companies SET tax_id_type = ${body.taxIdType ?? null}, updated_at = NOW() WHERE id = ${id}`;
  if (body.address !== undefined)
    await sql`UPDATE companies SET address = ${body.address ?? null}, updated_at = NOW() WHERE id = ${id}`;
  if (body.isDefault !== undefined)
    await sql`UPDATE companies SET is_default = ${body.isDefault}, updated_at = NOW() WHERE id = ${id}`;

  const [row] = await sql`SELECT * FROM companies WHERE id = ${id}`;
  return c.json(row);
});

companyRoutes.delete("/:id", async (c) => {
  const user = c.get("user");
  const id = c.req.param("id");
  await sql`DELETE FROM companies WHERE id = ${id} AND user_id = ${user.sub}`;
  return c.json({ ok: true });
});
