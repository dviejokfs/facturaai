import { AbsoluteFill, useCurrentFrame, useVideoConfig } from 'remotion';
import { useEffect, useMemo, useState } from 'react';

interface Cue {
  start: number;
  end: number;
  text: string;
}

// Hoisted outside component — no per-render allocation (js-hoist-regexp)
const CARRIAGE_RETURN = /\r/g;
const TIMING_ARROW = '-->';

function parseSrt(srt: string): Cue[] {
  const blocks = srt.replace(CARRIAGE_RETURN, '').split('\n\n').filter(Boolean);
  const cues: Cue[] = [];
  for (const block of blocks) {
    const lines = block.split('\n').filter(Boolean);
    if (lines.length < 2) continue;
    const timing = lines.find((l) => l.includes(TIMING_ARROW));
    if (!timing) continue;
    const [a, b] = timing.split(TIMING_ARROW).map((s) => s.trim());
    const text = lines.slice(lines.indexOf(timing) + 1).join(' ');
    cues.push({ start: srtTimeToSec(a!), end: srtTimeToSec(b!), text });
  }
  return cues;
}

function srtTimeToSec(t: string): number {
  const [h, m, rest] = t.split(':');
  const [s, ms] = rest!.split(',');
  return Number(h) * 3600 + Number(m) * 60 + Number(s) + Number(ms) / 1000;
}

export const Captions: React.FC<{ srtUrl: string; style: string; font: string }> = ({
  srtUrl,
  style,
  font,
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const sec = frame / fps;
  const [cues, setCues] = useState<Cue[]>([]);

  useEffect(() => {
    if (!srtUrl) return;
    fetch(srtUrl)
      .then((r) => r.text())
      .then((t) => setCues(parseSrt(t)))
      .catch(() => setCues([]));
  }, [srtUrl]);

  // Binary-searchable: cues are sorted by start time from parseSrt.
  // useMemo avoids re-scanning on every frame when cues haven't changed (rerender-memo).
  const current = useMemo(() => {
    return cues.find((c) => sec >= c.start && sec <= c.end);
  }, [cues, sec]);

  if (!current) return null;

  const color = style === 'tiktok-yellow' ? '#FFEB3B' : '#FFFFFF';
  return (
    <AbsoluteFill style={{ alignItems: 'center', justifyContent: 'flex-end', paddingBottom: 280 }}>
      <div
        style={{
          fontFamily: font,
          fontWeight: 900,
          fontSize: 64,
          color,
          textAlign: 'center',
          maxWidth: '85%',
          textShadow: '0 0 8px rgba(0,0,0,0.85), 0 4px 12px rgba(0,0,0,0.7)',
          lineHeight: 1.1,
          textTransform: 'uppercase',
        }}
      >
        {current.text}
      </div>
    </AbsoluteFill>
  );
};
