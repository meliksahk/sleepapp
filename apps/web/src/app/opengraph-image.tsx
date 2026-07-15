import { ImageResponse } from 'next/og';

// Site OG görseli (docs/05 §3.1). Build'de üretilir; token renkleri (docs/06).
export const alt = 'NOCTA — Your night has an identity';
export const size = { width: 1200, height: 630 };
export const contentType = 'image/png';

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
      <div style={{ fontSize: 30, color: '#9AA3C7', letterSpacing: 4 }}>NOCTA</div>
      <div style={{ fontSize: 84, fontWeight: 700, marginTop: 12 }}>
        Your night has an identity.
      </div>
      <div style={{ fontSize: 34, color: '#7C6CFF', marginTop: 24 }}>
        Find your sleep identity →
      </div>
    </div>,
    size,
  );
}
