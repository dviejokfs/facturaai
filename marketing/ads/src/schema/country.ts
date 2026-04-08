import { z } from 'zod';

export const VoiceConfig = z.object({
  provider: z.literal('elevenlabs'),
  voiceId: z.string(),
  name: z.string(),
  gender: z.enum(['male', 'female']),
  age: z.enum(['young', 'middle', 'senior']),
  persona: z.string(),
  modelId: z.string().default('eleven_multilingual_v2'),
});
export type VoiceConfig = z.infer<typeof VoiceConfig>;

export const AvatarConfig = z.object({
  provider: z.enum(['hedra', 'heygen']),
  characterId: z.string(),
  name: z.string(),
  persona: z.string(),
  referenceImage: z.string(),
  notes: z.string().optional(),
});
export type AvatarConfig = z.infer<typeof AvatarConfig>;

export const BrollClip = z.object({
  id: z.string(),
  path: z.string(),
  tags: z.array(z.string()),
  durationSec: z.number(),
  source: z.enum(['veo', 'pexels', 'pixabay', 'original', 'screen-recording']),
});
export type BrollClip = z.infer<typeof BrollClip>;

export const CountryConfig = z.object({
  id: z.string(),
  country: z.string(),
  language: z.string(),
  currency: z.string(),
  currencySymbol: z.string(),
  pricingDisplay: z.string(),
  taxAuthority: z.string(),
  accountantTerm: z.string(),
  selfEmployedTerm: z.string(),
  taxPeriodTerm: z.string(),
  appLocale: z.string(),
  appStoreUrl: z.string().url(),
  landingUrl: z.string().url(),
  metaPixelId: z.string().optional(),
  tiktokPixelId: z.string().optional(),
  voices: z.record(VoiceConfig),
  avatars: z.record(AvatarConfig),
  brollLibrary: z.array(BrollClip),
  appDemoClip: z.string(),
  fonts: z.object({
    captions: z.string(),
    captionSize: z.number(),
  }),
  captionStyle: z.enum(['tiktok-yellow', 'instagram-white', 'subtle']),
});
export type CountryConfig = z.infer<typeof CountryConfig>;

export async function loadCountry(id: string): Promise<CountryConfig> {
  const path = `${import.meta.dir}/../../countries/${id}/country.json`;
  const file = Bun.file(path);
  if (!(await file.exists())) {
    throw new Error(`Country config not found: ${path}`);
  }
  const data = await file.json();
  return CountryConfig.parse(data);
}
