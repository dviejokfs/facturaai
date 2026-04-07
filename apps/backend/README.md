# FacturaAI Backend

Bun + Hono API for FacturaAI. Handles Google OAuth, Gmail sync, Claude-powered invoice extraction, and Spanish-tax-aware CSV export.

## Stack

- **Runtime**: Bun
- **HTTP**: Hono
- **Database**: PostgreSQL via `Bun.SQL`
- **Auth**: Google OAuth 2.0 + JWT (`jose`)
- **AI**: Anthropic Claude Sonnet
- **Storage**: S3-compatible (RustFS locally, Cloudflare R2 in production)
- **Gmail**: `googleapis` with `gmail.readonly` scope

## Local development

### 1. Start Postgres + RustFS

```bash
docker compose up -d
```

- Postgres: `localhost:5432` (user/pass/db = `facturaai`)
- RustFS S3 API: `localhost:9000`
- RustFS console: `http://localhost:9001` (login: `facturaai` / `facturaai-secret`)

Create the bucket once:

```bash
# Via the RustFS console at localhost:9001, create bucket "facturaai-invoices"
# OR via aws CLI:
aws --endpoint-url http://localhost:9000 s3 mb s3://facturaai-invoices \
  --region auto \
  --profile facturaai
```

### 2. Configure env

```bash
cp .env.example .env
# fill in GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET, ANTHROPIC_API_KEY
# generate JWT_SECRET: openssl rand -base64 48
```

Google OAuth credentials: create at https://console.cloud.google.com/apis/credentials with redirect URI `http://localhost:3000/auth/google/callback` and scopes `email profile https://www.googleapis.com/auth/gmail.readonly`.

### 3. Migrate + run

```bash
bun install
bun run db:migrate
bun run dev
```

Server listens on `http://localhost:3000`.

## API

### Public

| Method | Path | Purpose |
|---|---|---|
| GET | `/` | Health/info |
| GET | `/health` | Liveness |
| GET | `/auth/google/start` | Begin OAuth flow (redirects to Google) |
| GET | `/auth/google/callback` | OAuth callback, redirects to `facturaai://auth?token=JWT` |

### Protected (require `Authorization: Bearer <jwt>`)

| Method | Path | Purpose |
|---|---|---|
| GET | `/auth/me` | Current user (email, plan, trial status) |
| GET | `/api/me` | JWT claims echo |
| GET | `/api/expenses` | List user expenses |
| GET | `/api/expenses/:id` | Get expense |
| PATCH | `/api/expenses/:id` | Edit/confirm expense |
| DELETE | `/api/expenses/:id` | Delete expense |
| POST | `/api/expenses/upload` | Upload receipt image (multipart `file`), returns extracted expense |
| POST | `/api/gmail/sync` | Start Gmail sync job |
| GET | `/api/gmail/sync/:id` | Poll sync job status |
| GET | `/api/gmail/sync` | List recent syncs |
| GET | `/api/export/csv?quarter=2026-Q2` | CSV download |
| GET | `/api/export/summary/:quarter` | Totals + by-category JSON |

## Trial model

New users get `plan = 'trial'` and `trial_ends_at = NOW() + 14 days`. The iOS app reads `trial_days_left` and `trial_expired` from `/auth/me` and shows a paywall when the trial expires. StoreKit subscription → backend webhook will flip the plan to `pro` or `business` (TODO).

## Database schema

See `src/db/schema.sql`. Core tables: `users`, `expenses`, `gmail_syncs`, `oauth_states`.

## Claude extraction

`src/services/extract.ts` handles both PDF (text extraction via `pdf-parse`) and images (Claude vision). The system prompt is tuned for Spanish invoices — it knows about IVA rates, IRPF retention, and maps vendors to Spanish tax categories (`hosting`, `software`, `representacion`, etc.).
