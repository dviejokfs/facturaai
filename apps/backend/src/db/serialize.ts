/**
 * Bun's SQL driver returns Postgres `numeric` columns as strings.
 * This helper converts expense rows so numeric fields are actual numbers
 * in the JSON response, matching what iOS Decodable expects.
 */
export function serializeExpense(row: Record<string, unknown>): Record<string, unknown> {
  return {
    ...row,
    subtotal: Number(row.subtotal),
    iva_rate: Number(row.iva_rate),
    iva_amount: Number(row.iva_amount),
    irpf_rate: Number(row.irpf_rate),
    irpf_amount: Number(row.irpf_amount),
    total: Number(row.total),
    confidence: Number(row.confidence),
    type: row.type ?? "expense",
    company_id: row.company_id ?? null,
    vendor_contact_id: row.vendor_contact_id ?? null,
    client_contact_id: row.client_contact_id ?? null,
  };
}

export function serializeExpenses(rows: Record<string, unknown>[]): Record<string, unknown>[] {
  return rows.map(serializeExpense);
}
