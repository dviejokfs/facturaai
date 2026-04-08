import { AbsoluteFill, Audio, Sequence, Video, useVideoConfig } from 'remotion';
import type { AdSpec } from '@/schema/ad';
import type { CountryConfig } from '@/schema/country';
import { Captions } from './components/Captions';
import { CTACard } from './components/CTACard';
import { TextCard } from './components/TextCard';

export interface AdCompositionProps {
  spec: AdSpec;
  country: CountryConfig;
  assetUrls: {
    voice: string;
    avatar: string;
    captions: string;
    broll: Record<string, string>;
    appDemo: string;
    music: string;
  };
}

export const AdComposition: React.FC<AdCompositionProps> = ({ spec, country, assetUrls }) => {
  const { fps } = useVideoConfig();

  return (
    <AbsoluteFill style={{ backgroundColor: '#000' }}>
      {assetUrls.voice && <Audio src={assetUrls.voice} />}
      {assetUrls.music && <Audio src={assetUrls.music} volume={0.18} />}

      {spec.scenes.map((scene, i) => {
        const from = Math.round(scene.startSec * fps);
        const dur = Math.round((scene.endSec - scene.startSec) * fps);
        return (
          <Sequence key={i} from={from} durationInFrames={dur}>
            {scene.type === 'avatar' && assetUrls.avatar && (
              <Video src={assetUrls.avatar} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
            )}
            {scene.type === 'broll' && scene.brollId && assetUrls.broll[scene.brollId] && (
              <Video src={assetUrls.broll[scene.brollId]!} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
            )}
            {scene.type === 'app-demo' && assetUrls.appDemo && (
              <Video src={assetUrls.appDemo} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
            )}
            {scene.type === 'text-card' && scene.textOverlay && (
              <TextCard text={scene.textOverlay} style={country.captionStyle} />
            )}
          </Sequence>
        );
      })}

      {spec.captions.enabled && assetUrls.captions && (
        <Captions srtUrl={assetUrls.captions} style={country.captionStyle} font={country.fonts.captions} />
      )}

      <Sequence from={Math.round((spec.durationSec - 3) * fps)}>
        <CTACard
          text={spec.cta.text}
          price={country.pricingDisplay}
          url={spec.cta.urlKey === 'appStore' ? country.appStoreUrl : country.landingUrl}
        />
      </Sequence>
    </AbsoluteFill>
  );
};
