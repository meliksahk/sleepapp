'use client';

import { useState, type FormEvent } from 'react';
import { useRouter } from 'next/navigation';
import { Button, Input } from '@nocta/ui';

/** API'nin durum + hata kodunu kullanıcının anlayacağı tek cümleye çevirir. */
function messageFor(status: number, code: string | null): string {
  // 429 ile 401'i AYIRMAK önemli: ikisini birleştirmek, limite takılan kullanıcıyı
  // "parolam yanlış" sanıp denemeye devam ettirir — ve limit hiç açılmaz.
  if (status === 429) return 'Çok fazla deneme yapıldı. Bir dakika bekleyip tekrar deneyin.';
  // 401'in iki anlamı var; "parola hatalı" demek, parolası DOĞRU olan kullanıcıyı
  // yanlış yere bakmaya gönderirdi.
  if (code === 'totp_required') return 'Doğrulama uygulamanızdaki 6 haneli kodu girin.';
  if (code === 'invalid_totp') return 'Kod hatalı veya süresi doldu. Yeni kodu deneyin.';
  if (status === 401) return 'E-posta veya parola hatalı.';
  return 'Giriş yapılamadı. Lütfen tekrar deneyin.';
}

/** Vekilin ilettiği hata kodu; gövde bozuksa null (çağıran genel mesaja düşer). */
async function codeFrom(res: Response): Promise<string | null> {
  try {
    const body: unknown = await res.json();
    if (typeof body === 'object' && body !== null && 'code' in body) {
      const { code } = body as { code: unknown };
      return typeof code === 'string' ? code : null;
    }
  } catch {
    // Gövde okunamadı — kod bilinmiyor.
  }
  return null;
}

/** Panel giriş formu (docs/03 A0). Token'a DOKUNMAZ: /api/session httpOnly çerez yazar. */
export function LoginForm({ next }: { next: string }) {
  const router = useRouter();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [totpCode, setTotpCode] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  /**
   * Kod alanı YALNIZCA API istediğinde açılır. Herkese baştan göstermek, 2FA'sı
   * olmayan kullanıcıya dolduramayacağı bir alan sunardı; gizli tutmak ise 2FA'lı
   * kullanıcıyı çıkmaza sokardı. Bu yüzden karar sunucunun: totp_required gelince.
   */
  const [totpNeeded, setTotpNeeded] = useState(false);

  async function onSubmit(e: FormEvent<HTMLFormElement>): Promise<void> {
    e.preventDefault();
    if (busy) return;
    setBusy(true);
    setError(null);
    try {
      const res = await fetch('/api/session', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        // Kod yalnızca girildiyse gönderilir: boş string 400 (biçim) alırdı.
        body: JSON.stringify({ email, password, ...(totpCode ? { totpCode } : {}) }),
      });
      if (!res.ok) {
        const code = await codeFrom(res);
        if (code === 'totp_required' || code === 'invalid_totp') {
          setTotpNeeded(true);
          // Yanan kod temizlenir: aynı kod ikinci kez zaten kabul edilmez
          // (RFC 6238 §5.2) — kullanıcı eskisini yeniden gönderip takılmasın.
          setTotpCode('');
        }
        setError(messageFor(res.status, code));
        return;
      }
      router.push(next);
      router.refresh();
    } catch {
      setError('Sunucuya ulaşılamadı.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <form onSubmit={onSubmit} className="flex w-full max-w-sm flex-col gap-4">
      <Input
        label="E-posta"
        type="email"
        autoComplete="username"
        required
        value={email}
        onChange={(e) => setEmail(e.target.value)}
      />
      <Input
        label="Parola"
        type="password"
        autoComplete="current-password"
        required
        value={password}
        onChange={(e) => setPassword(e.target.value)}
      />
      {totpNeeded && (
        <Input
          label="Doğrulama kodu"
          // inputMode=numeric: mobilde sayı tuş takımı açılır. autoComplete
          // one-time-code: iOS/Android kodu klavyeden önerir.
          inputMode="numeric"
          autoComplete="one-time-code"
          pattern="[0-9]{6}"
          maxLength={6}
          required
          autoFocus
          value={totpCode}
          onChange={(e) => setTotpCode(e.target.value.replace(/\D/g, ''))}
        />
      )}
      {error !== null && (
        <p role="alert" className="text-body text-accent-ember">
          {error}
        </p>
      )}
      <Button type="submit" disabled={busy}>
        {busy ? 'Giriş yapılıyor…' : 'Giriş yap'}
      </Button>
    </form>
  );
}
