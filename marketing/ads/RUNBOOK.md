# FacturaAI Ads — Runbook for Tomorrow

**Goal**: go from empty repo to 10 rendered Spanish ads uploaded to Meta by end of day.
**Time budget**: ~6 hours of focused work.
**Cost budget**: ~€30 in API credits + first day of ad spend (€50).

---

## Prerequisites (do tonight, not tomorrow)

Sign up and get API keys ready so you don't lose the morning on signup flows.

- [ ] **Anthropic** — API key with Sonnet 4.6 access → `ANTHROPIC_API_KEY`
- [ ] **ElevenLabs** — paid plan (Creator €22/mo or higher for voice cloning) → `ELEVENLABS_API_KEY`
- [ ] **Hedra** — paid plan with Character-3 access → `HEDRA_API_KEY`
- [ ] **AssemblyAI** — free tier is fine to start → `ASSEMBLYAI_API_KEY`
- [ ] **Cloudflare R2** — bucket `facturaai-ads` created, access key + secret → `R2_*`
- [ ] **Meta Business** — Ad Account ready, payment method on file, FacturaAI Page created
- [ ] **Google Veo 3** (optional) — Vertex AI project enabled, billing on

Also: **charge your laptop and eat breakfast**. Rendering will burn the battery and your patience.

---

## Morning block (9:00–12:30) — Setup

### 9:00 — Repo + dependencies (15 min)

```bash
cd ~/projects/kfs/mobile-apps/facturaai/marketing/ads
cp .env.example .env
# Paste all API keys into .env
bun install
```

**Expected**: all TypeScript diagnostics disappear. If any remain, run `bun run typecheck` and fix before moving on.

### 9:15 — Voice cloning (45 min)

Goal: 3 Spanish voices in ElevenLabs that will carry every ad.

**Source audio options (pick one)**:
- **Fastest**: find 3 Spanish YouTubers/podcasters whose voice you like, record 2 min of clean audio each via yt-dlp. *Only for testing — do not publish ads with uncleared voices.*
- **Right way**: hire 3 Spaniards on Malt or Fiverr (search "locutor español") to record 2 min each. Brief: *"Lee este texto en tono natural, conversacional, como si le contaras algo a un amigo."* Budget: ~€20 each. Turnaround: same day.
- **Shortcut**: record your own voice + ask 2 friends. Free and legal.

Steps:
1. Open ElevenLabs → Voices → Add Voice → Instant Voice Clone (for test) or Professional Voice Clone (for production, needs 30 min of audio)
2. Upload samples, name them: `carlos-autonomo`, `maria-disenadora`, `lucia-gestora`
3. Copy each `voice_id` from the URL or voice detail page
4. Paste into `countries/es-ES/country.json` under `voices.carlos.voiceId`, etc.
5. Test each voice in ElevenLabs playground with a sample sentence from `brief.md`

**Checkpoint**: 3 voice IDs in `country.json`, all 3 playback tested with natural Spanish.

### 10:00 — Hedra avatars (45 min)

Goal: 3 AI characters matching the 3 voice personas.

**Source reference photos**:
- **Option A — AI-generated**: Flux.1 Pro or Midjourney v7 prompts:
  - *"Photo of a 40-year-old Spanish plumber in work clothes, friendly face, soft lighting, casual selfie style, shot on iPhone"* → Carlos
  - *"Photo of a 32-year-old Spanish female graphic designer at her home office, warm smile, natural light, iPhone selfie"* → María
  - *"Professional photo of a 45-year-old Spanish accountant woman in an office, confident, warm expression"* → Lucía
- **Option B — Stock with usage rights**: Adobe Stock, Unsplash+ (paid), Pexels Pro. Faster but higher risk of someone recognizing the face.

Steps:
1. Generate/source 3 portrait photos (shoulders up, neutral background preferred, 1024×1024+)
2. Save to `countries/es-ES/avatars/{carlos,maria,lucia}.jpg`
3. Hedra → Create Character → upload photo → wait for processing (~2 min each)
4. Copy each `character_id`
5. Paste into `countries/es-ES/country.json` under `avatars.carlos.characterId`, etc.
6. Test each character with a 3-second sample audio in Hedra UI — confirm lip sync + identity look good

**Checkpoint**: 3 character IDs in `country.json`, all 3 preview clips look natural (not uncanny valley).

