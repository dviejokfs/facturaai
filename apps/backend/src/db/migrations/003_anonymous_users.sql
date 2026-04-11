-- Anonymous user support for onboarding flow
-- Anonymous users get a temp JWT, rate-limited to 3 extractions, then merge into real user on sign-in.

ALTER TABLE users
    ADD COLUMN IF NOT EXISTS is_anonymous BOOLEAN NOT NULL DEFAULT FALSE;

-- Allow NULL email for anonymous users (they have no email until they sign in)
ALTER TABLE users
    ALTER COLUMN email DROP NOT NULL;

-- Track extraction count for anonymous rate limiting
ALTER TABLE users
    ADD COLUMN IF NOT EXISTS anonymous_extractions INT NOT NULL DEFAULT 0;

-- Index to clean up stale anonymous users periodically
CREATE INDEX IF NOT EXISTS idx_users_anonymous
    ON users(is_anonymous, created_at) WHERE is_anonymous = TRUE;

-- Store anonymous_token in oauth_states for merging after Google sign-in
ALTER TABLE oauth_states
    ADD COLUMN IF NOT EXISTS anonymous_token TEXT;
