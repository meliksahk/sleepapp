import { NextResponse } from 'next/server';
import { API_BASE } from '@/shared/api/config';
import { ACCESS_COOKIE, REFRESH_COOKIE, cookieOptions } from '@/shared/auth/session';

/** Refresh token ömrü (API'nin REFRESH_TOKEN_TTL varsayılanıyla hizalı: 30 gün). */
const REFRESH_MAX_AGE = 60 * 60 * 24 * 30;

/**
 * Panel giriş vekili: tarayıcı → BURASI → API. Tarayıcı API'ye doğrudan gitmez;
 * token'lar httpOnly çerezlere yazılır ve yanıt gövdesinde DÖNMEZ (JS görmemeli).
 */
export async function POST(request: Request): Promise<NextResponse> {
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: 'invalid_body' }, { status: 400 });
  }

  const res = await fetch(`${API_BASE}/v1/auth/admin/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
    cache: 'no-store',
  });

  if (!res.ok) {
    // API'nin durum kodu AYNEN yansıtılır: 401 (kimlik) ve 429 (çok deneme) farklı
    // şeylerdir; ikisini 401'de birleştirmek kullanıcıyı "parolam yanlış" sanıp
    // denemeye devam ettirirdi.
    //
    // `code` da geçirilir çünkü 401'in İKİ ANLAMI var: "parola yanlış" ve "2FA kodu
    // gerekli". Ayırmazsak form, parolası DOĞRU olan kullanıcıya "parola hatalı"
    // der ve kod alanını hiç göstermez — 2FA'lı hesap panele hiç giremez.
    //
    // Sızıntı yok: bu noktaya ancak DOĞRU parolayla gelinir (bkz. identity/errors.ts).
    return NextResponse.json(
      { error: 'login_failed', code: await errorCode(res) },
      { status: res.status },
    );
  }

  const session = (await res.json()) as {
    accessToken: string;
    refreshToken: string;
    accessTokenExpiresIn: number;
  };

  const out = NextResponse.json({ ok: true });
  out.cookies.set(ACCESS_COOKIE, session.accessToken, cookieOptions(session.accessTokenExpiresIn));
  out.cookies.set(REFRESH_COOKIE, session.refreshToken, cookieOptions(REFRESH_MAX_AGE));
  return out;
}

/**
 * API'nin hata kodunu güvenle çıkarır. Gövde okunamazsa/biçimsizse null döner:
 * giriş yolunu bir JSON ayrıştırma hatası yüzünden 500'e çevirmek, kullanıcıyı
 * anlamsız bir hatayla baş başa bırakırdı — 401 zaten doğru yanıt.
 */
async function errorCode(res: Response): Promise<string | null> {
  try {
    const body: unknown = await res.json();
    if (typeof body === 'object' && body !== null && 'code' in body) {
      const { code } = body as { code: unknown };
      return typeof code === 'string' ? code : null;
    }
  } catch {
    // Gövde yok/bozuk — kod bilinmiyor, çağıran genel mesaja düşer.
  }
  return null;
}

/**
 * Çıkış: SUNUCUDAKİ oturumu iptal eder, sonra çerezleri siler.
 *
 * Sıra ve "yine de sil" davranışı bilinçli: API'ye ulaşamasak bile çerezleri
 * temizleriz — kullanıcı "çıkış" dediyse bu cihazda oturum kapanmalıdır. Aksi
 * halde ağ hatası, kullanıcıyı açık oturumla baş başa bırakırdı.
 */
export async function DELETE(request: Request): Promise<NextResponse> {
  const refreshToken = parseCookie(request.headers.get('cookie'), REFRESH_COOKIE);

  if (refreshToken !== null) {
    try {
      await fetch(`${API_BASE}/v1/auth/logout`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ refreshToken }),
        cache: 'no-store',
      });
    } catch {
      // Yut: sunucuda iptal edemedik ama çerezi yine de sileceğiz (yukarı bkz.).
      // Token 30 gün geçerli kalır — kabul edilen risk, defterde.
    }
  }

  const out = NextResponse.json({ ok: true });
  out.cookies.set(ACCESS_COOKIE, '', cookieOptions(0));
  out.cookies.set(REFRESH_COOKIE, '', cookieOptions(0));
  return out;
}

/** Tek bir çerezi başlıktan okur (route handler'da `cookies()` yerine: test edilebilir). */
function parseCookie(header: string | null, name: string): string | null {
  if (header === null) return null;
  for (const part of header.split(';')) {
    const [k, ...rest] = part.trim().split('=');
    if (k === name && rest.length > 0) return decodeURIComponent(rest.join('='));
  }
  return null;
}