**Red flag**: if any avatar looks weird on fast consonants (P, B, F), regenerate the source photo with a more neutral mouth position.

### 10:45 — Coffee + B-roll generation (45 min)

Goal: 3–5 B-roll clips for the scenes referenced in the specs.

Clips needed (from `country.json`):
- `messy-desk.mp4` — 6 sec — papers scattered on a desk, maybe hands rifling through
- `hacienda-letter.mp4` — 5 sec — Spanish tax letter arriving or being opened
- `gmail-search-chaos.mp4` — 5 sec — laptop screen showing Gmail search with many results

**Fastest path: Veo 3 Fast ($0.15/sec)**
```
Prompt examples (use via Vertex AI / Gemini API):

1. "Close-up shot of a messy Spanish autónomo's desk, invoices and
    receipts scattered everywhere, hands frantically searching, natural
    window light, shot on handheld camera, documentary style, 6 seconds"

2. "A Spanish tax authority letter (Hacienda) being pulled from a
    mailbox, close-up, slight shake, realistic, 5 seconds"

3. "Laptop screen showing Gmail with hundreds of search results,
    cursor scrolling frantically, over-the-shoulder view, 5 seconds"
```

Cost: ~3 × 6s × $0.15 = **~$2.70 total**.

**Free fallback**: Pexels API — search "messy desk papers", "tax letter", "gmail inbox". Download MP4s, trim with `ffmpeg -ss 0 -t 6 -i in.mp4 -c copy out.mp4`.

Drop final files into `countries/es-ES/broll/`.

**Checkpoint**: 3 MP4s in `broll/`, each matches the `brollId` referenced in specs.

### 11:30 — iOS app demo recording (45 min)

**This is the single most important asset.** It's the hero shot in 8 of the 10 ads.

Steps:
1. Open Xcode → iOS Simulator → iPhone 15 Pro, iOS 17+
2. Set simulator language: Settings → General → Language → Español (España)
3. Run `bun run seed:demo --locale=es-ES` (or manually load demo data from `brief.md`: Carlos Martínez, 23 facturas, €1.847,30, maria@gestoriagarcia.es)
4. Start screen recording: `xcrun simctl io booted recordVideo --codec h264 app-demo-export-es.mov`
5. In the simulator, perform this exact flow (practice 2–3 times first):
   - Home screen → tap "Exportar para gestor" card
   - Period picker defaulted to "T1 2026" → tap confirm
   - Preview shows: *23 facturas · €1.847,30 · sin advertencias*
   - Tap "Generar export" → progress bar → success screen
   - Tap "Enviar por email" → mail composer pre-filled with `maria@gestoriagarcia.es`
   - Hold final success screen for 2 seconds
6. Stop recording: `Ctrl+C`
7. Convert to MP4: `ffmpeg -i app-demo-export-es.mov -c:v libx264 -crf 18 app-demo-export-es.mp4`
8. Move to `countries/es-ES/broll/app-demo-export-es.mp4`

**Red flag**: if the flow takes more than 12 seconds on screen, it's too slow for a 30s ad. Speed it up with `ffmpeg -i in.mp4 -filter:v "setpts=0.7*PTS" out.mp4`.

**Checkpoint**: One 10–15 second MP4 showing the full export flow, in Spanish, with correct demo data. Watch it. Would you tap it on Instagram Reels?

### 12:15 — Sanity check before lunch (15 min)

Run a quick validation:

```bash
# 1. Validate country config loads
bun run -e 'import("./src/schema/country").then(m => m.loadCountry("es-ES")).then(c => console.log("OK", Object.keys(c.voices), Object.keys(c.avatars)))'

# 2. Validate all 10 specs parse
for f in specs/es-ES/*.json; do
  bun run -e "import('./src/schema/ad').then(m => m.loadSpec('$f')).then(s => console.log('OK', s.id))"
done

# 3. Confirm broll files exist
ls -la countries/es-ES/broll/
```

**Checkpoint**: 3 voices + 3 avatars logged, 10 specs parsed, 4 MP4 files present.

### 12:30 — Lunch. Do not skip. Do not code while eating.

---

## Afternoon block (13:30–17:00) — Generation

### 13:30 — First render, one ad, end-to-end (60 min)

Start with **one** ad. Don't batch until it works.

```bash
bun run ads generate specs/es-ES/es-ES__trimestre-panic__2026-04-08__v01.json
```

