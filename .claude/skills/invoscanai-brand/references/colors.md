# Color Reference

Full spec in `BRANDING.md` §2. This file is the quick-lookup cheat sheet.

## The one color that matters

**`#4B39C7`** — InvoScanAI indigo. This is the app's `AccentColor.colorset` and the primary brand color. When in doubt, this is the answer.

## Full palette

### Primary (indigo/violet spine)
| Token | Hex | Purpose |
|-------|-----|---------|
| `--color-primary` | `#4B39C7` | CTAs, active states, logo, icon tints |
| `--color-primary-light` | `#7C6BE8` | Hover, secondary emphasis |
| `--color-primary-dark` | `#312E81` | Gradient start, pressed states |
| `--color-primary-50` | `#EEF0FF` | Tinted backgrounds (badges, chips) |
| `--color-accent` | `#7C3AED` | Gradient mid, Pro/premium surfaces |
| `--color-accent-light` | `#A78BFA` | Gradient end region |

### Signature gradient
```css
background: linear-gradient(165deg, #312E81 0%, #6D28D9 40%, #7C3AED 60%, #8B5CF6 100%);
```
This exact gradient appears in: `FirstUseView` soft variant (at low opacity), `PaywallView` hero, App Store screenshot frames, app preview videos. Don't tweak the stops.

### Semantic (fixed meanings — don't repurpose)
| Role | Hex | SwiftUI | Use |
|------|-----|---------|-----|
| Success / Income | `#34C759` | `.green` | Confirmations, income transactions, "done" checkmarks |
| Warning | `#FF9500` | `.orange` | Error banners, expense arrows |
| Error / Gmail | `#FF3B30` | `.red` | Destructive actions, Gmail icon accent |
| Info / PDF | `#007AFF` | `.blue` | Document pickers, info badges |
| Premium / Pro | `#FFCC00` | `.yellow` | Crown icons, trial banners, Pro badges |
| Teal (accountant) | `#30B0C7` | `.teal` | Client role, accountant setup |

### Neutrals (iOS-aligned)
| Token | Light | Dark |
|-------|-------|------|
| `--color-bg` | `#FFFFFF` | `#000000` |
| `--color-surface` | `#F2F2F7` | `#1C1C1E` |
| `--color-surface-2` | `#FFFFFF` | `#2C2C2E` |
| `--color-border` | `#E5E5EA` | `#38383A` |
| `--color-text-primary` | `#000000` | `#FFFFFF` |
| `--color-text-secondary` | `#3C3C43` | `#EBEBF5` |
| `--color-text-muted` | `#8E8E93` | `#8E8E93` |

## Quick rules

- **Background of any screen**: `systemGroupedBackground` (`#F2F2F7`), never pure white.
- **Card background**: `secondarySystemGroupedBackground` (`#FFFFFF` in light, `#2C2C2E` in dark).
- **Badges/chips**: `role-color.opacity(0.1)` background + solid role-color foreground.
- **Hero icon wells**: `Circle().fill(Color.indigo.opacity(0.12))`.
- **Borders**: rarely visible. Prefer fills for separation. When needed, 1px `role-color.opacity(0.3)`.

## SwiftUI shortcuts

The codebase uses `Color.indigo` — this is close to but NOT identical to our `#4B39C7`. Both are acceptable; they read as the same brand color. If you need the exact brand hex in SwiftUI:

```swift
Color(red: 0.294, green: 0.224, blue: 0.780)  // #4B39C7
// or via asset catalog:
Color("AccentColor")
```

## Tailwind config snippet

```js
// tailwind.config.ts
export default {
  theme: {
    extend: {
      colors: {
        brand: {
          DEFAULT: '#4B39C7',
          50: '#EEF0FF',
          100: '#DDE0FF',
          500: '#4B39C7',
          600: '#3F2FA8',
          700: '#312E81',
          900: '#1E1B4B',
        },
        accent: {
          DEFAULT: '#7C3AED',
          light: '#A78BFA',
          dark: '#6D28D9',
        },
      },
      backgroundImage: {
        'brand-gradient': 'linear-gradient(165deg, #312E81 0%, #6D28D9 40%, #7C3AED 60%, #8B5CF6 100%)',
      },
    },
  },
};
```
