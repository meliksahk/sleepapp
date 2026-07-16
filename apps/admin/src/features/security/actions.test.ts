import { describe, it, expect, vi, beforeEach } from 'vitest';

const apiPost = vi.fn();
vi.mock('@/shared/api/server-client', () => ({ apiPost }));

const revalidatePath = vi.fn();
vi.mock('next/cache', () => ({ revalidatePath }));

const { startEnrollment, confirmEnrollment } = await import('./actions');

/**
 * 2FA kurulum akışının panel tarafı.
 *
 * En kritik davranış: kurulum BAŞLATMAK 2FA'yı ETKİNLEŞTİRMEZ. Etkinleştirseydi,
 * kodu Authenticator'a girmeden bırakan kullanıcı kendini kalıcı kilitlerdi.
 */
describe('security actions', () => {
  beforeEach(() => {
    apiPost.mockReset();
    revalidatePath.mockReset();
  });

  const formWith = (code: string): FormData => {
    const fd = new FormData();
    fd.set('code', code);
    return fd;
  };

  describe('startEnrollment', () => {
    it('anahtar + QR döner (QR SUNUCUDA üretilir)', async () => {
      apiPost.mockResolvedValue({
        ok: true,
        data: {
          secret: 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ',
          otpauthUri: 'otpauth://totp/NOCTA%3Aa%40b.c?secret=GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ',
        },
      });

      const state = await startEnrollment();

      expect(state.secret).toBe('GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ');
      // Gerçek SVG: qrcode kütüphanesi mock'lanmadı — üretimi de kanıtlanıyor.
      expect(state.qrSvg).toContain('<svg');
      expect(state.error).toBeUndefined();
    });

    it("ÇEKİRDEK: kurulum başlatmak 2FA'yı ETKİNLEŞTİRMEZ (yalnızca enroll çağrılır)", async () => {
      apiPost.mockResolvedValue({ ok: true, data: { secret: 'S', otpauthUri: 'otpauth://x' } });

      await startEnrollment();

      expect(apiPost).toHaveBeenCalledTimes(1);
      expect(apiPost.mock.calls[0]?.[0]).toBe('/v1/auth/admin/totp/enroll');
    });

    it('409 → "zaten etkin" mesajı (üstüne yazma bilerek engelli)', async () => {
      apiPost.mockResolvedValue({ ok: false, status: 409, code: 'totp_already_enabled' });

      const state = await startEnrollment();
      expect(state.error).toContain('zaten etkin');
      expect(state.secret).toBeUndefined();
    });

    it('401 → oturum mesajı; 429 → limit mesajı (ayrı ayrı)', async () => {
      apiPost.mockResolvedValue({ ok: false, status: 401 });
      expect((await startEnrollment()).error).toContain('Oturumunuz');

      apiPost.mockResolvedValue({ ok: false, status: 429 });
      expect((await startEnrollment()).error).toContain('Çok fazla');
    });
  });

  describe('confirmEnrollment', () => {
    it('geçerli kod → etkin + sayfa tazelenir', async () => {
      apiPost.mockResolvedValue({ ok: true, data: undefined });

      const state = await confirmEnrollment({}, formWith('123456'));

      expect(state).toEqual({ enabled: true });
      // Tazelenmezse kullanıcı etkinleştirdiği hâlde "Kapalı" rozetini görürdü.
      expect(revalidatePath).toHaveBeenCalledWith('/security');
    });

    it("biçimsiz kod API'ye HİÇ gitmez", async () => {
      const state = await confirmEnrollment({}, formWith('12'));

      expect(state.error).toContain('6 haneli');
      expect(apiPost).not.toHaveBeenCalled();
    });

    it('sunucu kodu 401\'de "kod hatalı" der — "oturum bitti" DEMEZ', async () => {
      // Uç kimlik doğrulamalı; buraya geçerli oturumla gelinir. 401 = kod tutmadı.
      apiPost.mockResolvedValue({ ok: false, status: 401, code: 'invalid_totp' });

      const state = await confirmEnrollment({}, formWith('000000'));
      expect(state.error).toContain('Kod hatalı');
      expect(state.enabled).toBeUndefined();
    });

    it('başarısız onayda sayfa TAZELENMEZ', async () => {
      apiPost.mockResolvedValue({ ok: false, status: 401, code: 'invalid_totp' });

      await confirmEnrollment({}, formWith('000000'));
      expect(revalidatePath).not.toHaveBeenCalled();
    });

    it("kod boşsa API'ye gitmez (form gönderilmiş olabilir)", async () => {
      const state = await confirmEnrollment({}, new FormData());
      expect(state.error).toContain('6 haneli');
      expect(apiPost).not.toHaveBeenCalled();
    });
  });
});
