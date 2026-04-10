import { Hono } from "hono";
import { zipSync, strToU8 } from "fflate";
import ExcelJS from "exceljs";
import { sql } from "../db/client";
import { downloadFile, uploadFile } from "../services/storage";
import {
  resolveLocale,
  formatCurrency,
  formatDate,
  formatNumber,
  excelNumberFormat,
  type LocaleStrings,
} from "../i18n";
import { checkProAccess } from "../services/entitlements";
import { sendExportEmail } from "../services/email";

export const exportRoutes = new Hono();

// Public route mounted separately at /e/:token — see shareDownloadRoute below.
export const shareDownloadRoute = new Hono();

// ─── helpers ────────────────────────────────────────────────────────────────

function csvEscape(s: string, delimiter: string): string {
  if (s == null) return "";
  if (s.includes(delimiter) || s.includes('"') || s.includes("\n")) {
    return `"${s.replace(/"/g, '""')}"`;
  }
  return s;
}

function quarterBounds(quarter: string): { start: string; end: string } {
  const [yearStr, qStr] = quarter.split("-Q");
  const year = parseInt(yearStr!);
  const q = parseInt(qStr!);
  const startMonth = (q - 1) * 3;
  const start = new Date(Date.UTC(year, startMonth, 1));
  const end = new Date(Date.UTC(year, startMonth + 3, 1));
  return {
    start: start.toISOString().slice(0, 10),
    end: end.toISOString().slice(0, 10),
  };
}

type ExpenseRow = {
  id: string;
  vendor: string;
  cif: string | null;
  date: string;
  invoice_number: string | null;
  subtotal: string;
  iva_rate: string;
  iva_amount: string;
  irpf_rate: string;
  irpf_amount: string;
  total: string;
  currency: string;
  category: string;
  status: string;
  attachment_key: string | null;
};

function safeFileName(s: string, max = 60): string {
  return s
    .replace(/[^a-zA-Z0-9._-]+/g, "_")
    .replace(/^_+|_+$/g, "")
    .slice(0, max);
}

function attachmentExt(key: string): string {
  const lower = key.toLowerCase();
  if (lower.endsWith(".pdf")) return "pdf";
  if (lower.endsWith(".png")) return "png";
  if (lower.endsWith(".jpg") || lower.endsWith(".jpeg")) return "jpg";
  if (lower.endsWith(".webp")) return "webp";
  return "bin";
}

// ─── CSV builders (locale-aware + universal English fallback) ───────────────

/**
 * Localized CSV: per-locale delimiter and decimal separator. This is the file
 * the user double-clicks in their own copy of Excel.
 */
function buildLocalizedCsv(rows: ExpenseRow[], loc: LocaleStrings): string {
  const d = loc.csvDelimiter;
  const L = loc.labels;
  const header = [
    L.date, L.supplier, L.taxId, L.invoiceNumber,
    L.base, `${L.tax} %`, L.tax, L.total, "Currency", L.category,
  ].join(d);

  const lines = [header];
  for (const r of rows) {
    lines.push(
      [
        formatDate(String(r.date).slice(0, 10), loc),
        csvEscape(r.vendor ?? "", d),
        csvEscape(r.cif ?? "", d),
        csvEscape(r.invoice_number ?? "", d),
        formatNumber(parseFloat(r.subtotal), loc),
        formatNumber(parseFloat(r.iva_rate), loc),
        formatNumber(parseFloat(r.iva_amount), loc),
        formatNumber(parseFloat(r.total), loc),
        r.currency,
        csvEscape(r.category ?? "", d),
      ].join(d),
    );
  }
  return lines.join("\n");
}

/**
 * Universal English/ISO CSV — comma delimiter, dot decimals, ISO dates. Any
 * accountant anywhere, any script, any bookkeeping software can ingest this.
 */
function buildUniversalCsv(rows: ExpenseRow[]): string {
  const header =
    "date,supplier,tax_id,invoice_number,net,tax_rate,tax,total,currency,category";
  const lines = [header];
  for (const r of rows) {
    lines.push(
      [
        String(r.date).slice(0, 10),
        csvEscape(r.vendor ?? "", ","),
        csvEscape(r.cif ?? "", ","),
        csvEscape(r.invoice_number ?? "", ","),
        r.subtotal,
        r.iva_rate,
        r.iva_amount,
        r.total,
        r.currency,
        csvEscape(r.category ?? "", ","),
      ].join(","),
    );
  }
  return lines.join("\n");
}

