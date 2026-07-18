import { ArchetypeTest } from '@/components/ArchetypeTest';
import { t, type Locale } from '@/lib/i18n';

/** Test sayfası gövdesi — `/test` ve `/tr/test` ortak bileşeni. */
export function TestView({ locale }: { locale: Locale }) {
  return (
    <main className="mx-auto max-w-2xl p-5">
      <h1 className="text-display font-display">{t(locale, 'test.h1')}</h1>
      <p className="mt-2 mb-6 text-body text-ink-secondary">{t(locale, 'test.intro')}</p>
      <ArchetypeTest locale={locale} />
    </main>
  );
}
