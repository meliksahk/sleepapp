import { ARCHETYPE_SLUGS, getArchetypeIn } from '@/content/archetypes';
import { t } from '@/lib/i18n';
import { OG_CONTENT_TYPE, OG_SIZE, renderOgImage } from '@/lib/og';

export const alt = 'NOCTA uyku arketipi';
export const size = OG_SIZE;
export const contentType = OG_CONTENT_TYPE;

export function generateStaticParams(): Array<{ archetype: string }> {
  return ARCHETYPE_SLUGS.map((archetype) => ({ archetype }));
}

export default async function Image({ params }: { params: Promise<{ archetype: string }> }) {
  const { archetype } = await params;
  const data = getArchetypeIn('tr', archetype);
  return renderOgImage({
    eyebrow: t('tr', 'card.eyebrow'),
    title: data?.name ?? 'NOCTA',
    subtitle: data?.tagline ?? t('tr', 'home.title'),
  });
}
