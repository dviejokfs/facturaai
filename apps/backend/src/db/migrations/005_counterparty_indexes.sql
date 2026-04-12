-- Indexes for the /contacts/counterparties aggregation + per-counterparty
-- invoice lookups. The query scans all of a user's expenses, so the primary
-- win is a composite on user_id + the grouping keys, but we also want fast
-- ILIKE search on name/tax_id via trigram indexes.

CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Composite indexes that cover the GROUP BY + filter predicates.
-- Partial on status to match the `status <> 'rejected'` filter.
CREATE INDEX IF NOT EXISTS idx_expenses_user_vendor
    ON expenses (user_id, vendor, vendor_tax_id)
    WHERE status <> 'rejected';

CREATE INDEX IF NOT EXISTS idx_expenses_user_client
    ON expenses (user_id, client, client_tax_id)
    WHERE status <> 'rejected' AND client IS NOT NULL;

-- Trigram indexes enable index-backed ILIKE '%term%' searches — otherwise
-- Postgres would sequentially scan every row in the CTE.
CREATE INDEX IF NOT EXISTS idx_expenses_vendor_trgm
    ON expenses USING gin (vendor gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_expenses_client_trgm
    ON expenses USING gin (client gin_trgm_ops)
    WHERE client IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_expenses_vendor_taxid_trgm
    ON expenses USING gin (vendor_tax_id gin_trgm_ops)
    WHERE vendor_tax_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_expenses_client_taxid_trgm
    ON expenses USING gin (client_tax_id gin_trgm_ops)
    WHERE client_tax_id IS NOT NULL;

-- Covers the per-counterparty invoice list endpoint (status<>rejected + date DESC).
CREATE INDEX IF NOT EXISTS idx_expenses_user_date_active
    ON expenses (user_id, date DESC)
    WHERE status <> 'rejected';