**Expected sequence in logs**:
```
[es-ES__trimestre-panic__2026-04-08__v01] synthesizing voice...
[es-ES__trimestre-panic__2026-04-08__v01] generating avatar...
[es-ES__trimestre-panic__2026-04-08__v01] transcribing captions...
[es-ES__trimestre-panic__2026-04-08__v01] assets ready at renders/es-ES/...
```

**Files that should now exist**:
```
renders/es-ES/es-ES__trimestre-panic__2026-04-08__v01/
├── voice.mp3      (~200KB, ~18 sec of audio)
├── avatar.mp4     (~3MB, ~18 sec, 9:16)
├── captions.srt   (~1KB)
└── final.mp4      ← only if Remotion render is wired
```

**If `final.mp4` isn't produced yet** (the `renderMedia()` call is stubbed): open Remotion preview and manually confirm the composition looks right:

```bash
bun run render:preview
# Opens http://localhost:3000
# Click AdComposition → scrub through the timeline
# Verify: audio plays, captions appear, scenes transition, CTA card at the end
```

Then render manually once:
```bash
bunx remotion render src/remotion/Root.tsx AdComposition \
  renders/es-ES/es-ES__trimestre-panic__2026-04-08__v01/final.mp4 \
  --props="$(cat <<'EOF'
{
  "spec": ... (paste spec JSON here),
  "country": ... (paste country JSON here),
  "assetUrls": {
    "voice": "renders/es-ES/.../voice.mp3",
    "avatar": "renders/es-ES/.../avatar.mp4",
    ...
  }
}
EOF
)"
```

**Troubleshooting**:
| Symptom | Likely cause | Fix |
|---|---|---|
| ElevenLabs 401 | Wrong API key | Check `.env` |
| ElevenLabs 422 | Voice ID doesn't exist | Re-copy from ElevenLabs UI |
| Hedra timeout | Character still processing | Wait 5 min, retry |
| Hedra 400 | Audio file not uploaded correctly | Check `voice.mp3` exists and is valid MP3 |
| AssemblyAI hangs | Language code wrong | Ensure `language: 'es'` not `'es-ES'` |
| Remotion crash | Missing asset URL | Check all paths in `assetUrls` resolve |
| Video has no audio | Audio src not loaded | Confirm absolute path in `<Audio src>` |

### 14:30 — Review the first ad with human eyes (30 min)

Play `final.mp4` on your phone (not desktop). Check:
- [ ] **Hook lands in first 2 seconds** — if you're bored, kill it
- [ ] **Voice sounds Spanish-Spanish** (not LatAm, not robotic)
- [ ] **Avatar lip sync** is reasonable (not perfect — "good enough" is fine)
- [ ] **Captions** appear, spelled correctly, in sync
- [ ] **App demo** is readable at phone size
- [ ] **CTA card** shows FacturaAI + €7/mes clearly
- [ ] **No weird silences or cuts**

**If it passes**: batch the rest.
**If it fails**: fix the one thing that broke, regenerate (cached assets will skip), retry.

### 15:00 — Batch the remaining 9 (90 min)

```bash
bun run ads build --country es-ES
```

Go have coffee. This will run for ~30–60 min depending on Hedra queue times.

**Monitor**: tail the log. If any single ad fails, the loop should continue to the next. Re-run with `--force` only on failed specs after.

### 16:30 — Quality gate (30 min)

Watch all 10 MP4s. Sort into:
- **Ship**: obviously good — upload to Meta today
- **Fix**: small issue, regenerate one asset (usually avatar or voice take) and retry
- **Kill**: fundamentally broken hook or bad avatar, don't ship

**Target**: ≥ 6 ads ship. If < 6, the issue is upstream (bad scripts, bad avatars, wrong voice tone). Debug before scaling.

---

## Evening block (17:00–19:00) — Launch

### 17:00 — Upload to Meta (45 min)

**Manual upload** (automation comes later):
1. Meta Ads Manager → Create Campaign
2. Objective: **App Promotion** (iOS)
3. Budget: **€5/day per ad set** (expect 10 ad sets = €50/day)
4. Audience: **Spain**, ages 25–55, interests: `autónomo`, `freelance`, `small business`, `Hacienda`, `contabilidad`
5. Placements: **Reels + Stories + Feed** (Instagram + Facebook). Turn OFF audience network.
6. Creative: one MP4 per ad set
7. Primary text: use the `hook` from the spec
8. Headline: `FacturaAI – €7/mes`
9. CTA button: `Descargar`
10. Link: App Store URL (iOS only; Android N/A right now)

