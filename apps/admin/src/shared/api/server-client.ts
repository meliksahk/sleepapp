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

/**
 * Yazma çağrısı. Hata FIRLATMAZ, ayrık sonuç döner: yazma hataları (409 slug dolu,
 * 400 geçersiz) KULLANICIYA GÖSTERİLECEK olağan sonuçlardır — istisna yapıp yakalamak
 * bunları "beklenmedik" gibi ele almak olurdu. Okuma (`apiGet`) tersine: 401/403 orada
 * sayfanın hiç render edilemeyeceği anlamına gelir.
 */
export async function apiPost<T>(
  path: string,
  body: unknown,
): Promise<{ ok: true; data: T } | { ok: false; status: number; code?: string }> {
  const token = (await cookies()).get(ACCESS_COOKIE)?.value;
  const res = await fetch(`${API_BASE}${path}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: JSON.stringify(body),
    cache: 'no-store',
  });

  if (res.ok) return { ok: true, data: (await res.json()) as T };

  // API'nin problem+json gövdesindeki `code` taşınır: mesajı ondan seçeceğiz.
  let code: string | undefined;
  try {
    code = ((await res.json()) as { code?: string }).code;
  } catch {
    // Gövde yoksa/bozuksa yalnızca durum koduyla devam — sessizce yutma değil,
    // çağıran zaten status'a göre de mesaj seçebiliyor.
  }
  return { ok: false, status: res.status, code };
}
