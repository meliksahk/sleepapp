import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import { ARCHETYPE_SLUGS, getArchetype } from '@/content/archetypes';
import { ArchetypeContent } from '@/components/ArchetypeContent';
import { buildArchetypeJsonLd, buildBreadcrumbJsonLd } from '@/lib/schema';

interface PageProps {
  params: Promise<{ archetype: string }>;
}

export function generateStaticParams(): Array<{ archetype: string }> {
  return ARCHETYPE_SLUGS.map((archetype) => ({ archetype }));
}

export async function generateMetadata({ params }: PageProps): Promise<Metadata> {
  const { archetype } = await params;
  const data = getArchetype(archetype);
  if (!data) return {};
  return {
    title: `${data.name} — Your Sleep Identity | NOCTA`,
    description: data.summary,
    openGraph: { title: `${data.name} — Your Sleep Identity`, description: data.summary },
  };
}

export default async function ArchetypePage({ params }: PageProps) {
  const { archetype } = await params;
  const data = getArchetype(archetype);
  if (!data) notFound();

  const jsonLd = [buildArchetypeJsonLd(data), buildBreadcrumbJsonLd(data)];
  return (
    <>
      <script
        type="application/ld+json"
        // JSON-LD tek util'den üretilir; içerik güvenilir (kullanıcı girdisi değil).
        dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
      />
      <ArchetypeContent archetype={data} />
    </>
  );
}
