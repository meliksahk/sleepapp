import { cookies } from 'next/headers';

import { defaultLocale, isLocale, type Locale } from './dictionaries';

/** Dil çerezi. `httpOnly` DEĞİL: gizli veri değil ve istemci de okuyabilmeli. */
export const LOCALE_COOKIE = 'nocta_admin_locale';

/**
 * Aktif dili çerezden okur (sunucu bileşenleri).
 * Geçersiz/eksik değer varsayılana düşer — bozuk çerez paneli kilitlemez.
 */
export async function getLocale(): Promise<Locale> {
  const store = await cookies();
  const value = store.get(LOCALE_COOKIE)?.value;
  return isLocale(value) ? value : defaultLocale;
}
