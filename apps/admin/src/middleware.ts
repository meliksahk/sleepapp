import { NextResponse, type NextRequest } from 'next/server';
import { API_BASE } from '@/shared/api/config';
import { ACCESS_COOKIE, REFRESH_COOKIE, cookieOptions } from '@/features/auth/session';

/** Refresh token ömrü — /api/session ile aynı (30 gün). */
const REFRESH_MAX_AGE = 60 * 60 * 24 * 30;

/**
 * Access çerezi tarayıcıda token'ın kendi ömrüyle (15dk) sona erer. Bu yüzden
 * "access çerezi yok ama refresh çerezi var" = oturum yenilenmeli demektir;
 * ayrıca süre hesabı tutmaya gerek yok, tarayıcı bunu bizim için yapıyor.
 */
type RefreshResult =
  | { kind: 'ok'; accessToken: string; refreshToken: string; accessTokenExpiresIn: number }
  /** Sunucu token'ı REDDETTİ (süre doldu / iptal / reuse) → oturum gerçekten bitti. */
  | { kind: 'rejected' }
  /** API'ye ULAŞILAMADI → token hakkında hiçbir şey öğrenmedik. */
  | { kind: 'unreachable' };

/**
 * İkisini AYIRMAK şart: "reddedildi" çerezleri silmeyi gerektirir, "ulaşılamadı"
 * ise KESİNLİKLE gerektirmez — geçici bir ağ kesintisi kullanıcının 30 günlük
 * oturumunu yok etmemeli. Tek bir `null` dönseydi bu ayrım kaybolurdu (ve nitekim
 * ilk yazımda kaybolmuştu; test yakaladı).
 */
async function refreshSession(refreshToken: string): Promise<RefreshResult> {
  let res: Response;
  try {
    res = await fetch(`${API_BASE}/v1/auth/refresh`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ refreshToken }),
      cache: 'no-store',
    });
  } catch {
    return { kind: 'unreachable' };
  }
  if (!res.ok) return { kind: 'rejected' };
  try {
    const body = await res.json();
    return { kind: 'ok', ...body };
  } catch {
    // 200 ama gövde bozuk: sunucu sorunu, token'ı suçlayamayız.
    return { kind: 'unreachable' };
  }
}

function redirectToLogin(request: NextRequest, clearCookies: boolean): NextResponse {
  const url = request.nextUrl.clone();
  url.pathname = '/login';
  url.searchParams.set('next', request.nextUrl.pathname);
  const res = NextResponse.redirect(url);
  if (clearCookies) {
    res.cookies.set(ACCESS_COOKIE, '', cookieOptions(0));
    res.cookies.set(REFRESH_COOKIE, '', cookieOptions(0));
  }
  return res;
}

/**
 * Panel kapısı (docs/03 A0): oturumu sessizce yeniler, yenileyemezse /login'e atar.
 *
 * DİKKAT — BU BİR YETKİ KONTROLÜ DEĞİLDİR: access çerezi varsa token doğrulanmadan
 * geçilir (Edge'de RS256 doğrulaması + anahtar dağıtımı ayrı iş). Gerçek kapı
 * SUNUCUDADIR: her admin ucu AuthGuard + RolesGuard + aud='admin' ister (#112/#113).
 * Buradaki kontrol UX'tir — geçersiz çerezle gelen sayfayı görür ama veri ÇEKEMEZ.
 * CLAUDE.md §3.3: "yalnızca UI gizleme yeterli değildir" → sunucu kapısı ÖNCE yazıldı.
 */
export async function middleware(request: NextRequest): Promise<NextResponse> {
  if (request.cookies.get(ACCESS_COOKIE)?.value) {
    return NextResponse.next();
  }

  const refreshToken = request.cookies.get(REFRESH_COOKIE)?.value;
  if (!refreshToken) {
    return redirectToLogin(request, false);
  }

  /**
   * YALNIZCA SAYFA GEZİNTİSİNDE yenile — YARIŞ KORUMASI.
   *
   * Refresh token ROTASYONLU ve yeniden kullanım tespitlidir: aynı token'la iki
   * EŞZAMANLI yenileme, API'de "çalıntı token" sayılır ve TÜM AİLEYİ düşürür
   * (refresh-session.usecase.ts) → kullanıcı sert biçimde atılır. Prefetch/RSC
   * istekleri paralel akar; hepsinde yenilemeye kalkmak bu yarışı davet ederdi.
   * Gezinti istekleri seri olduğu için risk küçülür.
   *
   * KALAN RİSK (çözülmedi, defterde): iki sekme aynı anda gezinirse yarış hâlâ
   * mümkün. Gerçek çözüm API tarafında kısa "grace window" veya tek-uçuş kilidi.
   */
  if (request.headers.get('sec-fetch-mode') !== 'navigate') {
    return redirectToLogin(request, false);
  }

  const session = await refreshSession(refreshToken);
  if (session.kind === 'rejected') {
    // Token gerçekten ölü → çerezleri temizle; yoksa kullanıcı her istekte ölü
    // token'la yenilemeyi yeniden dener.
    return redirectToLogin(request, true);
  }
  if (session.kind === 'unreachable') {
    // Çerezlere DOKUNMA: API dönünce oturum kaldığı yerden sürer.
    return redirectToLogin(request, false);
  }

  const res = NextResponse.next();
  res.cookies.set(ACCESS_COOKIE, session.accessToken, cookieOptions(session.accessTokenExpiresIn));
  res.cookies.set(REFRESH_COOKIE, session.refreshToken, cookieOptions(REFRESH_MAX_AGE));
  return res;
}

export const config = {
  /**
   * /login ve /api/session HARİÇ her şey korunur — aksi halde giriş sayfasının
   * kendisi de /login'e yönlenip sonsuz döngü olurdu.
   * Statik varlıklar (_next, favicon) da dışarıda: kapıya takılmaları anlamsız.
   */
  matcher: ['/((?!login|api/session|_next/static|_next/image|favicon.ico).*)'],
};
