-- Performance indexes for common query patterns

CREATE INDEX IF NOT EXISTS idx_expenses_user_date ON expenses(user_id, date DESC);
CREATE INDEX IF NOT EXISTS idx_expenses_user_type ON expenses(user_id, type);
CREATE INDEX IF NOT EXISTS idx_expenses_user_category ON expenses(user_id, category);
CREATE INDEX IF NOT EXISTS idx_gmail_syncs_user_status ON gmail_syncs(user_id, status);
CREATE INDEX IF NOT EXISTS idx_contacts_user_name ON contacts(user_id, name);
CREATE INDEX IF NOT EXISTS idx_device_tokens_user ON device_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_export_shares_export ON export_shares(export_id);
CREATE INDEX IF NOT EXISTS idx_subscription_events_user ON subscription_events(user_id);