// ─── XLSX (dual sheet: localized + universal Data) ──────────────────────────

async function buildXlsx(
  byCurrency: Map<string, ExpenseRow[]>,
  loc: LocaleStrings,
): Promise<Buffer> {
  const wb = new ExcelJS.Workbook();
  wb.creator = "InvoScanAI";
  wb.created = new Date();

  const numberFmt = excelNumberFormat();
  const L = loc.labels;

  // Sheet 1+: localized, one sheet per currency, human-friendly headers.
  for (const [currency, rows] of byCurrency) {
    const sheet = wb.addWorksheet(`${L.sheetName} ${currency}`);
    sheet.columns = [
      { header: L.date, key: "date", width: 12 },
      { header: L.supplier, key: "vendor", width: 30 },
      { header: L.taxId, key: "cif", width: 14 },
      { header: L.invoiceNumber, key: "invoice_number", width: 18 },
      { header: L.base, key: "subtotal", width: 12 },
      { header: `${L.tax} %`, key: "iva_rate", width: 8 },
      { header: L.tax, key: "iva_amount", width: 12 },
      { header: L.total, key: "total", width: 12 },
      { header: L.category, key: "category", width: 22 },
    ];
    sheet.getRow(1).font = { bold: true };

    let subtotalSum = 0,
      taxSum = 0,
      totalSum = 0;
    for (const r of rows) {
      subtotalSum += parseFloat(r.subtotal);
      taxSum += parseFloat(r.iva_amount);
      totalSum += parseFloat(r.total);
      const row = sheet.addRow({
        date: new Date(String(r.date).slice(0, 10)),
        vendor: r.vendor,
        cif: r.cif ?? "",
        invoice_number: r.invoice_number ?? "",
        subtotal: parseFloat(r.subtotal),
        iva_rate: parseFloat(r.iva_rate),
        iva_amount: parseFloat(r.iva_amount),
        total: parseFloat(r.total),
        category: r.category,
      });
      row.getCell("date").numFmt = loc.dateFormat;
      for (const key of ["subtotal", "iva_amount", "total"]) {
        row.getCell(key).numFmt = numberFmt;
      }
    }

    sheet.addRow({});
    const totalRow = sheet.addRow({
      vendor: `${L.total} ${currency}`,
      subtotal: subtotalSum,
      iva_amount: taxSum,
      total: totalSum,
    });
    totalRow.font = { bold: true };
    for (const key of ["subtotal", "iva_amount", "total"]) {
      totalRow.getCell(key).numFmt = numberFmt;
    }
  }

  // Universal "Data (EN)" sheet — flat, ISO formats, English headers, every
  // currency in one table. Designed for any accountant/script anywhere.
  const data = wb.addWorksheet("Data (EN)");
  data.columns = [
    { header: "date", key: "date", width: 12 },
    { header: "supplier", key: "vendor", width: 30 },
    { header: "tax_id", key: "cif", width: 14 },
    { header: "invoice_number", key: "invoice_number", width: 18 },
    { header: "net", key: "subtotal", width: 12 },
    { header: "tax_rate", key: "iva_rate", width: 10 },
    { header: "tax", key: "iva_amount", width: 12 },
    { header: "total", key: "total", width: 12 },
    { header: "currency", key: "currency", width: 10 },
    { header: "category", key: "category", width: 22 },
  ];
  data.getRow(1).font = { bold: true };
  for (const list of byCurrency.values()) {
    for (const r of list) {
      data.addRow({
        date: String(r.date).slice(0, 10),
        vendor: r.vendor,
        cif: r.cif ?? "",
        invoice_number: r.invoice_number ?? "",
        subtotal: parseFloat(r.subtotal),
        iva_rate: parseFloat(r.iva_rate),
        iva_amount: parseFloat(r.iva_amount),
        total: parseFloat(r.total),
        currency: r.currency,
        category: r.category,
      });
    }
  }

  // @ts-ignore — ExcelJS returns ArrayBuffer in Bun
  const buf = await wb.xlsx.writeBuffer();
  return Buffer.from(buf);
}

