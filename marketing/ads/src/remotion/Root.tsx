import { Composition } from 'remotion';
import { AdComposition, type AdCompositionProps } from './AdComposition';

const defaultProps: AdCompositionProps = {
  spec: {
    id: 'preview',
    countryId: 'es-ES',
    createdAt: new Date().toISOString(),
    angle: 'preview',
    platform: ['meta'],
    durationSec: 30,
    aspectRatio: '9:16',
    avatarId: 'carlos',
    voiceId: 'carlos',
    script: {
      hook: 'POV: llega el día 15 del trimestre',
      problem: 'Y empiezas a buscar facturas en Gmail, WhatsApp, fotos del móvil...',
      solution: 'InvoScanAI conecta tu Gmail y ordena cada factura según llega.',
      proof: 'Le mando todo limpio a mi gestora en un clic. Por fin.',
      cta: 'Descárgala gratis. €7 al mes.',
    },
    scenes: [
      { type: 'avatar', startSec: 0, endSec: 2 },
      { type: 'broll', startSec: 2, endSec: 8, brollId: 'messy-desk' },
      { type: 'app-demo', startSec: 8, endSec: 18 },
      { type: 'avatar', startSec: 18, endSec: 25 },
      { type: 'text-card', startSec: 25, endSec: 30, textOverlay: '€7/mes' },
    ],
    captions: { enabled: true },
    cta: { text: 'Descárgala gratis', urlKey: 'appStore' },
    tags: ['preview'],
  },
  country: {
    id: 'es-ES',
    country: 'ES',
    language: 'es',
    currency: 'EUR',
    currencySymbol: '€',
    pricingDisplay: '€7/mes',
    taxAuthority: 'Hacienda',
    accountantTerm: 'gestor',
    selfEmployedTerm: 'autónomo',
    taxPeriodTerm: 'trimestre',
    appLocale: 'es-ES',
    appStoreUrl: 'https://apps.apple.com/es/app/invoscanai',
    landingUrl: 'https://invoscanai.com/es',
    voices: {},
    avatars: {},
    brollLibrary: [],
    appDemoClip: '',
    fonts: { captions: 'Inter', captionSize: 56 },
    captionStyle: 'tiktok-yellow',
  },
  assetUrls: {
    voice: '',
    avatar: '',
    captions: '',
    broll: {},
    appDemo: '',
    music: '',
  },
};

export const RemotionRoot: React.FC = () => {
  return (
    <Composition
      id="AdComposition"
      component={AdComposition}
      durationInFrames={30 * 30}
      fps={30}
      width={1080}
      height={1920}
      defaultProps={defaultProps}
    />
  );
};
