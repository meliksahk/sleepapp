import type { Metadata } from 'next';
import './globals.css';

import { I18nProvider } from '@/shared/i18n/I18nProvider';
import { translate } from '@/shared/i18n/dictionaries';
import { getLocale } from '@/shared/i18n/locale';

/**
 * Sekme başlığı da çeviriye tabi: sabit `metadata` nesnesi dili göremezdi
 * (`generateMetadata` async olabildiği için çerezi okuyabiliyor).
 */
export async function generateMetadata(): Promise<Metadata> {
  const locale = await getLocale();
  return {
    title: translate(locale, 'meta.title'),
    description: translate(locale, 'meta.description'),
  };
}

/**
 * Kök layout — aktif dili çerezden okur, `<html lang>` ile doğru bildirir ve
 * istemci ağacına indirir.
 *
 * `lang="en"` SABİTTİ: panel Türkçe metin gösterirken tarayıcıya/ekran okuyucuya
 * "bu İngilizce" diyordu. Erişilebilirlik açısından yanlış telaffuz demek.
 */
export default async function RootLayout({ children }: { children: React.ReactNode }) {
  const locale = await getLocale();
  return (
    <html lang={locale}>
      <body>
        <I18nProvider locale={locale}>{children}</I18nProvider>
      </body>
    </html>
  );
}
