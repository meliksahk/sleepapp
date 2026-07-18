import Link from 'next/link';
import { getArchetypes, type ArchetypeContent as Archetype } from '@/content/archetypes';
import { ShareButton } from '@/components/ShareButton';
import { ShareCard } from '@/components/ShareCard';
import { t, type Locale } from '@/lib/i18n';
import { localePath, SITE_URL } from '@/lib/routes';

export function ArchetypeContent({
  archetype,
  locale = 'en',
}: {
  archetype: Archetype;
  locale?: Locale;
}) {
  const shareUrl = `${SITE_URL}${localePath(locale, `/a/${archetype.slug}`)}`;
  const others = getArchetypes(locale).filter((a) => a.slug !== archetype.slug);
  return (
    <article className="mx-auto max-w-2xl p-5">
      <p className="text-caption uppercase tracking-widest text-ink-secondary">
        {t(locale, 'archetype.eyebrow')}
      </p>
      <h1 className="mt-1 text-display font-display">{archetype.name}</h1>
      <p className="mt-2 text-body text-ink-secondary">{archetype.tagline}</p>

      {/* GEO: kısa, alıntılanabilir cevap bloğu */}
      <p className="mt-6 text-body">{archetype.summary}</p>

      {archetype.paragraphs.map((p, i) => (
        <p key={i} className="mt-4 text-body text-ink-secondary">
          {p}
        </p>
      ))}

      <h2 className="mt-8 text-h2 font-display">{t(locale, 'archetype.soundsHeading')}</h2>
      <ul className="mt-2 list-disc pl-5 text-ink-secondary">
        {archetype.soundsThatHelp.map((s) => (
          <li key={s}>{s}</li>
        ))}
      </ul>

      <div className="mt-8 flex flex-wrap items-center gap-3">
        <a
          href={localePath(locale, '/test')}
          className="inline-block rounded-button bg-accent-aurora px-5 py-3 text-bg-base"
        >
          {t(locale, 'archetype.ctaTest')}
        </a>
        <ShareButton
          title={t(locale, 'card.shareTitle', { name: archetype.name })}
          url={shareUrl}
          locale={locale}
        />
      </div>

      {/* Viral kanca (docs/05): indirilebilir paylaşım kartı */}
      <section className="mt-8" aria-label={t(locale, 'archetype.shareRegion')}>
        <h2 className="text-h2 font-display">{t(locale, 'archetype.shareHeading')}</h2>
        <p className="mt-1 mb-4 text-body text-ink-secondary">
          {t(locale, 'archetype.shareIntro')}
        </p>
        <ShareCard
          slug={archetype.slug}
          name={archetype.name}
          tagline={archetype.tagline}
          sounds={archetype.soundsThatHelp}
          locale={locale}
        />
      </section>

      {/* İç bağlantı (SEO): diğer sleep identity'leri */}
      <nav
        aria-label={t(locale, 'archetype.othersHeading')}
        className="mt-10 border-t border-ink-faint/20 pt-6"
      >
        <h2 className="text-h2 font-display">{t(locale, 'archetype.othersHeading')}</h2>
        <ul className="mt-3 flex flex-col gap-2">
          {others.map((a) => (
            <li key={a.slug}>
              <Link
                href={localePath(locale, `/a/${a.slug}`)}
                className="text-body text-accent-aurora hover:underline"
              >
                {a.name} — {a.tagline}
              </Link>
            </li>
          ))}
        </ul>
      </nav>
    </article>
  );
}
