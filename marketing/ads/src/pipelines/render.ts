// End-to-end render pipeline: spec → voice → avatar → captions → Remotion → R2
import { mkdir } from 'node:fs/promises';
import { type AdSpec, scriptToText } from '@/schema/ad';
import { type CountryConfig } from '@/schema/country';
import * as elevenlabs from '@/providers/elevenlabs';
import * as hedra from '@/providers/hedra';
import * as assemblyai from '@/providers/assemblyai';
import * as r2 from '@/providers/r2';

export interface RenderResult {
  specId: string;
  localPath: string;
  r2Key?: string;
  signedUrl?: string;
}

export async function renderAd(opts: {
  spec: AdSpec;
  country: CountryConfig;
  force?: boolean;
  upload?: boolean;
}): Promise<RenderResult> {
  const { spec, country } = opts;
  const workDir = `${import.meta.dir}/../../renders/${spec.countryId}/${spec.id}`;
  await mkdir(workDir, { recursive: true });

  const voicePath = `${workDir}/voice.mp3`;
  const avatarPath = `${workDir}/avatar.mp4`;
  const captionsPath = `${workDir}/captions.srt`;
  const finalPath = `${workDir}/final.mp4`;

  const voice = country.voices[spec.voiceId];
  if (!voice) throw new Error(`Voice ${spec.voiceId} not in country ${country.id}`);
  const avatar = country.avatars[spec.avatarId];
  if (!avatar) throw new Error(`Avatar ${spec.avatarId} not in country ${country.id}`);

  // 1. Voice (cached)
  if (opts.force || !(await Bun.file(voicePath).exists())) {
    console.log(`[${spec.id}] synthesizing voice...`);
    await elevenlabs.synthesize({
      voiceId: voice.voiceId,
      text: scriptToText(spec.script),
      modelId: voice.modelId,
      outputPath: voicePath,
    });
  }

  // 2. Avatar (cached)
  if (opts.force || !(await Bun.file(avatarPath).exists())) {
    console.log(`[${spec.id}] generating avatar...`);
    await hedra.generateAvatar({
      characterId: avatar.characterId,
      audioPath: voicePath,
      outputPath: avatarPath,
      aspectRatio: spec.aspectRatio === '9:16' ? '9:16' : '1:1',
    });
  }

  // 3. Captions (cached)
  if (spec.captions.enabled && (opts.force || !(await Bun.file(captionsPath).exists()))) {
    console.log(`[${spec.id}] transcribing captions...`);
    await assemblyai.transcribe({
      audioPath: voicePath,
      language: country.language,
      outputPath: captionsPath,
    });
  }

  // 4. Remotion render
  // Done out-of-process via @remotion/renderer in a separate step (see cli.ts).
  // We return paths so the CLI can invoke renderMedia() with the bundled composition.
  console.log(`[${spec.id}] assets ready at ${workDir}`);

  let r2Key: string | undefined;
  let signedUrl: string | undefined;
  if (opts.upload && (await Bun.file(finalPath).exists())) {
    r2Key = `ads/${spec.countryId}/${spec.id}.mp4`;
    await r2.upload({ key: r2Key, filePath: finalPath, contentType: 'video/mp4' });
    signedUrl = await r2.signedUrl(r2Key);
  }

  return { specId: spec.id, localPath: finalPath, r2Key, signedUrl };
}