// ─── README (localized header, English structural footer) ───────────────────

function buildReadme(
  quarter: string,
  loc: LocaleStrings,
  byCurrency: Map<string, { count: number; subtotal: number; tax: number; total: number }>,
): string {
  const L = loc.labels;
  const lines: string[] = [];
  lines.push(`InvoScanAI — ${L.summary} ${quarter}`);
  lines.push(`${L.generatedBy}: ${new Date().toISOString()}`);
  lines.push("");
  lines.push(`${L.total} (${L.expenses}):`);
  lines.push("");
  for (const [currency, t] of byCurrency) {
    lines.push(`  ${currency}`);
    lines.push(`    invoices : ${t.count}`);
    lines.push(`    ${L.base.toLowerCase()} : ${formatCurrency(t.subtotal, currency, loc)}`);
    lines.push(`    ${L.tax.toLowerCase()}      : ${formatCurrency(t.tax, currency, loc)}`);
    lines.push(`    ${L.total.toLowerCase()}    : ${formatCurrency(t.total, currency, loc)}`);
    lines.push("");
  }
  lines.push("Folder structure (English, universal):");
  lines.push("  transactions.csv         — localized CSV");
  lines.push("  transactions_en.csv      — universal English/ISO CSV");
  lines.push("  transactions.xlsx        — Excel: localized sheet(s) + Data (EN)");
  lines.push("  invoices/<YYYY>/<MM>/    — original PDFs/images by year and month");
  lines.push("");
  return lines.join("\n");
}

// ─── routes ─────────────────────────────────────────────────────────────────

exportRoutes.get("/summary/:quarter", async (c) => {
  const user = c.get("user");
  const quarter = c.req.param("quarter");
  const { start, end } = quarterBounds(quarter);

  const rows = (await sql`
    SELECT currency, category, subtotal, iva_amount, total
    FROM expenses
    WHERE user_id = ${user.sub}
      AND date >= ${start} AND date < ${end}
      AND status != 'rejected'
  `) as Array<{
    currency: string;
    category: string;
    subtotal: string;
    iva_amount: string;
    total: string;
  }>;

  const byCurrency: Record<
    string,
    { count: number; subtotal: number; tax: number; total: number }
  > = {};
  const byCategoryPerCurrency: Record<string, Record<string, number>> = {};

  for (const r of rows) {
    const ccy = r.currency || "EUR";
    if (!byCurrency[ccy]) {
      byCurrency[ccy] = { count: 0, subtotal: 0, tax: 0, total: 0 };
    }
    byCurrency[ccy].count++;
    byCurrency[ccy].subtotal += parseFloat(r.subtotal);
    byCurrency[ccy].tax += parseFloat(r.iva_amount);
    byCurrency[ccy].total += parseFloat(r.total);

    if (!byCategoryPerCurrency[ccy]) byCategoryPerCurrency[ccy] = {};
    byCategoryPerCurrency[ccy][r.category] =
      (byCategoryPerCurrency[ccy][r.category] || 0) + parseFloat(r.total);
  }

  return c.json({ quarter, byCurrency, byCategoryPerCurrency });
});

