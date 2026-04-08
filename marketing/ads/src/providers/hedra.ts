// Hedra Character-3 — audio-driven talking head
// Docs: https://docs.hedra.com
// NOTE: Hedra's API is evolving; verify endpoints against current docs before production use.

const BASE = 'https://api.hedra.com/v1';

export async function generateAvatar(opts: {
  characterId: string;
  audioPath: string;
  outputPath: string;
  aspectRatio?: '9:16' | '1:1' | '16:9';
}): Promise<string> {
  const apiKey = process.env.HEDRA_API_KEY;
  if (!apiKey) throw new Error('HEDRA_API_KEY missing');

  // 1. Upload audio
  const audioBlob = await Bun.file(opts.audioPath).arrayBuffer();
  const uploadForm = new FormData();
  uploadForm.append('file', new Blob([audioBlob]), 'voice.mp3');

  const upload = await fetch(`${BASE}/audio`, {
    method: 'POST',
    headers: { 'x-api-key': apiKey },
    body: uploadForm,
  });
  if (!upload.ok) throw new Error(`Hedra upload error: ${await upload.text()}`);
  const { id: audioId } = (await upload.json()) as { id: string };

  // 2. Start generation job
  const job = await fetch(`${BASE}/characters/${opts.characterId}/generations`, {
    method: 'POST',
    headers: { 'x-api-key': apiKey, 'content-type': 'application/json' },
    body: JSON.stringify({
      audio_id: audioId,
      aspect_ratio: opts.aspectRatio ?? '9:16',
    }),
  });
  if (!job.ok) throw new Error(`Hedra job error: ${await job.text()}`);
  const { id: jobId } = (await job.json()) as { id: string };

  // 3. Poll until ready
  for (let i = 0; i < 120; i++) {
    await new Promise((r) => setTimeout(r, 5000));
    const status = await fetch(`${BASE}/generations/${jobId}`, {
      headers: { 'x-api-key': apiKey },
    });
    const data = (await status.json()) as {
      status: string;
      video_url?: string;
    };
    if (data.status === 'complete' && data.video_url) {
      const video = await fetch(data.video_url);
      await Bun.write(opts.outputPath, video);
      return opts.outputPath;
    }
    if (data.status === 'failed') throw new Error(`Hedra generation failed`);
  }
  throw new Error('Hedra generation timed out');
}