**Pause all ad sets** until all 10 are created. Then activate simultaneously at 18:00 — this makes the performance comparison fair.

### 17:45 — Naming convention (10 min)

Name each ad set in Meta exactly: `{spec.id}` (e.g., `es-ES__trimestre-panic__2026-04-08__v01`). This lets you join Meta metrics back to your local specs tomorrow.

### 18:00 — Activate all, set a 72h reminder (10 min)

- Activate all 10 ad sets at once
- Set a calendar reminder for **2026-04-11 18:00** to pull metrics and update `data/performance.jsonl`
- Do **not** touch the campaigns until then. Let data come in.

### 18:15 — Post-launch notes (15 min)

Append to `data/winners.md`:

```md
## Launch 2026-04-08

Ads shipped: 10
Cost per ad: ~€X (track actual Hedra + ElevenLabs bill)
Budget: €50/day
Angles tested: trimestre-panic, gestora-pov, gmail-surprise, export-hero,
               pareja-relief, modelo-303, whatsapp-gestora, cajon-recibos,
               domingo-noche
Avatars: carlos (4), maria (4), lucia (1)
Hypothesis: gestora-pov and export-hero have highest ceiling. Hypothesis
            trimestre-panic is the volume baseline.

Review on 2026-04-11.
```

### 18:30 — Stop. Do not iterate tonight. (0 min)

**Hard rule**: no post-launch tweaking for 72 hours. You cannot learn from data you collected over 4 hours on a Tuesday. Let the algorithm breathe.

Close the laptop. Go outside.

---

## Day-3 follow-up (2026-04-11)

Brief script for when the reminder fires:

1. Export Meta metrics by ad set → CSV
2. Convert to `data/performance.jsonl`:
   ```
   bun run ads perf-import meta-export.csv
   ```
   *(this tool doesn't exist yet — build it if needed, or update the JSONL manually for the first cycle)*
3. Compute for each ad: CPI, install rate, hook-CTR
4. Rank, update `data/winners.md` with the top 3 and bottom 3
5. Feed winners into Claude to generate 10 new variants of top angles:
   ```
   bun run ads scripts --country es-ES --angle gestora-pov --count 10
   ```
6. Re-run morning/afternoon block from this runbook, but faster (~2 hours total because voices, avatars, B-roll are cached).

---

## Things that will probably go wrong

- **Hedra queue is slow**: avatars take 3–5 min each, sometimes 10. Plan for it.
- **Voice sounds like LatAm Spanish**: re-record source, use a different ElevenLabs model, or pick a voice clone from a clearly Castilian source.
- **App demo is jittery**: re-record at 60fps in Simulator, convert to 30fps in ffmpeg for smoothness.
- **Meta rejects ad**: usually for "unrealistic claims." Soften CTA (`"Prueba gratis"` not `"Garantizado"`). Never imply AI avatars are real people.
- **Captions are in wrong language**: AssemblyAI language code must be `es` exactly.
- **Remotion out-of-memory on long renders**: close other apps, use `--concurrency=1`.
- **R2 upload fails**: check bucket region, access key permissions, bucket CORS.

---

## Success criteria for end of day

- [x] All 10 specs exist (done already — in repo)
- [ ] 3 voices cloned and IDs in `country.json`
- [ ] 3 avatars created and IDs in `country.json`
- [ ] 4 B-roll files in `countries/es-ES/broll/` (3 clips + 1 app demo)
- [ ] `.env` fully populated
- [ ] `bun install` clean, zero diagnostics
- [ ] ≥ 6 `final.mp4` files rendered
- [ ] ≥ 6 ads uploaded to Meta as separate ad sets
- [ ] All ad sets named with their `spec.id`
- [ ] Campaign live at €50/day total
- [ ] Reminder set for 2026-04-11 review

If you hit all of these: you shipped a full ad pipeline in one day. If not: ship what you have, debug the rest tomorrow, the world is fine.

---

## One rule for tomorrow

**Don't rewrite the pipeline.** If something breaks, fix it in place. The goal is 10 ads in Meta by 18:00, not a perfect architecture. Architecture improvements go into a backlog file to revisit after the first week of data.
