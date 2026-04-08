import { AbsoluteFill } from 'remotion';

export const TextCard: React.FC<{ text: string; style: string }> = ({ text }) => {
  return (
    <AbsoluteFill
      style={{
        alignItems: 'center',
        justifyContent: 'center',
        backgroundColor: '#000',
      }}
    >
      <div
        style={{
          color: '#fff',
          fontFamily: 'Inter',
          fontSize: 120,
          fontWeight: 900,
          textAlign: 'center',
        }}
      >
        {text}
      </div>
    </AbsoluteFill>
  );
};
