# InvoScanAI — Brand Identity System

> AI that turns invoice chaos into clean, quarterly reports your accountant will love.

---

## 1. Brand Essence

### Mission
Give Spanish freelancers and small businesses their time back by turning every scrap of invoice evidence — paper, PDF, Gmail thread — into accountant-ready books with zero typing.

### Positioning
**The AI bookkeeper for autónomos.** Premium-feeling but indie-priced, ruthlessly fast, and quietly respectful of your data.

### Personality Attributes
| Attribute | Description |
|-----------|-------------|
| **Effortless** | Every task should feel like it took one tap. If the user has to think, we failed. |
| **Trustworthy** | We handle tax data. Calm, precise, "bank-grade" energy — never hype. |
| **Intelligent** | AI is the product, not a gimmick. Show the work (confidence %, step-by-step extraction) so users believe it. |
| **Pragmatic** | Written for the working autónomo, not the Silicon Valley demo reel. Spanish-first, IVA-fluent, tax-deadline aware. |
| **Minimal** | Deep indigo, one accent, lots of negative space. No decorative clutter. |

### Anti-Attributes (What We Are NOT)
- **Not "enterprise SaaS"** — no navy/gray corporate palette, no stock photos of people in suits pointing at dashboards.
- **Not playful/consumer** — no emojis in product copy, no rounded cartoon mascots, no Duolingo-style gamification.
- **Not a fintech neobank** — no neon greens, no "level-up your money" framing. We're a tool, not a lifestyle.
- **Not crypto/web3** — no gradients into pink, no "revolutionary" language.

### Brand References
- **Linear**: Craft, keyboard-fast, dark-first, restrained color use.
- **Stripe**: Calm authority, documentation-grade clarity, pastel-on-white panels.
- **Things 3 / Cultured Code**: iOS-native feel, SF Pro Rounded, tactile micro-animations.
- **RevenueCat dashboard**: Indigo/violet accent tone, dense but readable, "built by developers who ship."

---

## 2. Color System

The palette is **monochromatic indigo/violet** with one alert orange and one success green. Derived from the iOS `AccentColor` (`#4B39C7`) and the existing paywall/screenshot gradients (`#312e81 → #8b5cf6`).

### Primary Palette

```css
:root {
  /* Primary — Indigo (the brand) */
  --color-primary:        #4B39C7;  /* iOS AccentColor — CTAs, active states, logo */
  --color-primary-light:  #7C6BE8;  /* Hover, secondary CTAs */
  --color-primary-dark:   #312E81;  /* Gradient start, pressed states */
  --color-primary-50:     #EEF0FF;  /* Tinted backgrounds, badges */
  --color-primary-100:    #DDE0FF;
  --color-primary-500:    #4B39C7;  /* Alias */
  --color-primary-900:    #1E1B4B;

  /* Accent — Violet (gradient pair) */
  --color-accent:         #7C3AED;  /* Gradient mid, premium surfaces (Pro badges) */
  --color-accent-light:   #A78BFA;
  --color-accent-dark:    #6D28D9;

  /* Signature Gradient */
  --gradient-brand: linear-gradient(165deg, #312E81 0%, #6D28D9 40%, #7C3AED 60%, #8B5CF6 100%);
  --gradient-soft:  linear-gradient(160deg, rgba(75,57,199,0.08) 0%, rgba(124,58,237,0.04) 50%, transparent 100%);

  /* Neutrals — iOS systemGroupedBackground aligned */
  --color-bg:             #FFFFFF;
  --color-surface:        #F2F2F7;  /* iOS systemGroupedBackground */
  --color-surface-2:      #FFFFFF;  /* secondarySystemGroupedBackground (light) */
  --color-border:         #E5E5EA;
  --color-text-primary:   #000000;
  --color-text-secondary: #3C3C43;  /* 60% opacity overlay in iOS */
  --color-text-muted:     #8E8E93;
}
```

### Semantic Colors

Mapped to SwiftUI system colors already used in the app.

```css
:root {
  --color-success: #34C759;   /* SwiftUI .green — confirmation, income */
  --color-warning: #FF9500;   /* SwiftUI .orange — errors, warnings banner */
  --color-error:   #FF3B30;   /* SwiftUI .red — destructive, Gmail badge */
  --color-info:    #007AFF;   /* SwiftUI .blue — PDF/doc actions */
  --color-premium: #FFCC00;   /* SwiftUI .yellow — crown/trial/Pro highlight */
  --color-teal:    #30B0C7;   /* SwiftUI .teal — client role, accountant */
}
```

