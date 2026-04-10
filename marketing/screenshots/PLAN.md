# InvoScanAI — App Store Screenshot Plan

## Required sizes (App Store Connect, 2026)

Apple requires only the **6.9" display** (iPhone 17 Pro Max, 1320 × 2868) to be
uploaded — it is auto-scaled for all smaller devices. We also ship 6.5" for
legacy listings.

| Slot | Device              | Portrait size (px) |
| ---- | ------------------- | ------------------ |
| 1    | iPhone 17 Pro Max   | 1320 × 2868        |
| 2    | iPhone 15 Pro Max   | 1290 × 2796        |
| 3    | iPhone 8 Plus       | 1242 × 2208        |
| 4    | iPad Pro 13"        | 2064 × 2752        |

## The 6 screenshots (in scroll order)

Each frame pairs one screen with a punchy headline overlaid at the top third
(white text on a muted gradient band). Keep copy under 6 words.

1. **"Receipts to deductions. In seconds."**
   — Dashboard with EUR + USD summary cards visible (multi-currency hero).

2. **"Snap it. We handle the rest."**
   — ScanView with camera overlay + AI extraction preview sliding up.

3. **"Gmail invoices, auto-imported."**
   — Expenses list populated after Gmail sync, green "Synced" pill.

4. **"One ZIP your accountant loves."**
   — ExportView showing per-currency totals + Download ZIP button highlighted.

5. **"Works in every currency. Never converts."**
   — Expenses list with mixed EUR/USD/GBP/JPY rows.

6. **"14-day free trial. No card."**
   — Onboarding final page (trial CTA).

## Production pipeline

1. **Generate** raw screenshots with `fastlane snapshot` (UI test target
   `InvoScanAIUITests/ScreenshotUITests.swift` drives the nav flow).
2. **Frame** with `fastlane frameit` — uses `Framefile.json` for layout +
   `title.strings` for localized copy.
3. **Export** final PNGs into `marketing/screenshots/framed/<locale>/` ready to
   drag into App Store Connect.

### Commands

```bash
cd apps/ios
bundle exec fastlane snapshot   # runs UI tests on required simulators
bundle exec fastlane frameit    # frames + overlays titles
```

### Locales to ship at launch

- `en-US` — primary
- `es-ES` — secondary (founder's home market)
- `en-GB`, `de-DE`, `fr-FR`, `pt-BR` — phase 2

## Asset checklist

- [ ] Populate `MockData.sampleExpenses()` with 3+ currencies for demo state
- [ ] Build a debug flag `-UITestScreenshotMode` that auto-signs in + seeds the
      store with rich mock data (no real network)
- [ ] Record the UI test flow (tap Dashboard → Scan → Expenses → Export →
      Settings → Onboarding)
- [ ] Write `Framefile.json` with the 6 titles per locale
- [ ] Run snapshot for each required device
- [ ] Run frameit
- [ ] Upload via `fastlane deliver`
