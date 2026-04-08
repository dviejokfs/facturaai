/**
 * Locale shape used by the export pipeline. Every supported locale must
 * `satisfies LocaleStrings` so adding a new market is just copy + translate.
 */
export type LocaleStrings = {
  locale: string;        // BCP-47, e.g. 'es-ES', 'en-GB'
  language: string;      // 'es', 'en', 'de'
  country: string;       // 'ES', 'GB', 'US', 'DE'
  currency: string;      // 'EUR', 'GBP', 'USD'
  currencySymbol: string;
  dateFormat: string;    // 'dd/MM/yyyy' / 'MM/dd/yyyy'
  decimalSeparator: "," | ".";
  thousandSeparator: "," | "." | " ";
  csvDelimiter: "," | ";";
  labels: {
    summary: string;
    period: string;
    expenses: string;
    income: string;
    tax: string;            // IVA / VAT / MwSt
    taxDeductible: string;
    taxCollected: string;
    taxId: string;          // NIF / VAT number / Steuernummer
    date: string;
    supplier: string;
    concept: string;
    category: string;
    base: string;
    total: string;
    invoiceNumber: string;
    accountant: string;     // 'gestor' / 'accountant' / 'Steuerberater'
    exportFor: string;      // button copy
    generatedBy: string;
    sheetName: string;      // localized worksheet name
    quarter: string;
    movements: string;
  };
};

export type LocaleId = "en-GB" | "es-ES";
