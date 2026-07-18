'use server';

import { revalidatePath } from 'next/cache';
import { cookies } from 'next/headers';

import { isLocale } from './dictionaries';
import { LOCALE_COOKIE } from './locale';

/**
 * Dili değiştirir. Sunucu eylemi: çerez ancak sunucuda yazılabilir ve tüm sunucu
 * bileşenlerinin yeniden render edilmesi gerekir (yoksa yalnız istemci metinleri
 * değişir, sunucuda üretilenler eski dilde kalırdı).
 */
export async function setLocale(next: string): Promise<void> {
  if (!isLocale(next)) return; // bilinmeyen dil sessizce yok sayılır
  const store = await cookies();
  store.set(LOCALE_COOKIE, next, {
    path: '/',
    maxAge: 60 * 60 * 24 * 365,
    sameSite: 'lax',
  });
  revalidatePath('/', 'layout');
}
