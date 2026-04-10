#!/usr/bin/env bun
// CLI: bun run ads <command>
import { generateScripts } from '@/pipelines/script';
import { renderAd } from '@/pipelines/render';
import { loadCountry } from '@/schema/country';
import { loadSpec } from '@/schema/ad';
import { readdir } from 'node:fs/promises';

const [, , cmd, ...rest] = process.argv;
const args = parseArgs(rest);

try {
  switch (cmd) {
    case 'scripts':
      await cmdScripts();
      break;
    case 'generate':
      await cmdGenerate();
      break;
    case 'build':
      await cmdBuild();
      break;
    default:
      printHelp();
      process.exit(cmd ? 1 : 0);
  }
} catch (err) {
  console.error('Error:', err instanceof Error ? err.message : err);
  process.exit(1);
}

async function cmdScripts() {
  const countryId = required('country');
  const angle = required('angle');
  const count = Number(args.count ?? 10);
  const country = await loadCountry(countryId);
  const avatarId = args.avatar ?? Object.keys(country.avatars)[0];
  const voiceId = args.voice ?? Object.keys(country.voices)[0];
  if (!avatarId || !voiceId) {
    throw new Error(`Country ${countryId} has no avatars or voices configured`);
  }
  console.log(`Generating ${count} scripts for ${countryId} / angle=${angle}...`);
  const paths = await generateScripts({ countryId, angle, count, avatarId, voiceId });
  console.log(`Wrote ${paths.length} specs:`);
  paths.forEach((p) => console.log('  ' + p));
}

async function cmdGenerate() {
  const specPath = rest[0];
  if (!specPath) throw new Error('Usage: ads generate <spec-path>');
  const spec = await loadSpec(specPath);
  const country = await loadCountry(spec.countryId);
  const result = await renderAd({
    spec,
    country,
    force: !!args.force,
    upload: !!args.upload,
  });
  console.log('Done:', result);
}

async function cmdBuild() {
  const countryId = required('country');
  const dir = `${import.meta.dir}/../specs/${countryId}`;
  const files = (await readdir(dir)).filter((f) => f.endsWith('.json'));
  console.log(`Building ${files.length} specs for ${countryId}...`);
  const country = await loadCountry(countryId);
  for (const file of files) {
    const spec = await loadSpec(`${dir}/${file}`);
    await renderAd({ spec, country, force: !!args.force, upload: !!args.upload });
  }
}

function parseArgs(argv: string[]): Record<string, string> {
  const out: Record<string, string> = {};
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i]!;
    if (a.startsWith('--')) {
      const key = a.slice(2);
      const next = argv[i + 1];
      if (next && !next.startsWith('--')) {
        out[key] = next;
        i++;
      } else {
        out[key] = 'true';
      }
    }
  }
  return out;
}

function required(key: string): string {
  const v = args[key];
  if (!v) throw new Error(`Missing --${key}`);
  return v;
}

function printHelp() {
  console.log(`@invoscanai/ads CLI

Commands:
  scripts  --country <id> --angle <name> [--count 10] [--avatar id] [--voice id]
           Generate N ad scripts via Claude, save as specs/

  generate <spec-path> [--force] [--upload]
           Build a single spec → voice → avatar → captions → MP4

  build    --country <id> [--force] [--upload]
           Build all specs for a country

Examples:
  bun run ads scripts --country es-ES --angle trimestre-panic --count 10
  bun run ads generate specs/es-ES/es-ES__trimestre-panic__2026-04-08__v01.json
  bun run ads build --country es-ES --upload
`);
}
