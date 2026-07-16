import { cookies } from 'next/headers';
import { API_BASE } from './config';
import { ACCESS_COOKIE } from '@/shared/auth/session';

export class ApiError extends Error {
  constructor(readonly status: number) {
    super(`API ${status}`);
  }
}

/**
 * Sunucu tarafı API çağrısı (Server Component / route handler).
 *
 * Token httpOnly çerezden okunur ve tarayıcıya HİÇ değmez. Bu yüzden panelin
 * veri çekme yolu SUNUCUDAN geçmek zorundadır — bedeli #116'da bilerek kabul edildi.
 *
 * 401'de burada YENİLEME YAPILMAZ: Server Component çerez yazamaz (Next.js kısıtı),
 * dolayısıyla yenilenen token'ı saklayamazdık. Yenileme middleware'in işi (#117);
 * buraya 401 gelirse çağıran gösterir, bir sonraki gezintide middleware yeniler.
 */
export async function apiGet<T>(path: string): Promise<T> {
  const token = (await cookies()).get(ACCESS_COOKIE)?.value;
  const res = await fetch(`${API_BASE}${path}`, {
    headers: token ? { Authorization: `Bearer ${token}` } : {},
    // Panel verisi taze olmalı: editörün az önce kaydettiği içerik listede görünmeli.
    cache: 'no-store',
  });
  if (!res.ok) throw new ApiError(res.status);
  return (await res.json()) as T;
}