exportRoutes.get("/zip", async (c) => {
  const user = c.get("user");

  // ZIP export requires Pro
  const access = await checkProAccess(user.sub);
  if (!access.allowed) {
    return c.json(
      { error: access.error, message: access.message, upgrade: access.upgrade },
      access.status as 403,
    );
  }

  const quarter = c.req.query("quarter");
  if (!quarter) return c.json({ error: "quarter required (e.g., 2026-Q2)" }, 400);

  // Locale resolution priority: explicit query → users.locale → en-GB
  const localeQuery = c.req.query("locale");
  let userLocale: string | null = null;
  if (!localeQuery) {
    const u = (await sql`SELECT locale FROM users WHERE id = ${user.sub} LIMIT 1`) as Array<{
      locale: string;
    }>;
    userLocale = u[0]?.locale ?? null;
  }
  const loc = resolveLocale(localeQuery ?? userLocale);

  const { start, end } = quarterBounds(quarter);

  const rows = (await sql`
    SELECT id, vendor, cif, date, invoice_number,
           subtotal, iva_rate, iva_amount, irpf_rate, irpf_amount, total,
           currency, category, status, attachment_key
    FROM expenses
    WHERE user_id = ${user.sub}
      AND date >= ${start} AND date < ${end}
      AND status != 'rejected'
    ORDER BY currency ASC, date ASC
  `) as ExpenseRow[];

  if (rows.length === 0) {
    return c.json({ error: "no_expenses_in_quarter" }, 404);
  }

  // Group by currency
  const byCurrency = new Map<string, ExpenseRow[]>();
  for (const r of rows) {
    const ccy = r.currency || "EUR";
    if (!byCurrency.has(ccy)) byCurrency.set(ccy, []);
    byCurrency.get(ccy)!.push(r);
  }

  // Per-currency totals for README
  const totalsByCurrency = new Map<
    string,
    { count: number; subtotal: number; tax: number; total: number }
  >();
  for (const [ccy, list] of byCurrency) {
    const t = { count: 0, subtotal: 0, tax: 0, total: 0 };
    for (const r of list) {
      t.count++;
      t.subtotal += parseFloat(r.subtotal);
      t.tax += parseFloat(r.iva_amount);
      t.total += parseFloat(r.total);
    }
    totalsByCurrency.set(ccy, t);
  }

  // Pull tax id once for the filename
  const taxRows = (await sql`
    SELECT tax_id FROM users WHERE id = ${user.sub} LIMIT 1
  `) as Array<{ tax_id: string | null }>;
  const taxId = taxRows[0]?.tax_id ? safeFileName(taxRows[0].tax_id, 20) : "user";

  // Build the ZIP entries map. Filenames are ASCII / English so no charset
  // surprises across Windows / older email clients; content is localized.
  const entries: Record<string, Uint8Array> = {};

  // One localized CSV (all currencies, locale-formatted) + one universal.
  const flatRows: ExpenseRow[] = [];
  for (const list of byCurrency.values()) flatRows.push(...list);
  entries["transactions.csv"] = strToU8(buildLocalizedCsv(flatRows, loc));
  entries["transactions_en.csv"] = strToU8(buildUniversalCsv(flatRows));

  // Single Excel: localized sheet(s) + Data (EN) sheet.
  entries["transactions.xlsx"] = new Uint8Array(await buildXlsx(byCurrency, loc));

  // README
  entries["README.txt"] = strToU8(buildReadme(quarter, loc, totalsByCurrency));

  // Attachments grouped by year/month folder
  for (const list of byCurrency.values()) {
    for (const r of list) {
      if (!r.attachment_key) continue;
      try {
        const buf = await downloadFile(r.attachment_key);
        const ext = attachmentExt(r.attachment_key);
        const dateStr = String(r.date).slice(0, 10);
        const [year, month] = dateStr.split("-");
        const totalStr = parseFloat(r.total).toFixed(2);
        const name = `${dateStr}_${safeFileName(r.vendor)}_${totalStr}.${ext}`;
        entries[`invoices/${year}/${month}/${name}`] = new Uint8Array(buf);
      } catch (err) {
        console.warn(`Failed to fetch attachment ${r.attachment_key}:`, err);
      }
    }
  }

  // Zip everything synchronously (fine for typical ~50 invoices/quarter)
  const zipped = zipSync(entries, { level: 6 });

  const filename = `InvoScanAI_Export_${taxId}_${quarter}.zip`;
  return new Response(zipped, {
    headers: {
      "Content-Type": "application/zip",
      "Content-Disposition": `attachment; filename="${filename}"`,
      "Content-Length": String(zipped.byteLength),
    },
  });
});

