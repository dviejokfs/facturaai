# Typography Reference

Full spec in `BRANDING.md` §3.

## The rule

**Display = SF Pro Rounded.** **Body = SF Pro Text / Inter.**

On iOS, always use `.system(..., design: .rounded)` for titles. The codebase already does this — grep for `design: .rounded` to see the pattern.

## iOS type scale (SwiftUI)

```swift
// Display XL — Onboarding welcome, paywall hero
.font(.system(size: 38, weight: .bold, design: .rounded))

// Display L — Step titles, sheet headers
.font(.system(size: 26, weight: .bold, design: .rounded))

// H1 — Screen titles
.font(.system(size: 24, weight: .bold, design: .rounded))

// H2
.font(.title3)  // 20pt, semibold

// Body
.font(.subheadline)  // 15pt
.font(.body)         // 17pt

// Caption
.font(.caption)      // 12pt
.font(.caption2)     // 11pt
```

**Always pair titles with `.foregroundStyle(.primary)` and body text with `.foregroundStyle(.secondary)` for supporting copy.**

## Web type scale

```css
--fs-display-xl: 2.75rem;  /* 44px */
--fs-display-l:  2rem;     /* 32px */
--fs-h1:         1.75rem;  /* 28px */
--fs-h2:         1.25rem;  /* 20px */
--fs-headline:   1.0625rem;/* 17px */
--fs-body:       1rem;     /* 16px */
--fs-caption:    0.75rem;  /* 12px */
--fs-caption-xs: 0.6875rem;/* 11px */
```

## Font stacks

```css
/* Display (headlines) */
font-family: 'SF Pro Rounded', 'Nunito', -apple-system, BlinkMacSystemFont, 'Segoe UI Rounded', sans-serif;

/* Body */
font-family: -apple-system, BlinkMacSystemFont, 'Inter', 'Segoe UI', Helvetica, Arial, sans-serif;

/* Money / numeric columns — always tabular */
font-family: 'SF Pro Text', 'Inter', system-ui;
font-variant-numeric: tabular-nums;
font-feature-settings: "tnum" 1;

/* Code, tax IDs */
font-family: 'SF Mono', 'JetBrains Mono', Menlo, Consolas, monospace;
```

## Google Fonts import (web only)

```html
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Nunito:wght@600;700;800&family=Inter:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">
```

## Weight rules

- **700 (bold)** — display + hero headlines
- **600 (semibold)** — H1/H2, list row titles, button labels
- **500 (medium)** — captions, labels
- **400 (regular)** — body copy

Skip 300 and 800. Never use italic. Never use uppercase for emphasis.

## Line height

- Headlines (18px+): `1.2`
- Body (14–17px): `1.5`
- Captions (11–13px): `1.4`

## Letter spacing

- Display XL: `-0.5px` / `-0.015em`
- H1/H2: `-0.2px` / `-0.01em`
- Body and below: default (0)

## Don'ts

- Don't use `.rounded` design for body text — it reads infantile at 14–15pt.
- Don't hardcode pixel sizes in list rows — let iOS Dynamic Type scale.
- Don't mix 2+ fonts in a single heading.
- Don't go below 12pt / 11px for any readable content.
- Don't italicize or capitalize for emphasis — use weight (600/700) only.
