# InvoScanAI — iOS App

Native SwiftUI app for the InvoScanAI MVP. AI-powered expense autopilot for Spanish autónomos.

## Requirements

- Xcode 16+ (uses `PBXFileSystemSynchronizedRootGroup`, Xcode 16 feature)
- iOS 17+ deployment target
- Swift 5

## Run

```bash
open InvoScanAI.xcodeproj
```

Then hit ⌘R. The app runs standalone with in-memory mock data — no backend required.

## Architecture

```
InvoScanAI/
├── InvoScanAIApp.swift          # @main, injects stores
├── Models/
│   └── Expense.swift           # Core domain types
├── Services/
│   ├── AuthService.swift       # Google sign-in stub
│   ├── ExpenseStore.swift      # ObservableObject, CRUD + aggregates
│   ├── MockData.swift          # Sample Spanish invoices
│   └── CSVExporter.swift       # Gestoría-ready CSV export
├── Views/
│   ├── RootView.swift          # Auth gate + TabView
│   ├── OnboardingView.swift    # Google sign-in landing
│   ├── DashboardView.swift     # Quarterly summary + IVA totals
│   ├── ExpensesListView.swift  # Searchable list + swipe actions
│   ├── ExpenseDetailView.swift # Edit/confirm flow
│   ├── ScanView.swift          # VisionKit camera + manual entry
│   ├── ExportView.swift        # CSV share sheet
│   └── SettingsView.swift      # Account, integrations, pricing
├── Utilities/
│   └── Formatters.swift        # es_ES currency/date formatters
└── Resources/
    └── Info.plist              # Camera usage, Spanish locale
```

## What's mocked

- **Google Sign-In**: `AuthService.signInWithGoogle()` returns a fake user. Swap for `GoogleSignIn` SDK + Gmail read-only scope in production.
- **Gmail sync**: `ExpenseStore.syncGmail()` simulates pulling new invoices. Wire to the Rust backend's `/api/gmail/sync` endpoint.
- **AI extraction**: Camera scans are not OCR'd; a hardcoded expense is inserted. Wire to backend `/api/expenses/upload` which calls Claude.
- **Persistence**: In-memory only. Add SwiftData / backend API for real storage.

## Next steps to productionize

1. Replace `AuthService` with `GoogleSignIn-iOS` + backend token exchange
2. Add `APIClient` targeting the Rust Axum backend (JWT auth)
3. Replace `ExpenseStore` in-memory state with SwiftData + API sync
4. Wire `DocumentScanner` result → upload → backend Claude extraction
5. Add Spanish `Localizable.strings` for App Store submission
6. Add App Icon (currently empty slot)
7. StoreKit 2 for Pro/Business subscriptions
