import { z } from 'zod';

export const AdScript = z.object({
  hook: z.string(),
  problem: z.string(),
  solution: z.string(),
  proof: z.string(),
  cta: z.string(),
});
export type AdScript = z.infer<typeof AdScript>;

export const AdScene = z.object({
  type: z.enum(['avatar', 'broll', 'app-demo', 'text-card']),
  startSec: z.number().nonnegative(),
  endSec: z.number().positive(),
  brollId: z.string().optional(),
  textOverlay: z.string().optional(),
});
export type AdScene = z.infer<typeof AdScene>;

export const AdSpec = z.object({
  id: z.string(),
  countryId: z.string(),
  createdAt: z.string(),
  angle: z.string(),
  platform: z.array(z.enum(['meta', 'tiktok', 'youtube-shorts'])),
  durationSec: z.number().positive(),
  aspectRatio: z.enum(['9:16', '1:1', '4:5', '16:9']),
  avatarId: z.string(),
  voiceId: z.string(),
  script: AdScript,
  scenes: z.array(AdScene),
  music: z
    .object({
      track: z.string(),
      volumeDb: z.number().default(-18),
    })
    .optional(),
  captions: z.object({
    enabled: z.boolean().default(true),
    style: z.string().optional(),
  }),
  cta: z.object({
    text: z.string(),
    urlKey: z.enum(['appStore', 'landing']),
  }),
  tags: z.array(z.string()),
});
export type AdSpec = z.infer<typeof AdSpec>;

export function scriptToText(script: AdScript): string {
  return [script.hook, script.problem, script.solution, script.proof, script.cta]
    .filter(Boolean)
    .join(' ');
}

export async function loadSpec(path: string): Promise<AdSpec> {
  const file = Bun.file(path);
  if (!(await file.exists())) {
    throw new Error(`Spec not found: ${path}`);
  }
  return AdSpec.parse(await file.json());
}

export async function saveSpec(dir: string, spec: AdSpec): Promise<string> {
  const path = `${dir}/${spec.id}.json`;
  await Bun.write(path, JSON.stringify(spec, null, 2));
  return path;
}
