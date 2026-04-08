import type { LocaleStrings, LocaleId } from "./types";
import { enGB } from "./locales/en-GB";
import { esES } from "./locales/es-ES";

const LOCALES: Record<LocaleId, LocaleStrings> = {
  "en-GB": enGB,
  "es-ES": esES,
};

const DEFAULT_LOCALE: LocaleId = "en-GB";

/**
 * Resolve any client-supplied locale string to one we actually support.
 * Falls back through language-only match (e.g. "es" → "es-ES") then default.
 */
export function resolveLocale(input: string | undefined | null): LocaleStrings {
  if (!input) return LOCALES[DEFAULT_LOCALE];
  const exact = LOCALES[input as LocaleId];
  if (exact) return exact;
  const lang = input.slice(0, 2).toLowerCase();
  for (const id of Object.keys(LOCALES) as LocaleId[]) {
    if (LOCALES[id].language === lang) return LOCALES[id];
  }
  return LOCALES[DEFAULT_LOCALE];
}

export function listLocales(): LocaleId[] {
  return Object.keys(LOCALES) as LocaleId[];
}

// ── formatters ─────────────────────────────────────────────────────────────

/** Format a number using the locale's decimal/thousand separators. */
export function formatNumber(n: number, loc: LocaleStrings, fractionDigits = 2): string {
  const fixed = n.toFixed(fractionDigits);
  const [intPart, fracPart] = fixed.split(".");
  const withThousands = intPart!.replace(/\B(?=(\d{3})+(?!\d))/g, "\u0000");
  const intOut = withThousands.replace(/\u0000/g, loc.thousandSeparator);
  return fracPart ? `${intOut}${loc.decimalSeparator}${fracPart}` : intOut;
}

/** Format a currency amount in its ORIGINAL currency (never converted). */
export function formatCurrency(
  n: number,
  isoCurrency: string,
  loc: LocaleStrings,
): string {
  const num = formatNumber(n, loc);
  // Use ISO code rather than guessing symbol — works for any currency.
  return `${num} ${isoCurrency}`;
}

/** Format an ISO date string (yyyy-MM-dd) per locale's dateFormat. */
export function formatDate(iso: string | Date, loc: LocaleStrings): string {
  const d = typeof iso === "string" ? new Date(iso) : iso;
  const dd = String(d.getUTCDate()).padStart(2, "0");
  const mm = String(d.getUTCMonth() + 1).padStart(2, "0");
  const yyyy = String(d.getUTCFullYear());
  return loc.dateFormat
    .replace("dd", dd)
    .replace("MM", mm)
    .replace("yyyy", yyyy);
}

/** Excel cell number format string. ExcelJS / Excel render this per opener locale. */
export function excelNumberFormat(): string {
  return "#,##0.00";
}

export function excelDateFormat(loc: LocaleStrings): string {
  return loc.dateFormat;
}

export type { LocaleStrings, LocaleId };