// Legacy CSV endpoint (kept for compatibility) — now locale-aware too.
exportRoutes.get("/csv", async (c) => {
  const user = c.get("user");
  const quarter = c.req.query("quarter");
  if (!quarter) return c.json({ error: "quarter required" }, 400);

  const localeQuery = c.req.query("locale");
  let userLocale: string | null = null;
  if (!localeQuery) {
    const u = (await sql`SELECT locale FROM users WHERE id = ${user.sub} LIMIT 1`) as Array<{
      locale: string;
    }>;
    userLocale = u[0]?.locale ?? null;
  }
  const loc = resolveLocale(localeQuery ?? userLocale);

  const { start, end } = quarterBounds(quarter);

  const rows = (await sql`
    SELECT vendor, cif, date, invoice_number, subtotal, iva_rate, iva_amount,
           irpf_rate, irpf_amount, total, currency, category, status
    FROM expenses
    WHERE user_id = ${user.sub}
      AND date >= ${start} AND date < ${end}
      AND status != 'rejected'
    ORDER BY currency ASC, date ASC
  `) as ExpenseRow[];

  return new Response(buildLocalizedCsv(rows, loc), {
    headers: {
      "Content-Type": "text/csv; charset=utf-8",
      "Content-Disposition": `attachment; filename="invoscanai-${quarter}.csv"`,
    },
  });
});

// ─── warnings detection ────────────────────────────────────────────────────

type Warning = { type: string; count: number; message: string };

function detectWarnings(rows: ExpenseRow[], loc: LocaleStrings): Warning[] {
  const warnings: Warning[] = [];
  const noCif = rows.filter((r) => !r.cif);
  if (noCif.length > 0)
    warnings.push({
      type: "missing_cif",
      count: noCif.length,
      message: `${noCif.length} ${loc.labels.expenses.toLowerCase()} without supplier ${loc.labels.taxId}`,
    });
  const noCategory = rows.filter((r) => !r.category || r.category === "otros");
  if (noCategory.length > 0)
    warnings.push({
      type: "uncategorized",
      count: noCategory.length,
      message: `${noCategory.length} ${loc.labels.expenses.toLowerCase()} uncategorized or set to "otros"`,
    });
  const zeroAmount = rows.filter((r) => parseFloat(r.total) === 0);
  if (zeroAmount.length > 0)
    warnings.push({
      type: "zero_amount",
      count: zeroAmount.length,
      message: `${zeroAmount.length} ${loc.labels.expenses.toLowerCase()} with zero total`,
    });
  const pending = rows.filter((r) => r.status === "pending");
  if (pending.length > 0)
    warnings.push({
      type: "pending",
      count: pending.length,
      message: `${pending.length} ${loc.labels.expenses.toLowerCase()} still pending confirmation`,
    });
  return warnings;
}

// ─── async export job: create, poll, download ──────────────────────────────

/**
 * POST /api/export/jobs — create an export job. Returns immediately with job id
 * + summary stats + warnings. ZIP is built in the background.
 */
