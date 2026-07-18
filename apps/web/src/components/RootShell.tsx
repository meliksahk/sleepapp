import { SiteFooter } from '@/components/SiteFooter';
import type { Locale } from '@/lib/i18n';
import { buildOrganizationJsonLd, buildWebSiteJsonLd } from '@/lib/schema';

/**
 * `<html>` + `<body>` iskeleti — EN ve TR KÖK layout'larının ortak gövdesi.
 *
 * **Neden iki kök layout var:** `<html lang>` doğru dili göstermek zorunda (erişilebilirlik
 * + arama motoru dil sinyali). Next'te `<html>`ı yalnızca kök layout render eder ve tek
 * bir kök layout `lang`i dinamik seçemez (pathname'i bilmez). Route grubu başına kök
 * layout (`(en)` / `(tr)`) bunun Next'teki desteklenen çözümüdür; URL'ler değişmez.
 */
export function RootShell({ locale, children }: { locale: Locale; children: React.ReactNode }) {
  const siteJsonLd = [buildOrganizationJsonLd(locale), buildWebSiteJsonLd(locale)];
  return (
    <html lang={locale}>
      <body>
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(siteJsonLd) }}
        />
        {children}
        <SiteFooter locale={locale} />
      </body>
    </html>
  );
}
