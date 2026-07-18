import Link from 'next/link';
import { getArchetypes } from '@/content/archetypes';
import { t, type Locale } from '@/lib/i18n';
import { localePath } from '@/lib/routes';
import { buildArchetypeListJsonLd, buildBreadcrumbTrail } from '@/lib/schema';

/** Archetype dizini — `/archetypes` ve `/tr/archetypes` ortak bileşeni. */
export function ArchetypesIndexView({ locale }: { locale: Locale }) {
  const archetypes = getArchetypes(locale);
  const jsonLd = [
    buildArchetypeListJsonLd(archetypes, locale),
    buildBreadcrumbTrail([
      { name: t(locale, 'crumb.home'), path: locale === 'en' ? '' : '/tr' },
      { name: t(locale, 'archetypes.listName'), path: localePath(locale, '/archetypes') },
    ]),
  ];
  return (
    <>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
      />
      <main className="mx-auto max-w-2xl p-5">
        <p className="text-caption uppercase tracking-widest text-ink-secondary">
          {t(locale, 'archetypes.eyebrow')}
        </p>
        <h1 className="mt-1 text-display font-display">{t(locale, 'archetypes.h1')}</h1>
        <p className="mt-2 text-body text-ink-secondary">{t(locale, 'archetypes.intro')}</p>

        <ul className="mt-8 flex flex-col gap-4">
          {archetypes.map((a) => (
            <li key={a.slug}>
              <Link
                href={localePath(locale, `/a/${a.slug}`)}
                className="block rounded-card border border-ink-faint/20 p-4 hover:border-ink-faint/40"
              >
                <h2 className="text-h2 font-display">{a.name}</h2>
                <p className="mt-1 text-body text-ink-secondary">{a.tagline}</p>
              </Link>
            </li>
          ))}
        </ul>

        <Link
          href={localePath(locale, '/test')}
          className="mt-8 inline-block rounded-button bg-accent-aurora px-5 py-3 text-bg-base"
        >
          {t(locale, 'archetype.ctaTest')}
        </Link>
      </main>
    </>
  );
}
