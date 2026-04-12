# Voice & Tone Reference

Full spec in `BRANDING.md` §6. This is the copy-writer's bible.

## One-line voice

**Calm, competent, concrete.** We handle tax data — write like you know it matters, and like you've done this before.

## The six principles

1. **Outcome first.** Lead with what the user gets.
   - ✅ "One ZIP your accountant loves."
   - ❌ "AI-powered export engine that generates."

2. **Concrete, not abstract.** Use numbers, verbs, objects.
   - ✅ "Scan up to 10 invoices free."
   - ❌ "Try our starter tier."

3. **Calm confidence.** State facts. No hype, no hedging.
   - ✅ "Your invoices are encrypted at rest."
   - ❌ "Your data is SUPER secure, don't worry!!"

4. **Spanish-first mindset.** Write copy that translates cleanly.
   - ✅ "Ready to send." (travels to "Listo para enviar.")
   - ❌ "Good to go!" (idiomatic, doesn't travel)

5. **Respect the user's time.** Cut every word that doesn't earn its place.
   - ✅ "Scan. Extract. Export."
   - ❌ "Our innovative platform allows you to scan, extract, and export your invoices in just a few simple steps."

6. **Show the AI in human terms.** When AI works, describe the work.
   - ✅ "Reading amounts…" / "Analyzing vendor…"
   - ❌ "Running inference on multimodal model…"

## Tone spectrum

- Casual ←——●——→ Formal: **slightly formal**
- Playful ←—●———→ Serious: **mostly serious**
- Technical ←——●——→ Accessible: **accessible with precision** (say "IVA" not "value-added tax surcharge")
- Concise ←●———→ Detailed: **concise**

## The forbidden words

Never ship these in product or marketing copy:

- **just, simply, easily** — minimize the user's effort and insult their struggle
- **leverage, unlock, empower, revolutionize** — consulting-speak
- **seamless, robust, intuitive, powerful** — meaningless filler
- **solutions, platform, ecosystem, framework** — when talking about InvoScanAI
- **journey** (as in "your invoice journey") — reserve for actual travel
- **game-changer, next-level, cutting-edge, best-in-class** — all meaningless
- **users** (when addressing them directly) — use "you"

## Punctuation rules

- **Exclamation marks**: Only in genuine success confirmations. Never in headlines, CTAs, errors.
  - ✅ "Export ready!"
  - ❌ "Scan your invoices now!"
- **Emojis**: Forbidden in product copy. In marketing, one per surface maximum, and only when it carries meaning (✓ ⚡ not 🚀 🎉).
- **Em dashes** (—): Encouraged for crisp structure. No spaces around them in running text.
- **Rhetorical questions in headlines**: Forbidden. State the outcome.
  - ✅ "Every invoice, organized."
  - ❌ "Tired of invoice chaos?"

## Concrete examples

### Empty states
- ✅ "No expenses in this quarter."
- ✅ "No invoices from this vendor yet."
- ❌ "Oops! Nothing here yet 😅"

### Error messages
- ✅ "Couldn't extract the total. Try retaking the photo in better light."
- ✅ "Gmail sync paused — please sign in again."
- ❌ "Something went wrong! Please try again."

### CTAs
- ✅ "Scan first invoice"
- ✅ "Export for accountant"
- ✅ "Connect Gmail"
- ❌ "Get started now!"
- ❌ "Let's go!"

### Paywall
- ✅ "Unlimited scans. Gmail auto-sync. Quarterly exports."
- ✅ "€6.99/month. Cancel anytime."
- ❌ "Unlock your full potential with Premium!"
- ❌ "Go Pro and supercharge your workflow!"

### Onboarding headers
- ✅ "Scan your first invoice."
- ✅ "Point your camera. We'll handle the rest."
- ❌ "Welcome aboard! 🚀"
- ❌ "Let's get you set up!"

### Success confirmations
- ✅ "Export ready — 47 invoices for Q1."
- ✅ "Imported 12 invoices from Gmail."
- ❌ "Woohoo! All done 🎉"

## Domain vocabulary (use exactly these terms)

| Concept | English | Spanish |
|---------|---------|---------|
| Value-added tax | VAT (or IVA) | IVA |
| Personal income tax withholding | IRPF | IRPF |
| Tax ID | Tax ID | NIF / CIF |
| Self-employed person | Freelancer / autónomo | autónomo |
| Accountant | Accountant | gestor |
| Quarterly | Quarterly | Trimestral |
| Invoice (received) | Invoice | Factura |
| Receipt | Receipt | Ticket |

Keep Spanish tax terms (IVA, IRPF, NIF, autónomo, gestor, Modelo 303) even in English copy. They're terms of art.

## Bilingual parity

Every new string lands in both `en-US` and `es-ES` `Localizable.strings` in the same PR. If you're writing copy for the Spanish audience first, do that and then translate — the English will read more naturally.

Structure in `.strings`:
```
/* Section */
"key.name" = "English value";
```
