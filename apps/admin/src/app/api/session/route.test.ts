import { describe, it, expect, vi, afterEach } from 'vitest';
import { POST, DELETE } from './route';
import { ACCESS_COOKIE, REFRESH_COOKIE } from '@/shared/auth/session';

/**
 * Giriş vekilinin çekirdek sözleşmesi: token'lar httpOnly ÇEREZE yazılır ve
 * yanıt GÖVDESİNDE dönmez. Gövdede dönselerdi, `fetch` sonucunu okuyan herhangi
 * bir JS (ve dolayısıyla XSS) admin token'ını ele geçirirdi — httpOnly çerezin
 * tüm anlamı kaybolurdu.
 */
const loginRequest = (body: unknown = { email: 'a@b.c', password: 'password-1234' }): Request =>
  new Request('http://localhost:3002/api/session', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });

const apiSession = {
  accessToken: 'ACCESS-TOKEN-SECRET',
  refreshToken: 'REFRESH-TOKEN-SECRET',
  accessTokenExpiresIn: 900,
  userId: 'u1',
};

afterEach(() => {
  vi.unstubAllGlobals();
});

describe('POST /api/session', () => {
  it('başarılı girişte token GÖVDEDE dönmez, çerezlere yazılır', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue(new Response(JSON.stringify(apiSession), { status: 200 })),
    );

    const res = await POST(loginRequest());
    expect(res.status).toBe(200);

    const text = await res.clone().text();
    expect(text).not.toContain('ACCESS-TOKEN-SECRET');
    expect(text).not.toContain('REFRESH-TOKEN-SECRET');

    expect(res.cookies.get(ACCESS_COOKIE)?.value).toBe('ACCESS-TOKEN-SECRET');
    expect(res.cookies.get(REFRESH_COOKIE)?.value).toBe('REFRESH-TOKEN-SECRET');
    expect(res.cookies.get(ACCESS_COOKIE)?.httpOnly).toBe(true);
  });

  it('401 aynen yansıtılır ve çerez YAZILMAZ', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(new Response('{}', { status: 401 })));

    const res = await POST(loginRequest());
    expect(res.status).toBe(401);
    expect(res.cookies.get(ACCESS_COOKIE)).toBeUndefined();
  });

  it('429 401\'e ÇEVRİLMEZ — kullanıcı "parolam yanlış" sanıp denemeye devam etmesin', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(new Response('{}', { status: 429 })));

    const res = await POST(loginRequest());
    expect(res.status).toBe(429);
  });

  it("bozuk gövde → 400 (API'ye hiç gidilmez)", async () => {
    const fetchMock = vi.fn();
    vi.stubGlobal('fetch', fetchMock);

    const bad = new Request('http://localhost:3002/api/session', {
      method: 'POST',
      body: 'bu json degil',
    });
    const res = await POST(bad);
    expect(res.status).toBe(400);
    expect(fetchMock).not.toHaveBeenCalled();
  });
});

const logoutRequest = (cookie?: string): Request =>
  new Request('http://localhost:3002/api/session', {
    method: 'DELETE',
    headers: cookie === undefined ? {} : { cookie },
  });

describe('DELETE /api/session', () => {
  it('SUNUCUDAKİ oturumu iptal eder — çerezi silmek tek başına yalan olurdu', async () => {
    const fetchMock = vi.fn().mockResolvedValue(new Response(null, { status: 204 }));
    vi.stubGlobal('fetch', fetchMock);

    await DELETE(logoutRequest(`${REFRESH_COOKIE}=RT-DEGERI`));

    expect(fetchMock).toHaveBeenCalledOnce();
    const call = fetchMock.mock.calls[0];
    expect(String(call?.[0])).toContain('/v1/auth/logout');
    expect(JSON.parse(String(call?.[1]?.body))).toEqual({ refreshToken: 'RT-DEGERI' });
  });

  it('çıkışta iki çerez de boşaltılır', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(new Response(null, { status: 204 })));

    const res = await DELETE(logoutRequest(`${REFRESH_COOKIE}=RT-DEGERI`));
    expect(res.cookies.get(ACCESS_COOKIE)?.value).toBe('');
    expect(res.cookies.get(REFRESH_COOKIE)?.value).toBe('');
  });

  it('API ulaşılamasa BİLE çerezler silinir — "çık" diyen kullanıcı açık oturumla kalmasın', async () => {
    vi.stubGlobal('fetch', vi.fn().mockRejectedValue(new Error('ECONNREFUSED')));

    const res = await DELETE(logoutRequest(`${REFRESH_COOKIE}=RT-DEGERI`));
    expect(res.status).toBe(200);
    expect(res.cookies.get(REFRESH_COOKIE)?.value).toBe('');
  });

  it('refresh çerezi yoksa API çağrılmaz ama çerezler yine temizlenir', async () => {
    const fetchMock = vi.fn();
    vi.stubGlobal('fetch', fetchMock);

    const res = await DELETE(logoutRequest());
    expect(fetchMock).not.toHaveBeenCalled();
    expect(res.cookies.get(ACCESS_COOKIE)?.value).toBe('');
  });

  it('birden çok çerez arasından doğru olanı ayıklar', async () => {
    const fetchMock = vi.fn().mockResolvedValue(new Response(null, { status: 204 }));
    vi.stubGlobal('fetch', fetchMock);

    await DELETE(logoutRequest(`other=x; ${REFRESH_COOKIE}=DOGRU-RT; ${ACCESS_COOKIE}=AT`));
    expect(JSON.parse(String(fetchMock.mock.calls[0]?.[1]?.body))).toEqual({
      refreshToken: 'DOGRU-RT',
    });
  });
});