exportRoutes.post("/jobs", async (c) => {
  const user = c.get("user");

  // Export jobs (ZIP+XLSX) require Pro — free users can use /csv instead
  const access = await checkProAccess(user.sub);
  if (!access.allowed) {
    return c.json(
      { error: access.error, message: access.message, upgrade: access.upgrade },
      access.status as 403,
    );
  }

  const body = (await c.req.json().catch(() => ({}))) as {
    periodStart?: string;
    periodEnd?: string;
    quarter?: string;
    locale?: string;
  };

  let start: string, end: string;
  if (body.quarter) {
    const bounds = quarterBounds(body.quarter);
    start = bounds.start;
    end = bounds.end;
  } else if (body.periodStart && body.periodEnd) {
    start = body.periodStart;
    end = body.periodEnd;
  } else {
    return c.json({ error: "quarter or periodStart+periodEnd required" }, 400);
  }

  const localeQuery = body.locale;
  let userLocale: string | null = null;
  if (!localeQuery) {
    const u = (await sql`SELECT locale FROM users WHERE id = ${user.sub} LIMIT 1`) as Array<{
      locale: string;
    }>;
    userLocale = u[0]?.locale ?? null;
  }
  const loc = resolveLocale(localeQuery ?? userLocale);

  const rows = (await sql`
    SELECT id, vendor, cif, date, invoice_number,
           subtotal, iva_rate, iva_amount, irpf_rate, irpf_amount, total,
           currency, category, status, attachment_key
    FROM expenses
    WHERE user_id = ${user.sub}
      AND date >= ${start} AND date < ${end}
      AND status != 'rejected'
    ORDER BY currency ASC, date ASC
  `) as ExpenseRow[];

  // Group by currency
  const byCurrency = new Map<string, ExpenseRow[]>();
  for (const r of rows) {
    const ccy = r.currency || "EUR";
    if (!byCurrency.has(ccy)) byCurrency.set(ccy, []);
    byCurrency.get(ccy)!.push(r);
  }

  // Stats
  const stats: Record<string, { count: number; subtotal: number; tax: number; total: number }> = {};
  for (const [ccy, list] of byCurrency) {
    const t = { count: 0, subtotal: 0, tax: 0, total: 0 };
    for (const r of list) {
      t.count++;
      t.subtotal += parseFloat(r.subtotal);
      t.tax += parseFloat(r.iva_amount);
      t.total += parseFloat(r.total);
    }
    stats[ccy] = t;
  }

  const warnings = detectWarnings(rows, loc);

  // Insert job record
  const [job] = (await sql`
    INSERT INTO exports (user_id, locale, base_currency, period_start, period_end, status, stats, warnings)
    VALUES (
      ${user.sub},
      ${loc.locale ?? loc.language},
      'EUR',
      ${start},
      ${end},
      ${rows.length === 0 ? "ready" : "pending"},
      ${JSON.stringify({ byCurrency: stats })}::jsonb,
      ${JSON.stringify(warnings)}::jsonb
    )
    RETURNING id, status, created_at, expires_at
  `) as Array<{ id: string; status: string; created_at: string; expires_at: string }>;

  if (rows.length === 0) {
    return c.json({
      id: job.id,
      status: "ready",
      stats: { byCurrency: stats },
      warnings,
      expenseCount: 0,
      createdAt: job.created_at,
      expiresAt: job.expires_at,
    });
  }

  // Build ZIP in the background (fire and forget for this request)
  const jobId = job.id;
  const userId = user.sub;
  (async () => {
    try {
      await sql`UPDATE exports SET status = 'running', progress = 10 WHERE id = ${jobId}`;

      const totalsByCurrency = new Map<
        string,
        { count: number; subtotal: number; tax: number; total: number }
      >();
      for (const [ccy, s] of Object.entries(stats)) {
        totalsByCurrency.set(ccy, s);
      }

      const entries: Record<string, Uint8Array> = {};
      const flatRows: ExpenseRow[] = [];
      for (const list of byCurrency.values()) flatRows.push(...list);
      entries["transactions.csv"] = strToU8(buildLocalizedCsv(flatRows, loc));
      entries["transactions_en.csv"] = strToU8(buildUniversalCsv(flatRows));
      entries["transactions.xlsx"] = new Uint8Array(await buildXlsx(byCurrency, loc));
      entries["README.txt"] = strToU8(
        buildReadme(body.quarter ?? `${start}_${end}`, loc, totalsByCurrency),
      );

      await sql`UPDATE exports SET progress = 50 WHERE id = ${jobId}`;

      // Fetch attachments grouped by year/month
      for (const list of byCurrency.values()) {
        for (const r of list) {
          if (!r.attachment_key) continue;
          try {
            const buf = await downloadFile(r.attachment_key);
            const ext = attachmentExt(r.attachment_key);
            const dateStr = String(r.date).slice(0, 10);
            const [year, month] = dateStr.split("-");
            const totalStr = parseFloat(r.total).toFixed(2);
            const name = `${dateStr}_${safeFileName(r.vendor)}_${totalStr}.${ext}`;
            entries[`invoices/${year}/${month}/${name}`] = new Uint8Array(buf);
          } catch (err) {
            console.warn(`Failed to fetch attachment ${r.attachment_key}:`, err);
          }
        }
      }

      await sql`UPDATE exports SET progress = 80 WHERE id = ${jobId}`;

      const zipped = zipSync(entries, { level: 6 });
      const storageKey = `exports/${userId}/${jobId}.zip`;
      await uploadFile(storageKey, Buffer.from(zipped), "application/zip");

      await sql`
        UPDATE exports
        SET status = 'ready', progress = 100, storage_key = ${storageKey}
        WHERE id = ${jobId}
      `;
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      console.error(`Export job ${jobId} failed:`, msg, err);
      await sql`UPDATE exports SET status = 'failed', warnings = ${JSON.stringify([{ type: "error", count: 0, message: msg }])}::jsonb WHERE id = ${jobId}`;
    }
  })();

  return c.json({
    id: job.id,
    status: "pending",
    stats: { byCurrency: stats },
    warnings,
    expenseCount: rows.length,
    createdAt: job.created_at,
    expiresAt: job.expires_at,
  });
});

