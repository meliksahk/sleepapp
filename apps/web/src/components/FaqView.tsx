import Link from 'next/link';
import { getFaqItems } from '@/content/faq';
import { t, type Locale } from '@/lib/i18n';
import { localePath } from '@/lib/routes';
import { buildBreadcrumbTrail, buildFaqJsonLd } from '@/lib/schema';

/** SSS sayfası — `/faq` ve `/tr/faq` ortak bileşeni (FAQPage JSON-LD dahil). */
export function FaqView({ locale }: { locale: Locale }) {
  const items = getFaqItems(locale);
  const jsonLd = [
    buildFaqJsonLd(items),
    buildBreadcrumbTrail([
      { name: t(locale, 'crumb.home'), path: locale === 'en' ? '' : '/tr' },
      { name: t(locale, 'footer.faq'), path: localePath(locale, '/faq') },
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
          {t(locale, 'faq.eyebrow')}
        </p>
        <h1 className="mt-1 text-display font-display">{t(locale, 'faq.h1')}</h1>

        <dl className="mt-8 flex flex-col gap-6">
          {items.map((item) => (
            <div key={item.question}>
              <dt className="text-h2 font-display">{item.question}</dt>
              <dd className="mt-1 text-body text-ink-secondary">{item.answer}</dd>
            </div>
          ))}
        </dl>

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
