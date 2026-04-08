# Share Extension Setup

Lets users send a photo or PDF to FacturaAI from any iOS app via the share sheet.

Source files are already created in `apps/ios/FacturaAIShareExtension/`. You need to add the target in Xcode (one time):

## 1. Create the target
File → New → Target → **Share Extension**
- Product Name: `FacturaAIShareExtension`
- Language: Swift
- Embed in: FacturaAI

After creation, **delete** the auto-generated `ShareViewController.swift`, `MainInterface.storyboard`, and `Info.plist` inside the new target folder, then drag in:
- `apps/ios/FacturaAIShareExtension/ShareViewController.swift`
- `apps/ios/FacturaAIShareExtension/Info.plist` (replace)
- `apps/ios/FacturaAIShareExtension/FacturaAIShareExtension.entitlements`

## 2. App Group capability
On **both** the `FacturaAI` and `FacturaAIShareExtension` targets, Signing & Capabilities → + → **App Groups**, then check/create:

```
group.es.kungfusoftware.facturaai
```

The main app already has `apps/ios/FacturaAI/FacturaAI.entitlements` with this group.

## 3. URL scheme
Already declared in `Info.plist` as `facturaai://`. The extension opens `facturaai://share?f=<filename>` and `FacturaAIApp.onOpenURL` ingests via `SharedInboxService`.

## 4. Test
Build & run on device, open Photos, tap Share, select FacturaAI. The extension copies the file into the App Group container, opens the host app, and the new expense appears at the top of the list (uploaded via `/api/expenses/upload`).
