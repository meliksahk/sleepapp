import { describe, it, expect, afterEach, vi } from 'vitest';
import { cookieOptions } from './session';

describe('oturum çerezi ayarları', () => {
  afterEach(() => {
    vi.unstubAllEnvs();
  });

  it("token çerezi JS'ten okunamaz (httpOnly) — XSS admin anahtarını çalamasın", () => {
    expect(cookieOptions(60).httpOnly).toBe(true);
  });

  it("production'da secure", () => {
    vi.stubEnv('NODE_ENV', 'production');
    expect(cookieOptions(60).secure).toBe(true);
  });

  it("development'ta secure DEĞİL — aksi halde http://localhost'ta çerez hiç yazılmaz", () => {
    vi.stubEnv('NODE_ENV', 'development');
    expect(cookieOptions(60).secure).toBe(false);
  });

  it('sameSite lax — strict, giriş sonrası ilk yönlendirmede döngü üretebilir', () => {
    expect(cookieOptions(60).sameSite).toBe('lax');
  });

  it('maxAge 0 (çıkış) çerezi anında geçersiz kılar', () => {
    expect(cookieOptions(0).maxAge).toBe(0);
  });
});
