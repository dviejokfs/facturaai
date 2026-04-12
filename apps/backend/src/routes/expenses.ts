import { Hono } from "hono";
import { z } from "zod";
import { sql } from "../db/client";
import { serializeExpense, serializeExpenses } from "../db/serialize";
import { downloadFile } from "../services/storage";

export const expenseRoutes = new Hono();

expenseRoutes.get("/", async (c) => {
  const user = c.get("user");
  const since = c.req.query("since");
  const status = c.req.query("status");
  const type = c.req.query("type"); // 'expense' | 'income'
  const companyId = c.req.query("company_id");

  const rows = await sql`
    SELECT * FROM expenses
    WHERE user_id = ${user.sub}
      ${since ? sql`AND updated_at > ${since}` : sql``}
      ${status ? sql`AND status = ${status}` : sql``}
      ${type ? sql`AND type = ${type}` : sql``}
      ${companyId ? sql`AND company_id = ${companyId}` : sql``}
    ORDER BY date DESC, created_at DESC
    LIMIT 500
  `;
  return c.json(serializeExpenses(rows as Record<string, unknown>[]));
});

expenseRoutes.get("/:id", async (c) => {
  const user = c.get("user");
  const id = c.req.param("id");
  const [row] = await sql`
    SELECT * FROM expenses WHERE id = ${id} AND user_id = ${user.sub}
  `;
  if (!row) return c.json({ error: "not_found" }, 404);
  return c.json(serializeExpense(row as Record<string, unknown>));
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
  type: z.enum(["expense", "income"]).optional(),
});

expenseRoutes.patch("/:id", async (c) => {
  const user = c.get("user");
  const id = c.req.param("id");
  const body = PatchSchema.parse(await c.req.json());

  const [existing] = await sql`
    SELECT id FROM expenses WHERE id = ${id} AND user_id = ${user.sub}
  `;
  if (!existing) return c.json({ error: "not_found" }, 404);

  // Map camelCase body keys to snake_case DB columns
  const fieldMap: Record<string, string> = {
    vendor: "vendor", cif: "cif", date: "date",
    invoiceNumber: "invoice_number", subtotal: "subtotal",
    ivaRate: "iva_rate", ivaAmount: "iva_amount",
    irpfRate: "irpf_rate", irpfAmount: "irpf_amount",
    total: "total", category: "category", status: "status", notes: "notes",
    type: "type",
  };

  const sets: string[] = [];
  const values: unknown[] = [];
  for (const [key, col] of Object.entries(fieldMap)) {
    if (body[key as keyof typeof body] !== undefined) {
      sets.push(`${col} = $${sets.length + 1}`);
      values.push(body[key as keyof typeof body]);
    }
  }

  if (sets.length === 0) {
    const [row] = await sql`SELECT * FROM expenses WHERE id = ${id}`;
    return c.json(serializeExpense(row as Record<string, unknown>));
  }

  sets.push("updated_at = NOW()");
  const [row] = await sql.unsafe(
    `UPDATE expenses SET ${sets.join(", ")} WHERE id = $${values.length + 1} AND user_id = $${values.length + 2} RETURNING *`,
    [...values, id, user.sub],
  );
  return c.json(serializeExpense(row as Record<string, unknown>));
});

expenseRoutes.get("/:id/attachment", async (c) => {
  const user = c.get("user");
  const id = c.req.param("id");
  const [row] = await sql`
    SELECT attachment_key FROM expenses WHERE id = ${id} AND user_id = ${user.sub}
  `;
  if (!row) return c.json({ error: "not_found" }, 404);
  const key = row.attachment_key as string | null;
  if (!key) return c.json({ error: "no_attachment" }, 404);

  try {
    const buf = await downloadFile(key);
    const ext = key.split(".").pop()?.toLowerCase() ?? "";
    const contentType =
      ext === "pdf" ? "application/pdf" :
      ext === "png" ? "image/png" :
      ext === "heic" ? "image/heic" :
      "image/jpeg";
    return new Response(buf, {
      headers: {
        "Content-Type": contentType,
        "Content-Disposition": `inline; filename="${key.split("/").pop()}"`,
      },
    });
  } catch (err: any) {
    console.error("[attachment] download error:", err);
    const isNotFound = err?.name === "NoSuchKey" || err?.$metadata?.httpStatusCode === 404;
    if (isNotFound) {
      return c.json({ error: "file_not_found", message: "File not found in storage" }, 404);
    }
    return c.json({ error: "download_failed", message: err?.message ?? "Storage error" }, 500);
  }
});

expenseRoutes.delete("/:id", async (c) => {
  const user = c.get("user");
  const id = c.req.param("id");
  await sql`DELETE FROM expenses WHERE id = ${id} AND user_id = ${user.sub}`;
  return c.json({ ok: true });
});
