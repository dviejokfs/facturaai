// Script generation pipeline: Country brief + angle → N AdSpecs (saved as JSON)
import { generate } from '@/providers/claude';
import { type CountryConfig, loadCountry } from '@/schema/country';
import { type AdSpec, AdScript, saveSpec } from '@/schema/ad';

const SYSTEM = `You are a senior performance creative writing short-form video ad scripts.

Hard rules:
- Write natively in the country's language. NEVER translate from English.
- Use the vocabulary and pain points from the brief verbatim where possible.
- Respect forbidden angles. Do not break positioning.
- Each ad: 25-30 seconds total. Hook 2s, problem 6s, solution 10s, proof 7s, CTA 5s.
- Hooks must stop the scroll in 2 seconds. No throat-clearing.
- Output strict JSON. No prose, no markdown, no backticks.`;

interface GenerateScriptsOpts {
  countryId: string;
  angle: string;
  count: number;
  avatarId: string;
  voiceId: string;
}

export async function generateScripts(opts: GenerateScriptsOpts): Promise<string[]> {
  const country = await loadCountry(opts.countryId);
  const briefPath = `${import.meta.dir}/../../countries/${opts.countryId}/brief.md`;
  const brief = await Bun.file(briefPath).text();

  const user = `# Country brief
${brief}

# Task
Write ${opts.count} short-form video ad scripts for FacturaAI in ${country.language} (${country.country}).
Angle: "${opts.angle}"

Each script must be a JSON object with this exact shape:
{
  "hook": "...",
  "problem": "...",
  "solution": "...",
  "proof": "...",
  "cta": "..."
}

Return a JSON array of ${opts.count} such objects. No other text.`;

  const raw = await generate({ system: SYSTEM, user, maxTokens: 6000 });
  const cleaned = raw.trim().replace(/^```(?:json)?/, '').replace(/```$/, '').trim();
  const parsed = JSON.parse(cleaned) as unknown[];
  if (!Array.isArray(parsed)) throw new Error('Claude did not return an array');

  const specs: AdSpec[] = parsed.map((scriptRaw, i) => {
    const script = AdScript.parse(scriptRaw);
    const date = new Date().toISOString().slice(0, 10);
    const id = `${opts.countryId}__${opts.angle}__${date}__v${String(i + 1).padStart(2, '0')}`;
    return buildSpec({ id, country, angle: opts.angle, script, avatarId: opts.avatarId, voiceId: opts.voiceId });
  });

  const dir = `${import.meta.dir}/../../specs/${opts.countryId}`;
  const paths: string[] = [];
  for (const spec of specs) {
    paths.push(await saveSpec(dir, spec));
  }
  return paths;
}

function buildSpec(args: {
  id: string;
  country: CountryConfig;
  angle: string;
  script: AdScript;
  avatarId: string;
  voiceId: string;
}): AdSpec {
  return {
    id: args.id,
    countryId: args.country.id,
    createdAt: new Date().toISOString(),
    angle: args.angle,
    platform: ['meta', 'tiktok'],
    durationSec: 30,
    aspectRatio: '9:16',
    avatarId: args.avatarId,
    voiceId: args.voiceId,
    script: args.script,
    scenes: [
      { type: 'avatar', startSec: 0, endSec: 2 },
      { type: 'broll', startSec: 2, endSec: 8, brollId: 'messy-desk' },
      { type: 'app-demo', startSec: 8, endSec: 18 },
      { type: 'avatar', startSec: 18, endSec: 25 },
      { type: 'text-card', startSec: 25, endSec: 30, textOverlay: args.country.pricingDisplay },
    ],
    captions: { enabled: true },
    cta: {
      text: 'CTA',
      urlKey: 'appStore',
    },
    tags: [args.angle, args.country.country],
  };
}
