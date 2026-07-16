import { describe, it, expect, vi, afterEach } from 'vitest';
import { NextRequest } from 'next/server';
import { middleware, config } from './middleware';
import { ACCESS_COOKIE, REFRESH_COOKIE } from '@/shared/auth/session';

type Cookies = { access?: string; refresh?: string };

/** `navigate` varsayılan: gerçek sayfa gezintisi budur; yenileme yalnızca orada olur. */
const req = (path: string, cookies: Cookies = {}, mode = 'navigate'): NextRequest => {
  const r = new NextRequest(new URL(`http://localhost:3002${path}`), {
    headers: { 'sec-fetch-mode': mode },
  });
  if (cookies.access) r.cookies.set(ACCESS_COOKIE, cookies.access);
  if (cookies.refresh) r.cookies.set(REFRESH_COOKIE, cookies.refresh);
  return r;
};

const apiSession = {
  accessToken: 'YENI-ACCESS',
  refreshToken: 'YENI-REFRESH',
  accessTokenExpiresIn: 900,
};

/** matcher'ın bir yolu koruyup korumadığını, regex'i AYNEN uygulayarak ölçer. */
const isProtected = (path: string): boolean =>
  config.matcher.some((m) => new RegExp(`^${m}$`).test(path));

afterEach(() => {
  vi.unstubAllGlobals();
});

describe('panel kapısı (middleware)', () => {
  it("hiç çerez yoksa /login'e yönlendirir", async () => {
    const res = await middleware(req('/'));
    expect(res.status).toBe(307);
    expect(res.headers.get('location')).toContain('/login');
  });

  it('kullanıcıyı istediği sayfaya geri götürmek için ?next taşır', async () => {
    const res = await middleware(req('/content'));
    expect(res.headers.get('location')).toContain('next=%2Fcontent');
  });

  it('geçerli access çerezi varsa geçirir (yenilemeye kalkışmaz)', async () => {
    const fetchMock = vi.fn();
    vi.stubGlobal('fetch', fetchMock);

    const res = await middleware(req('/', { access: 'token' }));
    expect(res.status).toBe(200);
    expect(fetchMock).not.toHaveBeenCalled();
  });

  describe('oturum yenileme', () => {
    it('access süresi dolmuş + refresh var → SESSİZCE yeniler ve geçirir', async () => {
      vi.stubGlobal(
        'fetch',
        vi.fn().mockResolvedValue(new Response(JSON.stringify(apiSession), { status: 200 })),
      );

      const res = await middleware(req('/', { refresh: 'RT' }));
      expect(res.status).toBe(200);
      expect(res.headers.get('location')).toBeNull();
      expect(res.cookies.get(ACCESS_COOKIE)?.value).toBe('YENI-ACCESS');
      // Rotasyon: API yeni refresh döndürür, onu da yazmalıyız — yoksa bir sonraki
      // yenileme ESKİ token'la denenir, reuse sayılır ve aile düşerdi.
      expect(res.cookies.get(REFRESH_COOKIE)?.value).toBe('YENI-REFRESH');
    });

    it('YARIŞ KORUMASI: gezinti olmayan istekte (prefetch/RSC) yenilemez', async () => {
      // Rotasyonlu token ile paralel yenileme = reuse → API TÜM AİLEYİ düşürür.
      const fetchMock = vi.fn();
      vi.stubGlobal('fetch', fetchMock);

      const res = await middleware(req('/', { refresh: 'RT' }, 'cors'));
      expect(fetchMock).not.toHaveBeenCalled();
      expect(res.status).toBe(307);
    });

    it("refresh reddedildi (401) → çerezler TEMİZLENİR, login'e", async () => {
      vi.stubGlobal('fetch', vi.fn().mockResolvedValue(new Response('{}', { status: 401 })));

      const res = await middleware(req('/', { refresh: 'olu-token' }));
      expect(res.status).toBe(307);
      // Temizlenmezse kullanıcı her istekte ölü token'la yenilemeyi yeniden dener.
      expect(res.cookies.get(REFRESH_COOKIE)?.value).toBe('');
    });

    it('API ulaşılamıyor → çerezleri SİLMEZ (geçici kesinti oturumu yok etmemeli)', async () => {
      vi.stubGlobal('fetch', vi.fn().mockRejectedValue(new Error('ECONNREFUSED')));

      const res = await middleware(req('/', { refresh: 'RT' }));
      expect(res.status).toBe(307);
      expect(res.cookies.get(REFRESH_COOKIE)).toBeUndefined();
    });
  });

  describe('matcher', () => {
    it('/login KORUNMAZ — aksi halde giriş sayfası kendine yönlenip sonsuz döngü olurdu', () => {
      expect(isProtected('/login')).toBe(false);
    });

    it('/api/session KORUNMAZ — giriş isteğinin kendisi kapıya takılamaz', () => {
      expect(isProtected('/api/session')).toBe(false);
    });

    it('statik varlıklar korunmaz', () => {
      expect(isProtected('/_next/static/chunk.js')).toBe(false);
      expect(isProtected('/favicon.ico')).toBe(false);
    });

    it('panel sayfaları korunur', () => {
      expect(isProtected('/')).toBe(true);
      expect(isProtected('/content')).toBe(true);
      expect(isProtected('/users/42')).toBe(true);
    });
  });
});
