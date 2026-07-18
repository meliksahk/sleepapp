import { ImageResponse } from 'next/og';
import { BLOG_SLUGS, getBlogPost } from '@/content/blog';

export const alt = 'NOCTA blog';
export const size = { width: 1200, height: 630 };
export const contentType = 'image/png';

export function generateStaticParams(): Array<{ slug: string }> {
  return BLOG_SLUGS.map((slug) => ({ slug }));
}

// Not: satori (ImageResponse) build-time Node'da çalışır; CSS değişkeni okuyamaz →
// token hex'leri burada gömülür (archetype OG'siyle aynı kabul edilmiş desen).
export default async function Image({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const post = getBlogPost(slug);
  const title = post?.title ?? 'NOCTA Blog';
  const description = post?.description ?? 'Sleep rituals and soundscapes.';

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
      <div style={{ fontSize: 28, color: '#9AA3C7', letterSpacing: 4 }}>SLEEP RITUAL</div>
      <div style={{ fontSize: 68, fontWeight: 700, marginTop: 16, maxWidth: 1000 }}>{title}</div>
      <div style={{ fontSize: 30, color: '#9AA3C7', marginTop: 24, maxWidth: 960 }}>
        {description}
      </div>
      <div style={{ fontSize: 26, color: '#7C6CFF', marginTop: 40 }}>nocta.app</div>
    </div>,
    size,
  );
}
