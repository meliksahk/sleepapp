import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import { ARCHETYPE_SLUGS, getArchetypeIn } from '@/content/archetypes';
import { ArchetypeContent } from '@/components/ArchetypeContent';
import { buildArchetypeMetadata } from '@/lib/page-metadata';
import { buildArchetypeJsonLd, buildBreadcrumbJsonLd } from '@/lib/schema';

const LOCALE = 'tr' as const;

interface PageProps {
  params: Promise<{ archetype: string }>;
}

// Slug'lar dile göre DEĞİŞMEZ (paylaşım linkleri + derin linkler sabit kalsın).
export function generateStaticParams(): Array<{ archetype: string }> {
  return ARCHETYPE_SLUGS.map((archetype) => ({ archetype }));
}

export async function generateMetadata({ params }: PageProps): Promise<Metadata> {
  const { archetype } = await params;
  const data = getArchetypeIn(LOCALE, archetype);
  if (!data) return {};
  return buildArchetypeMetadata(LOCALE, data);
}

export default async function ArchetypePage({ params }: PageProps) {
  const { archetype } = await params;
  const data = getArchetypeIn(LOCALE, archetype);
  if (!data) notFound();

  const jsonLd = [buildArchetypeJsonLd(data, LOCALE), buildBreadcrumbJsonLd(data, LOCALE)];
  return (
    <>
      <script
        type="application/ld+json"
        // JSON-LD tek util'den üretilir; içerik güvenilir (kullanıcı girdisi değil).
        dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
      />
      <ArchetypeContent archetype={data} locale={LOCALE} />
    </>
  );
}
