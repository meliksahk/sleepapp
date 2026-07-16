import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';

const cookieGet = vi.fn();
vi.mock('next/headers', () => ({
  cookies: async () => ({ get: cookieGet }),
}));

const { apiGet, apiPost, ApiError } = await import('./server-client');

/**
 * Sunucu tarafı API istemcisinin sözleşmesi.
 *
 * 204 testi bir HATA için yazıldı (CLAUDE.md §5: önce failing test): `write()`
 * res.ok olunca KOŞULSUZ `res.json()` çağırıyordu. Gövdesiz 204'te bu SyntaxError
 * atar — yani fonksiyon `WriteResult` dönmek yerine ÇÖKER ve çağıran hiçbir zaman
 * `ok:true` görmez. 2FA onay ucu (`POST /totp/confirm`) tam olarak 204 döner.
 */
describe('server-client', () => {
  const fetchMock = vi.fn();

  beforeEach(() => {
    fetchMock.mockReset();
    cookieGet.mockReset();
    cookieGet.mockReturnValue({ value: 'AT' });
    vi.stubGlobal('fetch', fetchMock);
  });

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it('ÇEKİRDEK: gövdesiz 204 ok:true döner (çökmez)', async () => {
    fetchMock.mockResolvedValue(new Response(null, { status: 204 }));

    const res = await apiPost('/v1/auth/admin/totp/confirm', { code: '123456' });

    expect(res.ok).toBe(true);
  });

  it('gövdeli 200 veriyi taşır', async () => {
    fetchMock.mockResolvedValue(
      new Response(JSON.stringify({ secret: 'ABC' }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      }),
    );

    const res = await apiPost<{ secret: string }>('/x', {});
    expect(res).toEqual({ ok: true, data: { secret: 'ABC' } });
  });

  it('hata gövdesindeki code taşınır', async () => {
    fetchMock.mockResolvedValue(
      new Response(JSON.stringify({ code: 'totp_already_enabled' }), { status: 409 }),
    );

    const res = await apiPost('/x', {});
    expect(res).toEqual({ ok: false, status: 409, code: 'totp_already_enabled' });
  });

  it("token çerezden okunur ve header'a konur", async () => {
    fetchMock.mockResolvedValue(new Response(null, { status: 204 }));
    await apiPost('/x', {});
    expect(fetchMock.mock.calls[0]?.[1]?.headers).toMatchObject({ Authorization: 'Bearer AT' });
  });

  it("apiGet 401'de ApiError fırlatır (sayfa render edilemez)", async () => {
    fetchMock.mockResolvedValue(new Response('{}', { status: 401 }));
    await expect(apiGet('/x')).rejects.toBeInstanceOf(ApiError);
  });
});
