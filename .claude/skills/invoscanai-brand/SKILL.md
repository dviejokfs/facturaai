---
name: invoscanai-brand
description: Enforce the InvoScanAI brand system — indigo/violet palette, SF Pro Rounded typography, calm-confident voice, and signature component patterns. TRIGGER when writing user-facing copy, designing new screens, creating marketing pages, generating OG/App Store images, styling emails, or choosing colors/fonts/icons for anything InvoScanAI-branded. Load this before any visual or copy work.
---

# InvoScanAI Brand Skill

This skill is the working reference for everything visible in the InvoScanAI product and marketing. The single source of truth is `BRANDING.md` at the repo root — always read it when the task involves visual design, copy, color, typography, iconography, or motion.

## When to invoke

**Always load** when the user asks you to:
- Write or rewrite product copy (labels, buttons, error messages, onboarding)
- Write marketing copy (landing page, emails, App Store description, social)
- Pick colors, fonts, spacing, or icons
- Design a new SwiftUI view or web component
- Generate App Store screenshots, OG images, social cards, or app previews
- Review an existing UI for on-brand-ness

**Skip** when the task is purely backend, data modeling, infra, or internal tooling that never surfaces to users.

## Workflow

### 1. Load the brand kit
Start every branded task by reading the full kit:
```
Read /Users/davidviejo/projects/kfs/mobile-apps/facturaai/BRANDING.md
```

Then skim the topic-specific references below if the task is narrow.

### 2. Apply the 7 invariants

These override personal taste. If you're about to break one, stop and ask.

1. **One primary CTA per screen, filled with `#4B39C7`.** Every other button is ghost or surface-tinted.
2. **SF Pro Rounded for display, SF Pro Text for body.** On web: Nunito for display, Inter for body. Never mix weights within a single heading.
3. **Hero icons live in a 12%-opacity primary circle.** This is the signature visual — use it on every step header, empty state, and modal hero.
4. **The brand gradient (`#312E81 → #6D28D9 → #7C3AED → #8B5CF6`) is for decoration only.** Never behind readable content except on marketing screenshot frames.
5. **Spanish and English ship together.** Every new string gets both locales in the same PR. Write Spanish copy first when possible.
6. **Semantic colors are fixed**: green=success/income, orange=warning, red=error/Gmail, teal=client/accountant, yellow=Pro/premium. Don't repurpose them.
7. **No emojis, no exclamation marks, no "just/simply/easily", no rhetorical-question headlines.** See `references/voice.md`.

### 3. Verify before shipping

Run through the checklist in `references/checklist.md` for any visible surface before calling it done.

## Topic-specific references

Load these on demand:

| File | When to read |
|------|--------------|
| `references/colors.md` | Picking any color, building a new surface, adding a badge/pill |
| `references/typography.md` | Any heading, body copy, or font-size decision |
| `references/voice.md` | Writing any user-facing string or marketing copy |
| `references/components.md` | Building a button, card, input, banner, or list row |
| `references/icons.md` | Choosing an SF Symbol or Lucide icon |
| `references/checklist.md` | Final review of any visible change |

## Integration with other skills

When any of these skills run, they MUST read `BRANDING.md` first:
- `frontend-design` → pull `--color-*` tokens, spacing scale, radius scale
- `design-review` → use `references/checklist.md` as the rubric
- `copywriting`, `cold-email`, `copy-editing` → obey `references/voice.md` voice rules
- `blog-write`, `blog-outline`, `seo-page` → match tone + don't-list from `references/voice.md`
- `design-html`, `design-shotgun` → use the brand gradient + type scale verbatim
- `pptx`, `pdf`, `docx` (Office generators) → pull color palette and typography from the brand kit, not from generic Office templates

## Strong-opinion defaults

When the user hasn't specified something, default to these without asking:
- **Background**: `#F2F2F7` (iOS `systemGroupedBackground`), never pure white
- **Card radius**: `16px`
- **Button radius**: `14px`
- **Primary button height**: `52–56px` (16px vertical padding + line-height)
- **Hero icon**: 80pt circle, 12% primary opacity fill, SF Symbol at 36pt
- **Section spacing**: `32px` vertical between hero and content
- **Horizontal screen padding**: `20–24px`
- **Transition duration**: `300ms ease-in-out`

## Anti-patterns to reject

If a user asks for any of these, push back and propose the brand-aligned alternative:
- "Can we make the CTA green/blue/pink?" → No. Primary is always indigo `#4B39C7`.
- "Let's add a second accent color." → No. The palette is monochromatic indigo/violet; teal/green/orange/red/yellow are *semantic only*.
- "Can we use a gradient on the pricing table?" → No. Gradients are decoration, not information hierarchy.
- "Let's add some fun emojis to the onboarding." → No. Product copy is emoji-free.
- "Comic Sans / Papyrus / Playfair / Futura for headlines?" → No. SF Pro Rounded or Nunito, period.
- "Make the copy more exciting with exclamation marks!" → No. Calm confidence. One exclamation only in genuine success states.
