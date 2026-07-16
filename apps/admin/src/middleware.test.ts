import { describe, it, expect } from 'vitest';
import { NextRequest } from 'next/server';
import { middleware, config } from './middleware';
import { ACCESS_COOKIE } from '@/features/auth/session';

const req = (path: string, withCookie = false): NextRequest => {
  const r = new NextRequest(new URL(`http://localhost:3002${path}`));
  if (withCookie) r.cookies.set(ACCESS_COOKIE, 'token-value');
  return r;
};

/** matcher'ın bir yolu koruyup korumadığını, regex'i AYNEN uygulayarak ölçer. */
const isProtected = (path: string): boolean =>
  config.matcher.some((m) => new RegExp(`^${m}$`).test(path));

describe('panel kapısı (middleware)', () => {
  it("çerez yoksa /login'e yönlendirir", () => {
    const res = middleware(req('/'));
    expect(res.status).toBe(307);
    expect(res.headers.get('location')).toContain('/login');
  });

  it('kullanıcıyı istediği sayfaya geri götürmek için ?next taşır', () => {
    const res = middleware(req('/content'));
    expect(res.headers.get('location')).toContain('next=%2Fcontent');
  });

  it('çerez varsa geçirir', () => {
    const res = middleware(req('/', true));
    expect(res.status).toBe(200);
    expect(res.headers.get('location')).toBeNull();
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
