import { AbsoluteFill, interpolate, spring, useCurrentFrame, useVideoConfig } from 'remotion';

export const CTACard: React.FC<{ text: string; price: string; url: string }> = ({ text, price }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const scale = spring({ frame, fps, config: { damping: 12, stiffness: 120 } });
  const opacity = interpolate(frame, [0, 10], [0, 1], { extrapolateRight: 'clamp' });

  return (
    <AbsoluteFill
      style={{
        backgroundColor: 'rgba(0, 0, 0, 0.85)',
        alignItems: 'center',
        justifyContent: 'center',
        opacity,
      }}
    >
      <div
        style={{
          transform: `scale(${scale})`,
          textAlign: 'center',
          color: '#fff',
          fontFamily: 'Inter',
        }}
      >
        <div style={{ fontSize: 96, fontWeight: 900, marginBottom: 24 }}>FacturaAI</div>
        <div style={{ fontSize: 56, fontWeight: 700, marginBottom: 32 }}>{text}</div>
        <div
          style={{
            display: 'inline-block',
            padding: '24px 56px',
            borderRadius: 999,
            background: '#22c55e',
            fontSize: 64,
            fontWeight: 900,
          }}
        >
          {price}
        </div>
      </div>
    </AbsoluteFill>
  );
};