/** GET /api/export/jobs/:id — poll export job status */
exportRoutes.get("/jobs/:id", async (c) => {
  const user = c.get("user");
  const id = c.req.param("id");
  const [job] = (await sql`
    SELECT id, status, progress, stats, warnings, storage_key, created_at, expires_at
    FROM exports WHERE id = ${id} AND user_id = ${user.sub}
  `) as Array<{
    id: string;
    status: string;
    progress: number;
    stats: object | string;
    warnings: object | string;
    storage_key: string | null;
    created_at: string;
    expires_at: string;
  }>;
  if (!job) return c.json({ error: "not_found" }, 404);
  return c.json({
    id: job.id,
    status: job.status,
    progress: job.progress,
    stats: typeof job.stats === "string" ? JSON.parse(job.stats) : job.stats,
    warnings: typeof job.warnings === "string" ? JSON.parse(job.warnings) : job.warnings,
    storageKey: job.storage_key,
    createdAt: job.created_at,
    expiresAt: job.expires_at,
  });
});

/** GET /api/export/jobs/:id/download — stream ZIP from R2 */
exportRoutes.get("/jobs/:id/download", async (c) => {
  const user = c.get("user");
  const id = c.req.param("id");
  const [job] = (await sql`
    SELECT storage_key FROM exports
    WHERE id = ${id} AND user_id = ${user.sub} AND status = 'ready'
  `) as Array<{ storage_key: string | null }>;
  if (!job?.storage_key) return c.json({ error: "not_ready" }, 404);
  const buf = await downloadFile(job.storage_key);
  return new Response(buf, {
    headers: {
      "Content-Type": "application/zip",
      "Content-Disposition": `attachment; filename="InvoScanAI_Export_${id.slice(0, 8)}.zip"`,
      "Content-Length": String(buf.byteLength),
    },
  });
});

/** POST /api/export/jobs/:id/share — create a public share link */
exportRoutes.post("/jobs/:id/share", async (c) => {
  const user = c.get("user");
  const id = c.req.param("id");
  const [job] = (await sql`
    SELECT id, storage_key FROM exports
    WHERE id = ${id} AND user_id = ${user.sub} AND status = 'ready'
  `) as Array<{ id: string; storage_key: string | null }>;
  if (!job?.storage_key) return c.json({ error: "not_ready" }, 404);

  const token = crypto.randomUUID().replace(/-/g, "").slice(0, 16);
  const expiresAt = new Date(Date.now() + 7 * 24 * 3600 * 1000);

  await sql`
    INSERT INTO export_shares (token, export_id, expires_at)
    VALUES (${token}, ${id}, ${expiresAt.toISOString()})
  `;

  const url = `${process.env.PUBLIC_URL ?? "http://localhost:3000"}/e/${token}`;
  return c.json({ token, url, expiresAt: expiresAt.toISOString() });
});

