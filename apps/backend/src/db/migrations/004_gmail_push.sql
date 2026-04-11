-- Gmail Pub/Sub push notification support
ALTER TABLE users
    ADD COLUMN IF NOT EXISTS gmail_history_id VARCHAR,
    ADD COLUMN IF NOT EXISTS gmail_watch_expiry TIMESTAMPTZ;
