# FacturaAI — Launch Roadmap

> What's actually missing to ship this product and start earning money.
> Generated 2026-04-09 from a full codebase audit.

---

## Current State

FacturaAI has a solid foundation: AI invoice extraction (Anthropic Claude), Google/Apple auth, Gmail auto-sync, multi-currency support, expense/income classification, CSV/XLSX export, contacts auto-creation, and a well-designed iOS UI with onboarding. The backend (Bun/Hono) and database schema are clean.

**But it cannot launch today.** There are hard blockers from Apple, security vulnerabilities, and the monetization pipeline is entirely unconnected — every feature is free, forever, for everyone.

---

## Phase 0: CRITICAL BLOCKERS (Must fix before any TestFlight)

These will cause App Store rejection or immediate security/financial damage.

### 1. Production API URL
- **Problem**: `APIClient.swift` baseURL is hardcoded to `http://192.168.1.133:3005` (your local network). The app literally won't work for anyone else.
- **Fix**: Environment-based config. Use a `#if DEBUG` / production URL switch, or read from Info.plist. Deploy backend to a real server (Railway, Fly.io, Render, or your own VPS).
- **Effort**: 1 day (backend deploy) + 30 min (iOS config)

### 2. Apple Sign-In Token NOT Verified
- **Problem**: Backend decodes Apple's identity token but **never verifies the signature** against Apple's public keys. Anyone can forge an Apple login.
- **Fix**: Verify JWT signature using Apple's JWKS endpoint (`https://appleid.apple.com/auth/keys`).
- **Effort**: 2-3 hours

### 3. Account Deletion (Apple Requirement)
- **Problem**: No "Delete my account" anywhere. Apple requires this since June 2022. **Hard rejection.**
- **Fix**: Add backend `DELETE /api/account` that cascades user data. Add button in Settings with confirmation dialog.
- **Effort**: 4-6 hours

### 4. PrivacyInfo.xcprivacy
- **Problem**: Required since Spring 2024. Apple rejects without it. Must declare reasons for using UserDefaults, Date APIs, file timestamp APIs.
- **Fix**: Add the manifest file with proper API reason declarations.
- **Effort**: 1-2 hours

### 5. Public Extract Endpoint — Open Cost Exposure
- **Problem**: `POST /api/extract` requires NO auth and calls Anthropic API. Anyone who finds it can rack up your AI bill with unlimited requests.
- **Fix**: Either require auth, add aggressive rate limiting (IP-based), or remove it entirely.
- **Effort**: 1-2 hours

### 6. CORS Wide Open
- **Problem**: `origin: "*"` allows any website to make authenticated API calls.
- **Fix**: Restrict to your app's domain or remove CORS entirely (mobile-only API doesn't need it).
- **Effort**: 30 min

---

## Phase 1: MONETIZATION (Must fix before charging money)

The entire payment pipeline is scaffolded but **nothing is connected**. Free users have 100% access to every feature.

### 7. Backend Plan Enforcement
- **Problem**: `requireEntitlement()` function exists but is **never called** from any route. Upload, export, Gmail sync — all free.
- **Fix**: Add entitlement checks to premium routes:
  - `POST /api/expenses/upload` — limit free users to X scans/month
  - `POST /api/gmail/sync` — pro/business only
  - `POST /api/export/jobs` — pro/business only (or limit free to CSV-only)
  - Trial expired → reject with 403 + clear error
- **Effort**: 4-6 hours

### 8. iOS Feature Gating
- **Problem**: `.paywallGate()` modifier exists but is **never applied** to any view. No paywall appears when features are used.
- **Fix**: Apply `.paywallGate(.pro)` to: Gmail sync, export, bulk operations. Show paywall when trial expires.
- **Effort**: 3-4 hours

### 9. Trial Expiry Enforcement
- **Problem**: When trial expires, nothing happens. User keeps using everything.
- **Fix**: Server returns 403 for expired trials. iOS shows a blocking paywall that can't be dismissed (only upgrade or sign out).
- **Effort**: 3-4 hours

### 10. RevenueCat SDK Key
- **Problem**: `RC_PUBLIC_SDK_KEY_IOS` is empty in Info.plist. Purchases literally won't work.
- **Fix**: Create RevenueCat project, configure products in App Store Connect, add the key.
- **Effort**: 2-3 hours (plus App Store Connect setup)

