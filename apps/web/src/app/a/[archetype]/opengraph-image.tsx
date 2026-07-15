import { ImageResponse } from 'next/og';
import { ARCHETYPE_SLUGS, getArchetype } from '@/content/archetypes';

export const alt = 'NOCTA sleep archetype';
export const size = { width: 1200, height: 630 };
export const contentType = 'image/png';

export function generateStaticParams(): Array<{ archetype: string }> {
  return ARCHETYPE_SLUGS.map((archetype) => ({ archetype }));
}

export default async function Image({ params }: { params: Promise<{ archetype: string }> }) {
  const { archetype } = await params;
  const data = getArchetype(archetype);
  const name = data?.name ?? 'NOCTA';
  const tagline = data?.tagline ?? 'Your night has an identity';

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
      <div style={{ fontSize: 28, color: '#9AA3C7', letterSpacing: 4 }}>SLEEP IDENTITY</div>
      <div style={{ fontSize: 92, fontWeight: 700, marginTop: 12 }}>{name}</div>
      <div style={{ fontSize: 32, color: '#9AA3C7', marginTop: 24, maxWidth: 900 }}>{tagline}</div>
    </div>,
    size,
  );
}
