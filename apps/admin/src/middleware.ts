import { NextResponse, type NextRequest } from 'next/server';
import { ACCESS_COOKIE } from '@/features/auth/session';

/**
 * Panel kapısı (docs/03 A0): oturum çerezi yoksa /login'e atar.
 *
 * DİKKAT — BU BİR YETKİ KONTROLÜ DEĞİLDİR: middleware yalnızca çerezin VARLIĞINA
 * bakar, token'ı doğrulamaz (Edge runtime'da RS256 doğrulaması + anahtar dağıtımı
 * ayrı bir iştir). Gerçek kapı SUNUCUDADIR: her admin ucu AuthGuard + RolesGuard +
 * aud='admin' ister (#112/#113). Buradaki kontrol yalnızca UX'tir — geçersiz çerezle
 * gelen kullanıcı sayfayı görür ama sayfa veri ÇEKEMEZ (API 401/403 döner).
 * CLAUDE.md §3.3: "yalnızca UI gizleme yeterli değildir" — o yüzden sunucu kapısı önce yazıldı.
 */
export function middleware(request: NextRequest): NextResponse {
  const hasSession = Boolean(request.cookies.get(ACCESS_COOKIE)?.value);

  if (!hasSession) {
    const url = request.nextUrl.clone();
    url.pathname = '/login';
    // Girişten sonra kullanıcıyı istediği sayfaya geri götür.
    url.searchParams.set('next', request.nextUrl.pathname);
    return NextResponse.redirect(url);
  }

  return NextResponse.next();
}

export const config = {
  /**
   * /login ve /api/session HARİÇ her şey korunur — aksi halde giriş sayfasının
   * kendisi de /login'e yönlenip sonsuz döngü olurdu.
   * Statik varlıklar (_next, favicon) da dışarıda: kapıya takılmaları anlamsız.
   */
  matcher: ['/((?!login|api/session|_next/static|_next/image|favicon.ico).*)'],
};
