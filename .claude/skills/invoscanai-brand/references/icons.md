# Iconography Reference

Full spec in `BRANDING.md` §7.

## Source

- **iOS**: SF Symbols (system). Already available, free, consistent with platform.
- **Web**: [Lucide](https://lucide.dev) — closest visual match to SF Symbols.

## Canonical mappings

Every core concept has a fixed icon. Keep these consistent across iOS, web, marketing, and docs.

| Concept | SF Symbol | Lucide | Color |
|---------|-----------|--------|-------|
| Scan / camera | `camera.fill` / `doc.viewfinder.fill` | `camera` / `scan-line` | indigo |
| AI / extraction | `sparkles` / `cpu` / `sparkles.rectangle.stack.fill` | `sparkles` / `cpu` | indigo |
| Export / share | `paperplane.fill` / `square.and.arrow.up` | `send` / `share` | indigo |
| Company / vendor | `building.2.fill` | `building-2` | indigo |
| Gmail / inbox | `envelope.fill` | `mail` | **red** |
| Accountant / client | `person.text.rectangle.fill` | `user-round` | **teal** |
| Pro / premium | `crown.fill` | `crown` | **yellow** |
| Income | `arrow.down.circle.fill` | `arrow-down-circle` | **green** |
| Expense | `arrow.up.circle.fill` | `arrow-up-circle` | **red/orange** |
| Success | `checkmark.circle.fill` | `check-circle-2` | **green** |
| Warning | `exclamationmark.triangle.fill` | `alert-triangle` | **orange** |
| Error | `xmark.circle.fill` | `x-circle` | **red** |
| Tax / VAT | `percent` | `percent` | indigo |
| Calendar / quarter | `calendar` | `calendar` | indigo |
| Settings | `gearshape.fill` | `settings` | secondary |
| Client (role on invoice) | `tray.and.arrow.down.fill` | `inbox` | **teal** |
| Vendor (role on invoice) | `paperplane.fill` | `send` | **orange** |
| PDF upload | `doc.fill` | `file-text` | **blue** |
| Photo library | `photo.on.rectangle` | `image` | **purple** |

## Sizing

| Context | Size |
|---------|------|
| Inline with text | 16pt / 1em |
| List row leading | 20–24pt |
| Tab bar | 24pt |
| Action card icon (white-on-color tile) | 48pt tile, 22pt glyph |
| Hero icon in circle well | 36–56pt |
| Welcome hero | 56pt in 120pt circle |

## Weight

- `.regular` for inline body icons
- `.semibold` when emphasized
- `.fill` variants for hero/circle-backed icons
- Never mix `.fill` and outline variants on the same screen

## Hero icon well (the signature)

Every step header, empty state, modal hero uses this pattern:

```swift
ZStack {
    Circle()
        .fill(Color.indigo.opacity(0.12))
        .frame(width: 80, height: 80)
    Image(systemName: "building.2.fill")
        .font(.system(size: 40))
        .foregroundStyle(.indigo)
}
```

If the icon represents a *semantic* role (success, income, warning), use that semantic color instead of indigo — but keep the 12%-opacity circle pattern.

## Don'ts

- Don't invent custom icons when SF Symbols has one. Use the system.
- Don't use multicolor SF Symbols (`.palette`, `.multicolor` render modes) — we control color, not Apple.
- Don't combine icons from two different libraries (Lucide + Heroicons + Feather). Pick one per platform.
- Don't use icon-only buttons without a label except in standard contexts (close X, chevron, back arrow).
