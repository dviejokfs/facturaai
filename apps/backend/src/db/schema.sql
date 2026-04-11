CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR NOT NULL UNIQUE,
    name VARCHAR,
    google_sub VARCHAR UNIQUE,
    apple_sub VARCHAR UNIQUE,
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

ALTER TABLE gmail_syncs
    ADD COLUMN IF NOT EXISTS total_messages INT NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS oauth_states (
    state VARCHAR PRIMARY KEY,
    anonymous_token TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── RevenueCat: subscriptions + webhook event audit log ────────────────────

CREATE TABLE IF NOT EXISTS subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    revenuecat_app_user_id VARCHAR NOT NULL,
    entitlement VARCHAR NOT NULL,           -- 'pro' | 'business'
    product_id VARCHAR NOT NULL,            -- e.g. 'invoscanai_pro_yearly'
    period_type VARCHAR,                    -- 'normal' | 'trial' | 'intro'
    status VARCHAR NOT NULL,                -- 'active' | 'in_grace' | 'cancelled' | 'expired' | 'billing_issue'
    store VARCHAR,                          -- 'app_store' | 'play_store' | 'stripe'
    original_purchase_at TIMESTAMPTZ,
    purchased_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ,
    auto_renew BOOLEAN NOT NULL DEFAULT TRUE,
    environment VARCHAR NOT NULL DEFAULT 'PRODUCTION',  -- 'SANDBOX' | 'PRODUCTION'
    last_event_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_subscriptions_rc_user_entitlement
    ON subscriptions(revenuecat_app_user_id, entitlement);
CREATE INDEX IF NOT EXISTS idx_subscriptions_user ON subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_status ON subscriptions(status);
CREATE INDEX IF NOT EXISTS idx_subscriptions_expires ON subscriptions(expires_at);

CREATE TABLE IF NOT EXISTS subscription_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id VARCHAR NOT NULL UNIQUE,        -- RevenueCat's event.id, used for idempotency
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    revenuecat_app_user_id VARCHAR NOT NULL,
    event_type VARCHAR NOT NULL,             -- INITIAL_PURCHASE | RENEWAL | CANCELLATION | ...
    environment VARCHAR NOT NULL,            -- 'SANDBOX' | 'PRODUCTION'
    payload JSONB NOT NULL,
    received_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_subscription_events_user
    ON subscription_events(user_id, received_at DESC);
CREATE INDEX IF NOT EXISTS idx_subscription_events_rc_user
    ON subscription_events(revenuecat_app_user_id, received_at DESC);

-- ── Locale + tax id + accountant (worldwide invoicing) ─────────────────────

ALTER TABLE users
    ADD COLUMN IF NOT EXISTS locale           VARCHAR NOT NULL DEFAULT 'en-GB',
    ADD COLUMN IF NOT EXISTS base_currency    VARCHAR NOT NULL DEFAULT 'EUR',
    ADD COLUMN IF NOT EXISTS tax_id           VARCHAR,
    ADD COLUMN IF NOT EXISTS tax_id_type      VARCHAR,
    ADD COLUMN IF NOT EXISTS accountant_email VARCHAR,
    ADD COLUMN IF NOT EXISTS accountant_name  VARCHAR;

-- Backfill from legacy `cif` column on first run, if present.
-- (No-op if `cif` doesn't exist on users — only expenses has cif today.)

CREATE TABLE IF NOT EXISTS exports (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    locale        VARCHAR NOT NULL,
    base_currency VARCHAR NOT NULL,
    period_start  DATE NOT NULL,
    period_end    DATE NOT NULL,
    status        VARCHAR NOT NULL DEFAULT 'pending',  -- pending | running | ready | failed
    progress      INT NOT NULL DEFAULT 0,
    storage_key   VARCHAR,
    stats         JSONB NOT NULL DEFAULT '{}'::jsonb,
    warnings      JSONB NOT NULL DEFAULT '[]'::jsonb,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at    TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '30 days')
);

CREATE INDEX IF NOT EXISTS idx_exports_user ON exports(user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS export_shares (
    token          VARCHAR PRIMARY KEY,
    export_id      UUID NOT NULL REFERENCES exports(id) ON DELETE CASCADE,
    expires_at     TIMESTAMPTZ NOT NULL,
    download_count INT NOT NULL DEFAULT 0,
    max_downloads  INT NOT NULL DEFAULT 50,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_export_shares_export ON export_shares(export_id);

-- ── Vendor / Client party identification ─────────────────────
ALTER TABLE expenses
    ADD COLUMN IF NOT EXISTS vendor_tax_id VARCHAR,
    ADD COLUMN IF NOT EXISTS client        VARCHAR,
    ADD COLUMN IF NOT EXISTS client_tax_id VARCHAR;

-- ── User company name (for expense vs income detection) ──────
ALTER TABLE users
    ADD COLUMN IF NOT EXISTS company_name VARCHAR;

-- ── Multi-company support ────────────────────────────────────
CREATE TABLE IF NOT EXISTS companies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR NOT NULL,
    tax_id VARCHAR NOT NULL,
    tax_id_type VARCHAR,
    address TEXT,
    is_default BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_companies_user_taxid
    ON companies(user_id, tax_id);
CREATE INDEX IF NOT EXISTS idx_companies_user
    ON companies(user_id);

-- ── Contact directory ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS contacts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR NOT NULL,
    tax_id VARCHAR,
    email VARCHAR,
    phone VARCHAR,
    address TEXT,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_contacts_user_taxid
    ON contacts(user_id, tax_id) WHERE tax_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_contacts_user
    ON contacts(user_id);

-- ── Device tokens for push notifications ─────────────────────
CREATE TABLE IF NOT EXISTS device_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token VARCHAR NOT NULL,
    platform VARCHAR NOT NULL DEFAULT 'ios',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_device_tokens_user_token
    ON device_tokens(user_id, token);

-- ── Expense/Income type + company/contact FKs ────────────────
ALTER TABLE expenses
    ADD COLUMN IF NOT EXISTS type VARCHAR NOT NULL DEFAULT 'expense',
    ADD COLUMN IF NOT EXISTS company_id UUID REFERENCES companies(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS vendor_contact_id UUID REFERENCES contacts(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS client_contact_id UUID REFERENCES contacts(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_expenses_type ON expenses(user_id, type);
CREATE INDEX IF NOT EXISTS idx_expenses_company ON expenses(company_id) WHERE company_id IS NOT NULL;

-- ── Anonymous user support ──────────────────────────────────
ALTER TABLE users
    ADD COLUMN IF NOT EXISTS is_anonymous BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS anonymous_extractions INT NOT NULL DEFAULT 0;

-- Allow NULL email for anonymous users
ALTER TABLE users ALTER COLUMN email DROP NOT NULL;

CREATE INDEX IF NOT EXISTS idx_users_anonymous
    ON users(is_anonymous, created_at) WHERE is_anonymous = TRUE;

-- ── Gmail Push (Pub/Sub watch) ─────────────────────────────
ALTER TABLE users
    ADD COLUMN IF NOT EXISTS gmail_history_id VARCHAR,
    ADD COLUMN IF NOT EXISTS gmail_watch_expiry TIMESTAMPTZ;
