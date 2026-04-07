import { Hono } from "hono";
import { sql } from "../db/client";

export const exportRoutes = new Hono();

function csvEscape(s: string): string {
  if (s.includes(",") || s.includes("\"") || s.includes("\n")) {
    return `"${s.replace(/"/g, '""')}"`;
  }
  return s;
}

function quarterBounds(quarter: string): { start: string; end: string } {
  // "2026-Q2" → 2026-04-01..2026-07-01
  const [yearStr, qStr] = quarter.split("-Q");
  const year = parseInt(yearStr);
  const q = parseInt(qStr);
  const startMonth = (q - 1) * 3;
  const start = new Date(Date.UTC(year, startMonth, 1));
  const end = new Date(Date.UTC(year, startMonth + 3, 1));
  return { start: start.toISOString().slice(0, 10), end: end.toISOString().slice(0, 10) };
}

exportRoutes.get("/csv", async (c) => {
  const user = c.get("user");
  const quarter = c.req.query("quarter");
  if (!quarter) return c.json({ error: "quarter required (e.g., 2026-Q2)" }, 400);

  const { start, end } = quarterBounds(quarter);
  const rows = await sql`
    SELECT vendor, cif, date, invoice_number, subtotal, iva_rate, iva_amount,
           irpf_rate, irpf_amount, total, category, status
    FROM expenses
    WHERE user_id = ${user.sub}
      AND date >= ${start} AND date < ${end}
      AND status != 'rejected'
    ORDER BY date ASC
  `;

  const header = "Fecha,Proveedor,CIF,NumFactura,Subtotal,IVA%,IVA,IRPF%,IRPF,Total,Categoria,Estado";
  const lines = [header];
  for (const r of rows) {
    lines.push(
      [
        String(r.date).slice(0, 10),
        csvEscape(r.vendor ?? ""),
        r.cif ?? "",
        r.invoice_number ?? "",
        r.subtotal,
        r.iva_rate,
        r.iva_amount,
        r.irpf_rate,
        r.irpf_amount,
        r.total,
        csvEscape(r.category ?? ""),
        r.status,
      ].join(",")
    );
  }

  return new Response(lines.join("\n"), {
    headers: {
      "Content-Type": "text/csv; charset=utf-8",
      "Content-Disposition": `attachment; filename="facturaai-${quarter}.csv"`,
    },
  });
});

exportRoutes.get("/summary/:quarter", async (c) => {
  const user = c.get("user");
  const quarter = c.req.param("quarter");
  const { start, end } = quarterBounds(quarter);

  const [totals] = await sql`
    SELECT
      COUNT(*)::int AS count,
      COALESCE(SUM(subtotal), 0) AS subtotal,
      COALESCE(SUM(iva_amount), 0) AS iva,
      COALESCE(SUM(total), 0) AS total
    FROM expenses
    WHERE user_id = ${user.sub}
      AND date >= ${start} AND date < ${end}
      AND status != 'rejected'
  `;

  const byCategory = await sql`
    SELECT category, COALESCE(SUM(total), 0) AS total
    FROM expenses
    WHERE user_id = ${user.sub}
      AND date >= ${start} AND date < ${end}
      AND status != 'rejected'
    GROUP BY category
    ORDER BY total DESC
  `;

  return c.json({ quarter, totals, byCategory });
});
