import { describe, expect, it, vi, beforeEach, afterEach } from 'vitest';
import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { LoginForm } from './LoginForm';

const push = vi.fn();
vi.mock('next/navigation', () => ({
  useRouter: () => ({ push, refresh: vi.fn() }),
}));

/**
 * Giriş formunun 2FA davranışı.
 *
 * NEDEN: 401'in İKİ anlamı var — "parola yanlış" ve "2FA kodu gerekli". Form bunları
 * ayırmazsa, parolası DOĞRU olan kullanıcıya "parola hatalı" der ve kod alanını hiç
 * göstermez: 2FA'lı hesap panele HİÇ giremez. Bu, sessiz bir kilitlenmedir.
 */
describe('LoginForm — 2FA', () => {
  const jsonResponse = (status: number, body: unknown): Response =>
    new Response(JSON.stringify(body), {
      status,
      headers: { 'Content-Type': 'application/json' },
    });

  const fetchMock = vi.fn();

  beforeEach(() => {
    fetchMock.mockReset();
    push.mockReset();
    vi.stubGlobal('fetch', fetchMock);
  });

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  /**
   * `fireEvent` (user-event değil): user-event yeni bir bağımlılık isterdi ve
   * buradaki sorular ("alan açıldı mı", "gövdede ne gitti") için tuş-tuş simülasyona
   * ihtiyaç yok — testing-library/react zaten kurulu.
   */
  const type = (label: string, value: string): void => {
    fireEvent.change(screen.getByLabelText(label), { target: { value } });
  };

  const fillCredentials = (): void => {
    type('E-posta', 'owner@nocta.test');
    type('Parola', 'correct-horse-battery');
  };

  const submit = (): void => {
    fireEvent.click(screen.getByRole('button', { name: 'Giriş yap' }));
  };

  /** N. fetch çağrısının gövdesi. Çağrı yoksa PATLAR: sessizce undefined dönüp
   *  "beklenti tutmadı" yerine anlamsız bir hata vermek testi okunmaz kılardı. */
  const sentBody = (call: number): Record<string, unknown> => {
    const args = fetchMock.mock.calls[call];
    if (!args) throw new Error(`fetch ${call}. kez çağrılmadı`);
    return JSON.parse((args[1] as { body: string }).body);
  };

  it('kod alanı BAŞTA gizli (2FA olmayan kullanıcıya dolduramayacağı alan gösterilmez)', () => {
    render(<LoginForm next="/" />);
    expect(screen.queryByLabelText('Doğrulama kodu')).toBeNull();
  });

  it('ÇEKİRDEK: totp_required gelince kod alanı AÇILIR ve mesaj kodu ister', async () => {
    fetchMock.mockResolvedValueOnce(
      jsonResponse(401, { error: 'login_failed', code: 'totp_required' }),
    );
    render(<LoginForm next="/" />);
    fillCredentials();
    submit();

    expect(await screen.findByLabelText('Doğrulama kodu')).toBeTruthy();
    // "Parola hatalı" demek kullanıcıyı yanlış yere bakmaya gönderirdi.
    expect(screen.getByRole('alert').textContent).toContain('6 haneli kodu girin');
    expect(push).not.toHaveBeenCalled();
  });

  it('kodla ikinci deneme başarılıysa yönlendirir', async () => {
    fetchMock
      .mockResolvedValueOnce(jsonResponse(401, { error: 'login_failed', code: 'totp_required' }))
      .mockResolvedValueOnce(jsonResponse(200, { ok: true }));

    render(<LoginForm next="/panel" />);
    fillCredentials();
    submit();

    await screen.findByLabelText('Doğrulama kodu');
    type('Doğrulama kodu', '123456');
    submit();

    await waitFor(() => expect(push).toHaveBeenCalledWith('/panel'));
    expect(sentBody(1).totpCode).toBe('123456');
  });

  it('kod BOŞKEN gövdeye konmaz (boş string 400 alırdı)', async () => {
    fetchMock.mockResolvedValueOnce(jsonResponse(200, { ok: true }));
    render(<LoginForm next="/" />);
    fillCredentials();
    submit();

    await waitFor(() => expect(fetchMock).toHaveBeenCalled());
    expect(sentBody(0)).not.toHaveProperty('totpCode');
  });

  it('yanlış kodda alan AÇIK kalır ve yanan kod TEMİZLENİR', async () => {
    fetchMock
      .mockResolvedValueOnce(jsonResponse(401, { error: 'login_failed', code: 'totp_required' }))
      .mockResolvedValueOnce(jsonResponse(401, { error: 'login_failed', code: 'invalid_totp' }));

    render(<LoginForm next="/" />);
    fillCredentials();
    submit();
    await screen.findByLabelText('Doğrulama kodu');
    type('Doğrulama kodu', '000000');
    submit();

    const field = await screen.findByLabelText('Doğrulama kodu');
    // Aynı kod ikinci kez zaten kabul edilmez (RFC 6238 §5.2); ekranda bırakmak
    // kullanıcıyı yanan kodu tekrar göndermeye davet ederdi.
    await waitFor(() => expect((field as HTMLInputElement).value).toBe(''));
    expect(screen.getByRole('alert').textContent).toContain('Kod hatalı');
  });

  it('parola yanlışsa kod alanı AÇILMAZ (yanlış yere bakmasın)', async () => {
    fetchMock.mockResolvedValueOnce(
      jsonResponse(401, { error: 'login_failed', code: 'invalid_credentials' }),
    );
    render(<LoginForm next="/" />);
    fillCredentials();
    submit();

    expect(await screen.findByRole('alert')).toBeTruthy();
    expect(screen.getByRole('alert').textContent).toContain('E-posta veya parola hatalı');
    expect(screen.queryByLabelText('Doğrulama kodu')).toBeNull();
  });

  it('429 mesajı 2FA mesajına KARIŞMAZ', async () => {
    fetchMock.mockResolvedValueOnce(jsonResponse(429, { error: 'login_failed', code: null }));
    render(<LoginForm next="/" />);
    fillCredentials();
    submit();

    expect((await screen.findByRole('alert')).textContent).toContain('Çok fazla deneme');
  });

  it('sayı olmayan karakterler kod alanına girmez', async () => {
    fetchMock.mockResolvedValueOnce(
      jsonResponse(401, { error: 'login_failed', code: 'totp_required' }),
    );
    render(<LoginForm next="/" />);
    fillCredentials();
    submit();

    const field = (await screen.findByLabelText('Doğrulama kodu')) as HTMLInputElement;
    type('Doğrulama kodu', '12ab34');
    expect(field.value).toBe('1234');
  });

  it('bozuk gövde çökmez, genel mesaja düşer', async () => {
    fetchMock.mockResolvedValueOnce(new Response('<html>502</html>', { status: 502 }));
    render(<LoginForm next="/" />);
    fillCredentials();
    submit();

    expect((await screen.findByRole('alert')).textContent).toContain('Giriş yapılamadı');
  });
});
