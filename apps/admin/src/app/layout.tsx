import type { Metadata } from 'next';
import './globals.css';

import { I18nProvider } from '@/shared/i18n/I18nProvider';
import { getLocale } from '@/shared/i18n/locale';

export const metadata: Metadata = {
  title: 'NOCTA Admin',
  description: 'NOCTA yönetim paneli',
};

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
