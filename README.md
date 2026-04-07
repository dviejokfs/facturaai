# FacturaAI

AI-powered financial autopilot for Spanish autónomos. Monorepo containing all components.

> **Status**: MVP in progress. See PRD for full product spec.

## Monorepo layout

```
facturaai/
├── apps/
│   ├── ios/            # Native SwiftUI iOS app (Xcode 16+, iOS 17+)
│   └── backend/        # Bun + Hono API server (Postgres, Claude, Gmail)
├── package.json        # Workspace root
└── README.md
```

## Architecture overview

```
┌────────────┐   facturaai://auth   ┌───────────────────┐   Gmail API    ┌────────┐
│  iOS app   │◀────────────────────▶│  Bun/Hono backend │◀──────────────▶│ Google │
│ (SwiftUI)  │   JWT Bearer         │                   │                └────────┘
│            │◀────────────────────▶│  - OAuth/JWT      │
│  Keychain  │   REST /api/*        │  - Gmail sync     │   Claude API   ┌────────┐
│            │                      │  - PDF extraction │◀──────────────▶│ Claude │
└────────────┘                      │  - CSV export     │                └────────┘
                                    │                   │   S3/R2        ┌────────┐
                                    │  Postgres + S3    │◀──────────────▶│Storage │
                                    └───────────────────┘                └────────┘
```

### Auth flow

1. iOS opens `ASWebAuthenticationSession` → `GET {BACKEND}/auth/google/start`
2. Backend redirects to Google consent with Gmail `readonly` scope
3. Google → `GET {BACKEND}/auth/google/callback?code=...`
4. Backend exchanges code, stores `refresh_token`, mints JWT
5. Backend redirects to `facturaai://auth?token=<jwt>`
6. iOS captures token from the custom URL scheme, stores in Keychain
7. All subsequent API calls: `Authorization: Bearer <jwt>`

### Gmail sync flow

1. iOS: `POST /api/gmail/sync` → returns job id
2. Backend worker lists Gmail messages with PDF attachments matching invoice patterns
3. For each new attachment: download → store in S3 → extract via Claude → insert expense
4. iOS polls `GET /api/expenses?since=<timestamp>` or `GET /api/gmail/sync/:id`

### Receipt scan flow

1. iOS: VisionKit camera → image
2. `POST /api/expenses/upload` (multipart image)
3. Backend: S3 upload → Claude vision extraction → returns Expense JSON
4. iOS inserts into local store

## Getting started

### Backend

```bash
cd apps/backend
cp .env.example .env    # fill in GOOGLE_CLIENT_ID, ANTHROPIC_API_KEY, DATABASE_URL
bun install
bun run db:migrate
bun run dev
```

### iOS

```bash
cd apps/ios
open FacturaAI.xcodeproj
```

Update `APIClient.baseURL` in `apps/ios/FacturaAI/Services/APIClient.swift` to point to your backend (default: `http://localhost:3000`).

## PRD

FacturaAI is an AI financial assistant for Spanish autónomos. See the full PRD in the project notes. Targets: 5,000 free users and 150 paid subscribers (€1,050 MRR) within 6 months.

## License

© 2026 Kung Fu Software SL
