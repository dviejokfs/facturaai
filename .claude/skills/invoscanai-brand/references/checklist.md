# Brand Review Checklist

Run through this before calling any visible change done. If any box is unchecked, fix it.

## Color

- [ ] Primary CTA is `#4B39C7` / `Color.indigo` / `Color("AccentColor")`
- [ ] Only ONE primary CTA per screen (other buttons are surface or ghost)
- [ ] No unapproved accent colors introduced (no teal/green/red as brand — only as semantic)
- [ ] Screen background is `systemGroupedBackground` (`#F2F2F7`), not pure white
- [ ] Card backgrounds are `secondarySystemGroupedBackground`
- [ ] Brand gradient (if used) is the exact 4-stop version and only on decorative surfaces
- [ ] Text contrast passes WCAG AA (4.5:1 body, 3:1 large)
- [ ] Dark mode works — test it

## Typography

- [ ] All headings use `.system(..., design: .rounded)` (iOS) or Nunito (web)
- [ ] Body text uses `.body` / `.subheadline` / system sans
- [ ] Weights are 400 / 500 / 600 / 700 only — no 300, no 800
- [ ] No italic, no uppercase-for-emphasis
- [ ] Money columns use tabular numerals
- [ ] Nothing smaller than 12pt / 11px for readable content
- [ ] Dynamic Type respected on iOS (no hardcoded sizes in list rows)

## Iconography

- [ ] SF Symbols on iOS / Lucide on web (no mixing libraries)
- [ ] Canonical icons for core concepts (see `icons.md`)
- [ ] Hero icons sit in 12%-opacity colored circle wells
- [ ] Icon sizes follow the scale: 16 inline / 20–24 list / 36–56 hero

## Layout

- [ ] 8pt grid respected (4pt half-steps OK)
- [ ] Horizontal screen padding is 20–24pt
- [ ] Card radius 16pt, button radius 14pt, input radius 12pt
- [ ] Primary button has `padding(.vertical, 16)` and `frame(maxWidth: .infinity)`
- [ ] Section gaps are 24–32pt vertical

## Motion

- [ ] Transitions are `.easeInOut(duration: 0.3)` by default
- [ ] Step flows use asymmetric slide transitions (trailing-in, leading-out)
- [ ] AI/loading states use the extraction overlay pattern (pulsing ring + cycling text)
- [ ] No animations longer than 500ms for UI state changes

## Copy

- [ ] No forbidden words: just, simply, easily, leverage, unlock, empower, revolutionize, seamless, robust, solutions, platform, journey, game-changer
- [ ] No emojis in product copy (marketing gets max 1 per surface)
- [ ] No exclamation marks except in genuine success confirmations
- [ ] No rhetorical questions in headlines
- [ ] Outcome-first phrasing ("One ZIP your accountant loves." not "Export feature")
- [ ] Concrete nouns/verbs, not abstractions ("47 invoices" not "items")
- [ ] Tax terms kept in Spanish even in English copy (IVA, IRPF, NIF, autónomo, gestor)

## Localization

- [ ] New string exists in both `en.lproj/Localizable.strings` and `es.lproj/Localizable.strings`
- [ ] Keys follow existing section prefixes (`onboarding.*`, `settings.*`, `paywall.*`, etc.)
- [ ] No hardcoded English strings in SwiftUI views — all through `NSLocalizedString(...)`
- [ ] Copy translates cleanly (no English-only idioms)

## Accessibility

- [ ] All interactive elements have accessibility labels
- [ ] Icon-only buttons have `.accessibilityLabel(...)`
- [ ] Hit targets ≥ 44×44pt
- [ ] Color is never the only signal (pair with icon or text)
- [ ] VoiceOver flow tested for new screens

## Platform fit

- [ ] On iOS: follows SwiftUI idioms, uses Form/List where appropriate
- [ ] "Sign in with Apple/Google" buttons use vendor-approved styling
- [ ] Paywall uses RevenueCat's `PaywallView` component when possible
- [ ] Nothing fights the platform's native patterns
