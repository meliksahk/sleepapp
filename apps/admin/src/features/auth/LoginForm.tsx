'use client';

import { useState, type FormEvent } from 'react';
import { useRouter } from 'next/navigation';
import { Button, Input } from '@nocta/ui';
import type { MessageKey } from '@/shared/i18n/dictionaries';
import { useT } from '@/shared/i18n/I18nProvider';

/** API'nin durum + hata kodunu kullanıcının anlayacağı tek cümleye çevirir. */
function messageFor(status: number, code: string | null): MessageKey {
  // 429 ile 401'i AYIRMAK önemli: ikisini birleştirmek, limite takılan kullanıcıyı
  // "parolam yanlış" sanıp denemeye devam ettirir — ve limit hiç açılmaz.
  if (status === 429) return 'login.errorRate' as const;
  // 401'in iki anlamı var; "parola hatalı" demek, parolası DOĞRU olan kullanıcıyı
  // yanlış yere bakmaya gönderirdi.
  if (code === 'totp_required') return 'login.errorTotpRequired' as const;
  if (code === 'invalid_totp') return 'login.errorTotpInvalid' as const;
  if (status === 401) return 'login.errorCredentials' as const;
  return 'login.errorGeneric' as const;
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
  const t = useT();
  const router = useRouter();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [totpCode, setTotpCode] = useState('');
  // Hata artık MESAJ ANAHTARI tutar (dizge değil): dil değişince mesaj da değişsin.
  const [error, setError] = useState<MessageKey | null>(null);
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
      setError('login.errorUnreachable');
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
          {t(error)}
        </p>
      )}
      <Button type="submit" disabled={busy}>
        {busy ? t('login.submitting') : t('login.submit')}
      </Button>
    </form>
  );
}