### Dark Mode Overrides

```css
[data-theme="dark"] {
  --color-bg:             #000000;
  --color-surface:        #1C1C1E;  /* systemGroupedBackground dark */
  --color-surface-2:      #2C2C2E;  /* secondarySystemGroupedBackground dark */
  --color-border:         #38383A;
  --color-text-primary:   #FFFFFF;
  --color-text-secondary: #EBEBF5;
  --color-text-muted:     #8E8E93;

  /* Primary stays the same — indigo works in both modes */
  --color-primary-light:  #9B8EFF;  /* Slightly lighter for dark bg contrast */
}
```

### Color Usage Rules
- **Do** use `--color-primary` for the *one* primary CTA per screen, active tab dots, progress indicators, and circular icon backgrounds at 12% opacity.
- **Do** use the brand gradient for hero sections, paywall headers, App Store screenshot frames, and marketing OG images — *never* for in-product content areas.
- **Do** pair indigo icons with `opacity(0.12)` circle backgrounds (see `FirstUseView` pattern) — this is our signature icon treatment.
- **Don't** ever introduce a second accent hue (teal/pink/red-as-brand). Red/orange/green/teal are *semantic* only.
- **Don't** use gradients on body text, form inputs, or list rows. Gradients are for decoration, not information.
- **Don't** use pure black on pure white — always prefer `systemGroupedBackground` (#F2F2F7) as the canvas so surfaces pop.

### Accessibility
- `#4B39C7` on `#FFFFFF`: **7.8:1** ✓ AAA
- `#4B39C7` on `#F2F2F7`: **7.4:1** ✓ AAA
- `#FFFFFF` on `#4B39C7`: **7.8:1** ✓ AAA (safe for white button text)
- All semantic colors (success/warning/error) pass AA at 16px+ against both light and dark backgrounds.

---

## 3. Typography

Apple-native on iOS, web-hosted elsewhere. We lean into **SF Pro Rounded** for display — it's what the app ships and it's what gives InvoScanAI its warm-but-precise feel.

### Font Stack

```css
:root {
  /* Display / Headlines — SF Pro Rounded equivalent */
  --font-display: 'SF Pro Rounded', 'Nunito', -apple-system, BlinkMacSystemFont, 'Segoe UI Rounded', sans-serif;

  /* Body / UI — SF Pro Text / Inter */
  --font-body: -apple-system, BlinkMacSystemFont, 'Inter', 'Segoe UI', Helvetica, Arial, sans-serif;

  /* Numeric / Tabular — tabular-nums for money columns */
  --font-numeric: 'SF Pro Text', 'Inter', system-ui;
  --numeric-features: "tnum" 1, "cv11" 1;

  /* Code / Mono — for tax IDs, CLI, code blocks */
  --font-mono: 'SF Mono', 'JetBrains Mono', Menlo, Consolas, monospace;
}
```

**Google Fonts import (for web/marketing):**
```html
<link href="https://fonts.googleapis.com/css2?family=Nunito:wght@600;700;800&family=Inter:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">
```

On iOS, use `.font(.system(size: X, weight: .bold, design: .rounded))` — this is the pattern throughout the codebase.

### Type Scale

| Level       | iOS SwiftUI                                      | Web (rem)        | Weight | Usage                                |
|-------------|--------------------------------------------------|------------------|--------|--------------------------------------|
| Display XL  | `.system(size: 38, weight: .bold, .rounded)`     | 2.75rem / 44px   | 700    | Onboarding welcome, paywall hero     |
| Display L   | `.system(size: 26, weight: .bold, .rounded)`     | 2.0rem / 32px    | 700    | Step titles, sheet headers           |
| H1          | `.system(size: 24, weight: .bold, .rounded)`     | 1.75rem / 28px   | 700    | Screen titles                        |
| H2 / .title3| `.title3`                                        | 1.25rem / 20px   | 600    | Card titles, section heads           |
| Headline    | `.headline`                                      | 1.0625rem / 17px | 600    | List row titles, emphasis            |
| Body        | `.body` / `.subheadline`                         | 1.0rem / 16px    | 400    | Paragraphs, descriptions             |
| Caption     | `.caption`                                       | 0.75rem / 12px   | 500    | Labels, metadata, tax ID rows        |
| Caption XS  | `.caption2`                                      | 0.6875rem / 11px | 400    | Footer links, terms                  |

