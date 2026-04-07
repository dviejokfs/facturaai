CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR NOT NULL UNIQUE,
    name VARCHAR,
    google_sub VARCHAR UNIQUE,
    google_access_token TEXT,
    google_refresh_token TEXT,
    google_token_expiry TIMESTAMPTZ,
    plan VARCHAR NOT NULL DEFAULT 'trial', -- trial | pro | business | expired
    trial_ends_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '14 days'),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS expenses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    vendor VARCHAR NOT NULL,
    cif VARCHAR,
    date DATE NOT NULL,
    invoice_number VARCHAR,
    subtotal NUMERIC(12,2) NOT NULL DEFAULT 0,
    iva_rate NUMERIC(5,2) NOT NULL DEFAULT 0,
    iva_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
    irpf_rate NUMERIC(5,2) NOT NULL DEFAULT 0,
    irpf_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
    total NUMERIC(12,2) NOT NULL DEFAULT 0,
    currency VARCHAR NOT NULL DEFAULT 'EUR',
    category VARCHAR NOT NULL DEFAULT 'otros',
    status VARCHAR NOT NULL DEFAULT 'pending',
    confidence NUMERIC(3,2) NOT NULL DEFAULT 0,
    source VARCHAR NOT NULL DEFAULT 'manual',
    gmail_message_id VARCHAR,
    attachment_key VARCHAR,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_expenses_user_date ON expenses(user_id, date DESC);
CREATE INDEX IF NOT EXISTS idx_expenses_user_status ON expenses(user_id, status);
CREATE UNIQUE INDEX IF NOT EXISTS idx_expenses_gmail_msg
    ON expenses(user_id, gmail_message_id) WHERE gmail_message_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS gmail_syncs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status VARCHAR NOT NULL DEFAULT 'idle',
    last_sync_at TIMESTAMPTZ,
    messages_processed INT NOT NULL DEFAULT 0,
    invoices_found INT NOT NULL DEFAULT 0,
    error TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_gmail_syncs_user ON gmail_syncs(user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS oauth_states (
    state VARCHAR PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