/** POST /api/export/jobs/:id/share/email — email the share link to the accountant */
exportRoutes.post("/jobs/:id/share/email", async (c) => {
  const user = c.get("user");
  const id = c.req.param("id");
  const body = (await c.req.json().catch(() => ({}))) as { email?: string };

  // Fetch user profile for accountant info
  const [profile] = (await sql`
    SELECT name, company_name, accountant_email, accountant_name
    FROM users WHERE id = ${user.sub}
  `) as Array<{
    name: string | null;
    company_name: string | null;
    accountant_email: string | null;
    accountant_name: string | null;
  }>;

  const recipientEmail = body.email || profile?.accountant_email;
  if (!recipientEmail) {
    return c.json({ error: "no email provided and no accountant_email on profile" }, 400);
  }

  // Get or create share link
  const [existing] = (await sql`
    SELECT token, expires_at FROM export_shares
    WHERE export_id = ${id} ORDER BY created_at DESC LIMIT 1
  `) as Array<{ token: string; expires_at: string }>;

  let shareToken: string;
  let expiresAt: string;

  if (existing && new Date(existing.expires_at) > new Date()) {
    shareToken = existing.token;
    expiresAt = existing.expires_at;
  } else {
    shareToken = crypto.randomUUID().replace(/-/g, "").slice(0, 16);
    const expiry = new Date(Date.now() + 7 * 24 * 3600 * 1000);
    expiresAt = expiry.toISOString();
    await sql`
      INSERT INTO export_shares (token, export_id, expires_at)
      VALUES (${shareToken}, ${id}, ${expiresAt})
    `;
  }

  const shareUrl = `${process.env.PUBLIC_URL ?? "http://localhost:3000"}/e/${shareToken}`;

  // Fetch period for quarter label
  const [job] = (await sql`
    SELECT period_start, period_end FROM exports
    WHERE id = ${id} AND user_id = ${user.sub}
  `) as Array<{ period_start: string; period_end: string }>;

  if (!job) return c.json({ error: "not_found" }, 404);

  // Derive quarter label from period
  const startDate = new Date(job.period_start);
  const q = Math.ceil((startDate.getMonth() + 1) / 3);
  const quarter = `${startDate.getFullYear()}-Q${q}`;

  try {
    await sendExportEmail({
      to: recipientEmail,
      accountantName: profile?.accountant_name ?? null,
      senderName: profile?.name ?? null,
      companyName: profile?.company_name ?? null,
      quarter,
      shareUrl,
      expiresAt,
    });
    return c.json({ ok: true, sentTo: recipientEmail });
  } catch (err) {
    console.error("Failed to send export email:", err);
    return c.json({ error: "email_failed", message: "Could not send email" }, 500);
  }
});

/** GET /api/export/jobs — list recent exports for this user */
exportRoutes.get("/jobs", async (c) => {
  const user = c.get("user");
  const rows = (await sql`
    SELECT id, status, progress, stats, warnings, period_start, period_end,
           storage_key, created_at, expires_at
    FROM exports WHERE user_id = ${user.sub}
    ORDER BY created_at DESC LIMIT 20
  `) as Array<Record<string, unknown>>;
  return c.json(rows.map((r) => ({
    ...r,
    stats: typeof r.stats === "string" ? JSON.parse(r.stats as string) : r.stats,
    warnings: typeof r.warnings === "string" ? JSON.parse(r.warnings as string) : r.warnings,
  })));
});

// ─── public share download (mounted at /e/:token, no auth) ─────────────────

shareDownloadRoute.get("/:token", async (c) => {
  const token = c.req.param("token");

  const [share] = (await sql`
    SELECT s.token, s.export_id, s.expires_at, s.download_count, s.max_downloads,
           e.storage_key
    FROM export_shares s
    JOIN exports e ON e.id = s.export_id
    WHERE s.token = ${token}
  `) as Array<{
    token: string;
    export_id: string;
    expires_at: string;
    download_count: number;
    max_downloads: number;
    storage_key: string | null;
  }>;

  if (!share) return c.json({ error: "not_found" }, 404);
  if (new Date(share.expires_at) < new Date()) return c.json({ error: "expired" }, 410);
  if (share.download_count >= share.max_downloads) return c.json({ error: "max_downloads_reached" }, 429);
  if (!share.storage_key) return c.json({ error: "not_ready" }, 404);

  // Increment download count
  await sql`
    UPDATE export_shares SET download_count = download_count + 1 WHERE token = ${token}
  `;

  const buf = await downloadFile(share.storage_key);
  return new Response(buf, {
    headers: {
      "Content-Type": "application/zip",
      "Content-Disposition": `attachment; filename="InvoScanAI_Export.zip"`,
      "Content-Length": String(buf.byteLength),
    },
  });
});