### Typography Rules
- **Do** use `.rounded` design for all titles (Display XL → H1). It's our voice.
- **Do** use `tabular-nums` for money columns, quarterly totals, tax percentages.
- **Do** let iOS handle Dynamic Type — never hardcode font sizes in cells/list rows.
- **Don't** use display/rounded for body text or form fields — it reads as childish at small sizes.
- **Don't** go below 12px / `.caption` for any readable content.
- **Don't** use italic or uppercase for emphasis. Weight (600/700) is the only emphasis tool.

---

## 4. Logo

### Concept
**Icon**: A stylized document/invoice rectangle with a subtle sparkle (AI signal) overlaid, rendered in the brand indigo. The existing app icon (`AppIcon.png`) is the source of truth.

**Wordmark**: "InvoScanAI" set in SF Pro Rounded Bold with `letter-spacing: -0.01em`. The "AI" may be set in `--color-accent` (#7C3AED) to signal the intelligence layer — but only in marketing contexts, never inside the app.

### Variants
- **Primary**: App icon + wordmark — horizontal lockup for headers, splash screens.
- **Icon only**: App icon @ 60pt — home screen, favicons, share-sheet activities.
- **Wordmark only**: Text-only for footers, email signatures, docs.

### Clear Space
Minimum clear space = height of the "I" in the wordmark.

### Logo Don'ts
- Never stretch or distort the icon.
- Never recolor outside `--color-primary` / white / black.
- Never place on the brand gradient without a 16px white/indigo-900 halo.
- Never add shadows, strokes, or bevels.

---

## 5. Spacing & Layout

iOS uses an 8pt grid with 4pt half-steps. We mirror this on web.

### Spacing Scale

```css
:root {
  --space-xs:   0.25rem;  /*  4px — icon-to-label gap */
  --space-sm:   0.5rem;   /*  8px — tight rows */
  --space-md:   0.75rem;  /* 12px — card inner padding */
  --space-lg:   1rem;     /* 16px — default padding */
  --space-xl:   1.25rem;  /* 20px — card padding, section gutter */
  --space-2xl:  1.5rem;   /* 24px — horizontal screen padding */
  --space-3xl:  2rem;     /* 32px — section breaks, hero padding */
  --space-4xl:  3rem;     /* 48px — major section separators */
}
```

### Border Radius

```css
:root {
  --radius-xs:  0.5rem;   /*  8px — pills, small chips */
  --radius-sm:  0.625rem; /* 10px — inline badges */
  --radius-md:  0.75rem;  /* 12px — buttons, inputs, list rows */
  --radius-lg:  0.875rem; /* 14px — primary CTAs, action cards */
  --radius-xl:  1rem;     /* 16px — content cards, review panels */
  --radius-2xl: 1.75rem;  /* 28px — extraction overlay, modal sheets */
  --radius-full: 9999px;  /* Pills, avatar, step indicator dots */
}
```

### Container Widths
```css
:root {
  --container-sm: 28rem;   /* 448px — auth/sign-in sheets */
  --container-md: 40rem;   /* 640px — content-focused marketing pages */
  --container-lg: 64rem;   /* 1024px — standard landing pages */
  --container-xl: 80rem;   /* 1280px — wide dashboards */
}
```

### Signature Layout Patterns
- **Circle-icon header**: 80–120pt circle filled at 12% primary opacity, SF Symbol centered at 36–56pt in `.primary`. Used on every step header and empty state.
- **Action card**: 48pt colored square icon (white glyph on color fill), title + subtitle, chevron, inside a `secondarySystemGroupedBackground` rounded rectangle.
- **Step indicator**: Capsules (width 24pt active, 8pt inactive; height 8pt) filled primary for completed, `systemGray4` for pending.

---

## 6. Voice & Tone

### Writing Principles

| Principle | Description | Example |
|-----------|-------------|---------|
| **Outcome first** | Lead with what the user gets, never with how we built it. | "One ZIP your accountant loves." — not "AI-powered export engine." |
| **Concrete, not abstract** | Numbers, verbs, objects. No "solutions" or "platforms." | "Scan up to 10 invoices free." — not "Try our tier." |
| **Calm confidence** | State facts. No exclamation marks except in success states. | "Your invoices are encrypted at rest." — not "Your data is SUPER secure!!" |
| **Spanish-first mindset** | Write copy that translates cleanly to `es-ES`. Avoid English-only idioms. | "Ready to send" travels; "Good to go!" doesn't. |
| **Respect the user's time** | Every word earns its place. If a sentence can be deleted, delete it. | "Scan. Extract. Export." over a three-paragraph explainer. |
| **Show the AI** | When AI is doing work, say so — but describe it in human terms. | "Reading amounts…" / "Analyzing vendor…" — not "Running inference." |

### Tone Spectrum
- Casual ←——●——→ Formal: **slightly formal** (we handle tax data, users expect competence)
- Playful ←—●———→ Serious: **mostly serious** (one dry joke is fine; no puns)
- Technical ←——●——→ Accessible: **accessible with precision** (say "IVA" not "value-added tax surcharge")
- Concise ←●———→ Detailed: **concise** (bullet points over paragraphs, every time)

### Voice Examples

| Situation | ✅ On-brand | ❌ Off-brand |
|-----------|-------------|--------------|
| Empty state | "No expenses in this quarter." | "Oops! Looks like you haven't scanned anything yet 😅" |
| Error | "Couldn't extract the total. Try retaking the photo in better light." | "Something went wrong! Please try again." |
| Paywall | "Unlimited scans. Gmail auto-sync. Quarterly exports." | "Unlock your full potential with Premium!" |
| Onboarding | "Point your camera at a receipt. We'll handle the rest." | "Welcome aboard! Let's get started on your invoice journey 🚀" |
| Success | "Export ready — 47 invoices for Q1." | "Woohoo! Your export is all set 🎉" |

### Voice Don'ts
- Never use emojis in product copy. (Marketing gets *one* per screen, max, and only when it carries meaning — ✓ ✅ ⚡.)
- Never use "just", "simply", "easily" — they minimize the user's problem.
- Never use "leverage", "unlock", "empower", "revolutionize", "seamless", "robust."
- Never use exclamation marks except in genuine success confirmations.
- Never ask rhetorical questions in headlines ("Tired of invoice chaos?"). State the outcome instead.

---

## 7. Iconography & Imagery

### Icon Style
- **Source**: SF Symbols (system). On web, use [Lucide](https://lucide.dev) — it matches the SF aesthetic closely.
- **Weight**: `.regular` for body/list icons, `.semibold` for emphasized, `.fill` variant for circle-backed hero icons.
- **Treatment**: Hero icons live inside a `Circle().fill(primary.opacity(0.12))` at 80–120pt. This is the signature move.
- **Size**: 16pt inline, 20pt list rows, 24pt tab bar, 36–56pt hero.

### Canonical Icon Mappings
Every core domain object has a fixed SF Symbol. Keep these consistent:
- Scan / Camera: `camera.fill` / `doc.viewfinder.fill`
- AI / Extraction: `sparkles` / `cpu` / `sparkles.rectangle.stack.fill`
- Export / Share: `paperplane.fill` / `square.and.arrow.up`
- Company / Vendor: `building.2.fill`
- Gmail / Inbox: `envelope.fill` (always with `.red` or red accent)
- Accountant / Client: `person.text.rectangle.fill` (teal)
- Pro / Premium: `crown.fill` (yellow)
- Income: `arrow.down.circle.fill` (green)
- Expense: `arrow.up.circle.fill` (orange/red)

### Photography / Illustration Direction
- **App Store screenshots**: Real product UI on brand gradient background (`#312E81 → #8B5CF6`) with white, bold, rounded headline above. No mockup frames from stock libraries.
- **Marketing illustration**: None. We show the product, not metaphors.
- **Stock photography**: Forbidden. If humans appear, they're founders/customers in a real context — never hands-on-laptop compositions.

### Imagery Don'ts
- No 3D isometric illustrations of "data flowing."
- No generic fintech photography (calculators, ledgers, handshakes).
- No AI-generated hero images that look like AI-generated hero images.

---

## 8. Motion & Interaction

### Animation Principles
- **Fast** — 150–300ms for most transitions. If a user notices the animation, it's too slow.
- **Ease-in-out for state changes** (step transitions, sheet presentations).
- **Asymmetric slides for step flows**: `.move(edge: .trailing).combined(with: .opacity)` on insert, `.leading + .opacity` on remove. This is how onboarding flows feel in the app today.
- **Symbol effects** — use `.contentTransition(.symbolEffect(.replace))` when swapping SF Symbols during loading states (see `ExtractionOverlay`).
- **Pulse + bounce for AI work** — indigo ring pulsing at 1.2s, three bouncing dots, rotating status text. Reserved for genuinely-async AI work.

### Easing

```css
:root {
  --ease-default:  cubic-bezier(0.4, 0, 0.2, 1);      /* ease-in-out, the workhorse */
  --ease-out:      cubic-bezier(0.16, 1, 0.3, 1);     /* entrance */
  --ease-in:       cubic-bezier(0.7, 0, 0.84, 0);     /* exit */
  --ease-spring:   cubic-bezier(0.5, 1.25, 0.75, 1.25); /* playful confirmation */

  --duration-fast:    150ms;  /* micro (hover, tap) */
  --duration-base:    300ms;  /* transitions (tab switch, step) */
  --duration-slow:    500ms;  /* page-level, modal */
  --duration-pulse:   1200ms; /* ambient loading ring */
}
```

---

## 9. Component Patterns

### Buttons

| Type | Style |
|------|-------|
| **Primary CTA** | `background: var(--color-primary)`, white text `700`, padding `16px vertical / full width`, `radius-lg` (14px). The one big indigo button per screen. |
| **Secondary** | `background: var(--color-surface)`, primary text, same dimensions. |
| **Ghost / link** | Transparent, `color: var(--color-primary)`, subheadline size, no border. Used for "Sign in instead", "Restore purchases." |
| **Destructive** | `color: var(--color-error)`, transparent background. Confirmation required. |
| **Disabled** | `background: gray` (iOS `.gray`), no opacity change — state should be obvious. |

### Cards
- Background: `secondarySystemGroupedBackground` (iOS) / `--color-surface-2` (web)
- Radius: `radius-xl` (16px) for content panels; `radius-lg` (14px) for action cards
- Padding: `space-xl` (20px) for content, `space-lg` (14–16px) for action cards
- Border: optional 1px `role-colored.opacity(0.3)` for selection states
- Shadow: none by default. If elevation needed: `0 8px 20px rgba(0,0,0,0.1)`.

### Inputs
- Background: `secondarySystemGroupedBackground`
- Padding: 14px all sides
- Radius: `radius-md` (12px)
- Label above: caption, medium weight, secondary text color, 4px left padding
- No visible border by default — the fill provides separation

### Badges / Pills
- Background: `role-color.opacity(0.1)`
- Foreground: same role color, semibold
- Radius: `radius-full`
- Padding: `6px × 12px`
- Font: caption / subheadline

### Alert Banners
- Background: `role-color.opacity(0.1)` (orange for warning, red for error)
- Icon: `role-color` filled SF Symbol on the left
- Radius: `radius-md`
- Dismiss: trailing `xmark.circle.fill` in secondary text color

---

## 10. Application Notes

### Key Surfaces
- **iOS app (SwiftUI)** — canonical source; everything else matches this.
- **App Store screenshots** (`/marketing/screenshots/framed/`) — brand gradient frame + rounded display headline.
- **App previews / videos** (`/marketing/previews/`) — same gradient as screenshot frames.
- **Marketing landing page** (invoscan.ai) — SF Pro Rounded via Nunito fallback, indigo primary, Spanish/English parity.
- **App Store Connect metadata** — in `/marketing/metadata.json`, localized EN + ES.
- **Accountant-facing exports (CSV/XLSX)** — neutral styling; brand only in PDF cover page if we add one.

### Localization Rules
- Every user-facing string ships in both `en-US` and `es-ES`. Spanish is the primary market — write Spanish copy first when possible.
- Tax terms stay in Spanish even in English copy: IVA, IRPF, NIF, autónomo, Modelo 303, gestor.

### Co-Branding
- **"Sign in with Apple"** and **"Sign in with Google"** buttons follow each vendor's guidelines — never restyle them.
- **RevenueCat paywall** — use their `PaywallView` with our indigo tint; never fight the SDK styling.
- **Kung Fu Software SL** — the parent company appears only in App Store footer, settings app-version line, and legal pages. Never lead with it.

### File Formats
- Colors: CSS custom properties (this doc), SwiftUI `Color` literals, Tailwind config (see skill).
- Fonts: System fonts on iOS; Google Fonts (Nunito, Inter, JetBrains Mono) on web.
- Logo: `AppIcon.png` in `Assets.xcassets/AppIcon.appiconset/` — source of truth. Export SVG for web.
- Gradient: always use the exact four stops. Don't "adjust for taste."

---

*Generated with branding-kit skill — last updated 2026-04-12*
