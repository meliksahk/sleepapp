import { WaitlistForm } from '@/components/WaitlistForm';
import { t, type Locale } from '@/lib/i18n';
import { localePath } from '@/lib/routes';

/**
 * Ana sayfa gövdesi — EN (`/`) ve TR (`/tr`) rotalarının ORTAK bileşeni.
 * İki dil için iki ayrı sayfa kopyalanmaz; rota dosyaları yalnızca `locale` besler.
 */
export function HomeView({ locale }: { locale: Locale }) {
  return (
    <main className="mx-auto max-w-2xl p-5">
      <h1 className="text-display font-display">{t(locale, 'home.title')}</h1>
      <p className="mt-3 text-body text-ink-secondary">{t(locale, 'home.intro')}</p>
      <a
        href={localePath(locale, '/test')}
        className="mt-5 inline-block rounded-button bg-accent-aurora px-5 py-3 text-bg-base"
      >
        {t(locale, 'home.cta')}
      </a>

      <section className="mt-10">
        <h2 className="text-h2 font-display">{t(locale, 'home.waitlistHeading')}</h2>
        <p className="mt-2 mb-3 text-body text-ink-secondary">{t(locale, 'home.waitlistIntro')}</p>
        <WaitlistForm locale={locale} />
      </section>
    </main>
  );
}