### 11. PaywallView Subscribe Button is a No-Op
- **Problem**: The manual `PaywallView.swift` has `// TODO: StoreKit 2 purchase`. It does nothing.
- **Fix**: Either wire it to RevenueCat's purchase flow or replace entirely with RevenueCatUI's `PaywallView`.
- **Effort**: 2 hours

### 12. Remove Duplicate Subscription System
- **Problem**: Both `SubscriptionService.swift` (raw StoreKit 2) and `RevenueCatService.swift` exist. Confusing.
- **Fix**: Pick RevenueCat (it's better for cross-platform), remove `SubscriptionService.swift`.
- **Effort**: 1 hour

---

## Phase 2: RELIABILITY (Must fix before real users)

### 13. File Size Limits
- **Problem**: No file size limit on upload. Users (or attackers) can upload 1GB files and crash the server.
- **Fix**: Add `Content-Length` check (max 20MB) in upload middleware.
- **Effort**: 1 hour

### 14. Rate Limiting
- **Problem**: No rate limiting on any endpoint. DDoS and abuse are trivial.
- **Fix**: Add rate limiting middleware (e.g., `hono-rate-limiter`). Suggested: 60 req/min general, 10 req/min on upload/extract.
- **Effort**: 2-3 hours

### 15. Error Messages Leak Internals
- **Problem**: Global error handler returns raw `err.message` to clients, potentially exposing DB errors, stack traces.
- **Fix**: Return generic error message in production. Log full error server-side.
- **Effort**: 1 hour

### 16. Gmail Sync Robustness
- **Problem**: No retry/backoff for Google API rate limits. No recovery of stuck jobs. No concurrency control. No `after:` date filter (re-scans everything).
- **Fix**: Add exponential backoff, use `after:` filter from `last_sync_at`, add stuck-job recovery, prevent duplicate syncs.
- **Effort**: 4-6 hours

### 17. Push Notifications Incomplete
- **Problem**: No `UIBackgroundModes: remote-notification` in Info.plist. No notification tap handling. No foreground display.
- **Fix**: Add background mode, implement `UNUserNotificationCenterDelegate`, handle tap → navigate to expense.
- **Effort**: 2-3 hours

### 18. Offline / Error States
- **Problem**: No loading indicators during data fetch. No error UI when API fails. No "you're offline" state. Errors silently swallowed.
- **Fix**: Add network reachability monitoring, loading skeletons, error banners with retry.
- **Effort**: 4-6 hours

---

## Phase 3: LEGAL & COMPLIANCE (Must fix before public launch)

### 19. Privacy Policy & Terms of Service
- **Problem**: App links to `https://invoscanai.com/terms` and `https://invoscanai.com/privacy` but these pages likely don't exist yet.
- **Fix**: Write and host actual privacy policy and terms. Must cover: what data is collected, Anthropic API data processing, Google OAuth data storage, data retention, user rights.
- **Effort**: 1-2 days (consider using a generator like Iubenda, then customize)

### 20. Auto-Renewal Terms Disclosure
- **Problem**: Apple requires explicit text near the subscribe button explaining auto-renewal terms, pricing, and cancellation.
- **Fix**: Add required disclosure text to paywall view.
- **Effort**: 1 hour

### 21. GDPR Full Data Export
- **Problem**: Export only covers expenses. GDPR requires exporting ALL personal data (profile, contacts, subscription history, etc.).
- **Fix**: Add `GET /api/account/export` endpoint that bundles everything.
- **Effort**: 3-4 hours

### 22. Data Processing Disclosure
- **Problem**: Invoice images/PDFs are sent to Anthropic's API for extraction. Users must know this.
- **Fix**: Add disclosure in privacy policy and a brief in-app notice on first scan.
- **Effort**: 2 hours

---

## Phase 4: INFRASTRUCTURE (Before scaling)

### 23. Deploy Backend to Production
- **Where**: Railway, Fly.io, Render, or your own VPS. Need: Postgres, S3-compatible storage (R2/Backblaze B2), HTTPS.
- **Effort**: Half day
- **Suggested stack**: 
  - Fly.io (backend) + Supabase or Neon (Postgres) + Cloudflare R2 (storage)
  - OR Railway (all-in-one with Postgres add-on) + Cloudflare R2

### 24. Structured Logging & Error Tracking
- **Problem**: All errors go to stdout. No alerting, no Sentry.
- **Fix**: Add Sentry (free tier), structured JSON logs.
- **Effort**: 2-3 hours

### 25. Database Migrations
- **Problem**: Schema changes = "run the whole schema.sql again". No versioning, no rollback.
- **Fix**: Use a migration tool (drizzle-kit, dbmate, or simple numbered SQL files).
- **Effort**: 3-4 hours

### 26. Orphaned File Cleanup
- **Problem**: Deleting an expense doesn't delete its S3 file. Files accumulate forever.
- **Fix**: Delete S3 object on expense deletion. Add a periodic cleanup job for orphans.
- **Effort**: 2 hours

---

## Phase 5: POLISH (Before Product Hunt / marketing)

### 27. Localization Cleanup
- **Hardcoded English strings in**: OnboardingView.swift (12+ strings), ExpenseDetailView.swift (amounts labels), SwipeReviewView.swift, SettingsView.swift (integration names).
- **Effort**: 2-3 hours

### 28. Accessibility
- **Problem**: Zero `accessibilityLabel` modifiers. Fixed font sizes that don't scale with Dynamic Type. Color-only status indicators.
- **Fix**: Add accessibility labels to custom controls, use `.font(.headline)` instead of `.system(size:)`, add non-color cues.
- **Effort**: 4-6 hours

### 29. Launch Screen
- **Problem**: Empty white launch screen.
- **Fix**: Add app logo/branding.
- **Effort**: 1 hour

### 30. Email Integration
- **Problem**: No emails at all. No welcome email, no accountant notifications, no export-ready notifications.
- **Fix**: Integrate Resend or SendGrid. Add: welcome email, export completion email, optional accountant forwarding.
- **Effort**: 4-6 hours

---

## Launch Priority Order

```
Week 1: Phase 0 (Critical Blockers)
  ├── Deploy backend to production server
  ├── Fix Apple token verification
  ├── Add account deletion
  ├── Add PrivacyInfo.xcprivacy
  ├── Secure public extract endpoint
  └── Fix CORS

Week 2: Phase 1 (Monetization)
  ├── Set up App Store Connect products
  ├── Configure RevenueCat with real key
  ├── Enforce entitlements on backend routes
  ├── Apply paywallGate to iOS views
  ├── Enforce trial expiry
  └── Remove SubscriptionService duplicate

Week 3: Phase 2 + 3 (Reliability + Legal)
  ├── File size limits + rate limiting
  ├── Error handling cleanup
  ├── Privacy policy + Terms of Service
  ├── Auto-renewal disclosure
  ├── Gmail sync robustness
  └── Push notification fixes

Week 4: Phase 4 + 5 (Infrastructure + Polish)
  ├── Sentry + structured logging
  ├── Database migrations
  ├── Localization cleanup
  ├── Offline/error states
  ├── Launch screen
  └── TestFlight beta → Phase 3 (Beta Launch)
```

---

## Revenue Model Recommendation

Based on the current feature set:

| Plan | Price | Features |
|------|-------|----------|
| **Free** | €0 | 5 scans/month, manual entry only, no export |
| **Pro** | €9.99/mo or €79/yr | Unlimited scans, Gmail sync, CSV/XLSX export, contacts |
| **Business** | €19.99/mo or €159/yr | Everything in Pro + accountant forwarding, team support (future), priority support |

**Key gates:**
- Scan count (free = 5/mo, pro = unlimited)
- Gmail sync (pro+)
- Export (pro+)
- Accountant email forwarding (business)

---

## What's Actually GOOD and Launch-Ready

Don't lose sight of what works well:
- AI extraction quality is excellent (Claude Sonnet, 99% confidence on test invoices)
- Expense/income auto-classification via company name matching
- Multi-currency support with no conversion (correct for accounting)
- Contact auto-creation from scanned invoices
- Gmail sync with progress tracking
- Export system (CSV + XLSX + attachments ZIP) is production-quality
- RevenueCat webhook handler is properly built with idempotency
- Clean, modern iOS UI with good i18n foundation
- Country-aware tax ID system (44 countries)
- Onboarding flow with company setup

The product is ~70% there. The missing 30% is security, monetization wiring, and compliance — not features.
