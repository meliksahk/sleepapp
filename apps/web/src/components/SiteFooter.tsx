import Link from 'next/link';
import { t, type Locale } from '@/lib/i18n';
import { localePath } from '@/lib/routes';

/**
 * Site geneli footer — iç bağlantı (SEO sinyali) + keşfedilebilirlik. Her sayfada
 * (root layout). Sağlık iddiası YOK: "relaxation & sleep ritual" konumlandırması.
 *
 * Dil geçişi burada yaşar: kullanıcı ve tarayıcı için TR/EN sürümü keşfedilebilir
 * olur. Hedef, karşı dilin ANA SAYFASIDIR — footer sunucu bileşeni olduğundan mevcut
 * yolu bilmez; sayfa-sayfa eşleme `alternates.languages` (hreflang) ile zaten kurulu,
 * bu link insan içindir.
 */
const LINK_KEYS = [
  { path: '/archetypes', key: 'footer.identities' },
  { path: '/test', key: 'footer.test' },
  { path: '/faq', key: 'footer.faq' },
] as const;

export function SiteFooter({ locale = 'en' }: { locale?: Locale }) {
  const other: Locale = locale === 'en' ? 'tr' : 'en';
  return (
    <footer className="mx-auto mt-16 max-w-2xl border-t border-ink-faint/20 p-5">
      <nav aria-label={t(locale, 'footer.nav')} className="flex flex-wrap gap-x-6 gap-y-2">
        {LINK_KEYS.map((l) => (
          <Link
            key={l.path}
            href={localePath(locale, l.path)}
            className="text-body text-ink-secondary hover:text-ink-primary"
          >
            {t(locale, l.key)}
          </Link>
        ))}
        <Link
          href={localePath(other, '/')}
          hrefLang={other}
          className="text-body text-ink-secondary hover:text-ink-primary"
        >
          {t(locale, 'footer.otherLocale')}
        </Link>
      </nav>
      <p className="mt-4 text-caption text-ink-faint">{t(locale, 'footer.tagline')}</p>
    </footer>
  );
}
