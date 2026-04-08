// AssemblyAI — transcription with word-level timestamps for caption burning
// Docs: https://www.assemblyai.com/docs

const BASE = 'https://api.assemblyai.com/v2';

export async function transcribe(opts: {
  audioPath: string;
  language: string; // 'es', 'en', 'de'
  outputPath: string; // .srt
}): Promise<string> {
  const apiKey = process.env.ASSEMBLYAI_API_KEY;
  if (!apiKey) throw new Error('ASSEMBLYAI_API_KEY missing');

  // 1. Upload audio
  const audio = await Bun.file(opts.audioPath).arrayBuffer();
  const upload = await fetch(`${BASE}/upload`, {
    method: 'POST',
    headers: { authorization: apiKey, 'content-type': 'application/octet-stream' },
    body: audio,
  });
  if (!upload.ok) throw new Error(`AssemblyAI upload: ${await upload.text()}`);
  const { upload_url } = (await upload.json()) as { upload_url: string };

  // 2. Submit transcription
  const submit = await fetch(`${BASE}/transcript`, {
    method: 'POST',
    headers: { authorization: apiKey, 'content-type': 'application/json' },
    body: JSON.stringify({
      audio_url: upload_url,
      language_code: opts.language,
      punctuate: true,
      format_text: true,
    }),
  });
  const { id } = (await submit.json()) as { id: string };

  // 3. Poll
  for (let i = 0; i < 120; i++) {
    await new Promise((r) => setTimeout(r, 3000));
    const status = await fetch(`${BASE}/transcript/${id}`, {
      headers: { authorization: apiKey },
    });
    const data = (await status.json()) as { status: string };
    if (data.status === 'completed') {
      // 4. Download SRT
      const srt = await fetch(`${BASE}/transcript/${id}/srt`, {
        headers: { authorization: apiKey },
      });
      await Bun.write(opts.outputPath, await srt.text());
      return opts.outputPath;
    }
    if (data.status === 'error') throw new Error('AssemblyAI transcription failed');
  }
  throw new Error('AssemblyAI transcription timed out');
}
