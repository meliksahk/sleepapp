import { NextResponse } from 'next/server';
import { API_BASE } from '@/shared/api/config';
import { ACCESS_COOKIE, REFRESH_COOKIE, cookieOptions } from '@/features/auth/session';

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
    return NextResponse.json({ error: 'login_failed' }, { status: res.status });
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

/** Çıkış: çerezleri sil. (Sunucudaki oturumu iptal etmek ayrı iş — defterde.) */
export async function DELETE(): Promise<NextResponse> {
  const out = NextResponse.json({ ok: true });
  out.cookies.set(ACCESS_COOKIE, '', cookieOptions(0));
  out.cookies.set(REFRESH_COOKIE, '', cookieOptions(0));
  return out;
}
