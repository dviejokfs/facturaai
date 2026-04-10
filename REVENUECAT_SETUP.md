# RevenueCat Setup — Last Manual Step

Everything in code is ready. Once you do the steps below, purchases work end-to-end.

## 1. Sign up
1. Create account at https://app.revenuecat.com
2. Create project "InvoScanAI" → add iOS app with bundle id `es.kungfusoftware.invoscanai`

## 2. Products (must match `apps/ios/InvoScanAI/Configuration.storekit`)
Create in App Store Connect (or use the storekit file in sandbox):
- `invoscanai_pro_monthly` — €12.99/mo, 14-day free trial
- `invoscanai_pro_yearly` — €99/yr, 14-day free trial
- `invoscanai_business_monthly` — €24.99/mo
- `invoscanai_business_yearly` — €199/yr

Import them in RevenueCat → Products.

## 3. Entitlements
Create two entitlements and attach products:
- `pro` → both pro products
- `business` → both business products

## 4. Offering
Create offering `default` with packages for Pro Monthly, Pro Yearly, Business Monthly, Business Yearly.

## 5. Paywall (Paywalls v2)
RevenueCat dashboard → Paywalls → create paywall on `default` offering using the visual editor.

## 6. SDK key
Project Settings → API Keys → copy the **Public iOS SDK key** and paste into:
- `apps/ios/InvoScanAI/Resources/Info.plist` → `RC_PUBLIC_SDK_KEY_IOS`

## 7. Webhook
Project Settings → Integrations → Webhooks:
- URL: `https://<your-host>/webhooks/revenuecat`
- Authorization header: `Bearer <pick-a-strong-secret>`

Then in `apps/backend/.env`:
```
REVENUECAT_WEBHOOK_SECRET=<same-secret>
REVENUECAT_SECRET_API_KEY=<from RC dashboard>
REVENUECAT_PROJECT_ID=<from RC dashboard>
```

## 8. Xcode
- Add Swift packages: `https://github.com/RevenueCat/purchases-ios` (both `RevenueCat` and `RevenueCatUI`)
- Target → Signing & Capabilities → add **In-App Purchase**
- Scheme → Run → Options → StoreKit Configuration → `Configuration.storekit`

## 9. DB migration
```
cd apps/backend && bun src/db/migrate.ts
```

Done. The app calls `RevenueCatService.shared.identify(userId:)` after sign-in, paywall gates work via `.paywallGate(.pro, feature: "...")`, and webhooks land entitlement state in Postgres.
