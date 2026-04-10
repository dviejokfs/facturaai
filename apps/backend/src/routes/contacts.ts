import { Hono } from "hono";
import { z } from "zod";
import { sql } from "../db/client";

export const contactRoutes = new Hono();

const ContactSchema = z.object({
  name: z.string().min(1),
  taxId: z.string().nullable().optional(),
  email: z.string().nullable().optional(),
  phone: z.string().nullable().optional(),
  address: z.string().nullable().optional(),
  notes: z.string().nullable().optional(),
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
