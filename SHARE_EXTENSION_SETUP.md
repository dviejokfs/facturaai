# Share Extension Setup

Lets users send a photo or PDF to InvoScanAI from any iOS app via the share sheet.

Source files are already created in `apps/ios/InvoScanAIShareExtension/`. You need to add the target in Xcode (one time):

## 1. Create the target
File → New → Target → **Share Extension**
- Product Name: `InvoScanAIShareExtension`
- Language: Swift
- Embed in: InvoScanAI

After creation, **delete** the auto-generated `ShareViewController.swift`, `MainInterface.storyboard`, and `Info.plist` inside the new target folder, then drag in:
- `apps/ios/InvoScanAIShareExtension/ShareViewController.swift`
- `apps/ios/InvoScanAIShareExtension/Info.plist` (replace)
- `apps/ios/InvoScanAIShareExtension/InvoScanAIShareExtension.entitlements`

## 2. App Group capability
On **both** the `InvoScanAI` and `InvoScanAIShareExtension` targets, Signing & Capabilities → + → **App Groups**, then check/create:

```
group.es.kungfusoftware.invoscanai
```

The main app already has `apps/ios/InvoScanAI/InvoScanAI.entitlements` with this group.

## 3. URL scheme
Already declared in `Info.plist` as `invoscanai://`. The extension opens `invoscanai://share?f=<filename>` and `InvoScanAIApp.onOpenURL` ingests via `SharedInboxService`.

## 4. Test
Build & run on device, open Photos, tap Share, select InvoScanAI. The extension copies the file into the App Group container, opens the host app, and the new expense appears at the top of the list (uploaded via `/api/expenses/upload`).
