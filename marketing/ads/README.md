# @facturaai/ads

Country-first, spec-driven ad generation pipeline for FacturaAI.

## Principles

1. **Country is the unit of campaign**, not language. UK and US are different campaigns.
2. **Scripts are written natively, never translated.** Claude reads each country's brief.
3. **Assets are country-scoped.** Voices, avatars, B-roll, app demos all live under `countries/{id}/`.
4. **One Remotion template, many specs.** All variation lives in JSON specs.
5. **Reproducible from JSON.** Every ad has a spec; rebuilds are idempotent.
6. **Cache everything.** Voice/avatar/captions are reused across renders.

## Layout

```
marketing/ads/
├── src/                  pipeline code
│   ├── cli.ts            entry: bun run ads <command>
│   ├── providers/        ElevenLabs, Hedra, Veo, AssemblyAI, R2, Claude
│   ├── pipelines/        script → voice → avatar → captions → render
│   ├── remotion/         single AdComposition template
│   ├── schema/           zod: AdSpec, CountryConfig
│   └── publishers/       Meta, TikTok (later)
├── countries/
│   └── es-ES/
│       ├── country.json  CountryConfig
│       ├── brief.md      audience, vocabulary, pain points (the moat)
│       ├── voices/       ElevenLabs voice metadata
│       ├── avatars/      Hedra character metadata
│       ├── broll/        country-specific B-roll
│       └── music/
├── specs/                every ad ever generated, as JSON (committed)
├── renders/              local cache (gitignored)
└── data/                 performance.jsonl, manifest, winners.md
```

## Commands

```bash
# Generate scripts for a country/angle
bun run ads scripts --country es-ES --angle trimestre-panic --count 10

# Build a single ad from spec → MP4
bun run ads generate specs/es-ES/2026-04-08_hook-trimestre-01.json

# Build all approved specs for a country
bun run ads build --country es-ES --since 2026-04-08

# Preview Remotion composition locally
bun run render:preview
```

## Pipeline

```
AdSpec.json + CountryConfig.json
   │
   ├─► ElevenLabs ──► voice.mp3
   ├─► Hedra      ──► avatar.mp4
   ├─► AssemblyAI ──► captions.srt
   ├─► Remotion   ──► final.mp4
   └─► R2         ──► signed URL + manifest entry
```

Each step is cached. Re-running with the same spec reuses prior outputs unless `--force`.

## Adding a new country

1. `mkdir countries/xx-XX`
2. Copy `countries/es-ES/country.json` and translate
3. Write `countries/xx-XX/brief.md` natively (do not translate)
4. Clone voices in ElevenLabs, register in `voices/`
5. Create avatars in Hedra, register in `avatars/`
6. Record `app-demo-export-xx.mp4` from iOS Simulator with `bun run seed:demo --locale=xx-XX`
7. Generate first scripts: `bun run ads scripts --country xx-XX --count 10`

The pipeline code is country-agnostic. New countries are folder additions, not code changes.

## Setup

```bash
cd marketing/ads
cp .env.example .env
# Fill in API keys
bun install
```
