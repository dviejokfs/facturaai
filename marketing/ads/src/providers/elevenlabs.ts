// ElevenLabs TTS — voice cloning + multilingual v2/v3
// Docs: https://elevenlabs.io/docs/api-reference/text-to-speech

const BASE = 'https://api.elevenlabs.io/v1';

export async function synthesize(opts: {
  voiceId: string;
  text: string;
  modelId?: string;
  outputPath: string;
}): Promise<string> {
  const apiKey = process.env.ELEVENLABS_API_KEY;
  if (!apiKey) throw new Error('ELEVENLABS_API_KEY missing');

  const res = await fetch(`${BASE}/text-to-speech/${opts.voiceId}`, {
    method: 'POST',
    headers: {
      'xi-api-key': apiKey,
      'content-type': 'application/json',
      accept: 'audio/mpeg',
    },
    body: JSON.stringify({
      text: opts.text,
      model_id: opts.modelId ?? 'eleven_multilingual_v2',
      voice_settings: { stability: 0.5, similarity_boost: 0.75, style: 0.0 },
    }),
  });

  if (!res.ok) {
    throw new Error(`ElevenLabs error ${res.status}: ${await res.text()}`);
  }

  await Bun.write(opts.outputPath, res);
  return opts.outputPath;
}
