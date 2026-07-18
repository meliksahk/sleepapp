import { ImageResponse } from 'next/og';

/**
 * OG görsel şablonu — dil sürümleri arasında paylaşılır.
 *
 * satori (ImageResponse) build-time Node'da çalışır; CSS değişkeni okuyamaz →
 * token hex'leri burada gömülür (mevcut archetype/blog OG rotalarıyla aynı kabul
 * edilmiş desen).
 */
export const OG_SIZE = { width: 1200, height: 630 } as const;
export const OG_CONTENT_TYPE = 'image/png';

const BG = '#0A0E1A';
const INK = '#F2F4FF';
const INK_DIM = '#9AA3C7';

export function renderOgImage(input: {
  eyebrow: string;
  title: string;
  subtitle: string;
}): ImageResponse {
  return new ImageResponse(
    <div
      style={{
        display: 'flex',
        flexDirection: 'column',
        width: '100%',
        height: '100%',
        background: BG,
        color: INK,
        padding: 96,
        justifyContent: 'center',
      }}
    >
      <div style={{ fontSize: 28, color: INK_DIM, letterSpacing: 4 }}>{input.eyebrow}</div>
      <div style={{ fontSize: 84, fontWeight: 700, marginTop: 12, maxWidth: 1000 }}>
        {input.title}
      </div>
      <div style={{ fontSize: 32, color: INK_DIM, marginTop: 24, maxWidth: 900 }}>
        {input.subtitle}
      </div>
    </div>,
    OG_SIZE,
  );
}
