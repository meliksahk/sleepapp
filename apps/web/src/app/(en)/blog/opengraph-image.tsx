import { ImageResponse } from 'next/og';

export const alt = 'NOCTA Blog — Sleep Rituals & Soundscapes';
export const size = { width: 1200, height: 630 };
export const contentType = 'image/png';

// satori build-time Node'da çalışır → token hex'leri gömülür (archetype OG deseni).
export default function Image() {
  return new ImageResponse(
    <div
      style={{
        display: 'flex',
        flexDirection: 'column',
        width: '100%',
        height: '100%',
        background: '#0A0E1A',
        color: '#F2F4FF',
        padding: 96,
        justifyContent: 'center',
      }}
    >
      <div style={{ fontSize: 28, color: '#9AA3C7', letterSpacing: 4 }}>NOCTA</div>
      <div style={{ fontSize: 88, fontWeight: 700, marginTop: 12 }}>Blog</div>
      <div style={{ fontSize: 32, color: '#9AA3C7', marginTop: 24, maxWidth: 900 }}>
        Simple guides to sleep rituals, soundscapes, and the rhythm of your nights.
      </div>
    </div>,
    size,
  );
}
