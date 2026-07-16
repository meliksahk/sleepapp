'use client';

import { useState, type FormEvent } from 'react';
import { useRouter } from 'next/navigation';
import { Button, Input } from '@nocta/ui';

/** API'nin durum kodunu kullanıcının anlayacağı tek cümleye çevirir. */
function messageFor(status: number): string {
  // 429 ile 401'i AYIRMAK önemli: ikisini birleştirmek, limite takılan kullanıcıyı
  // "parolam yanlış" sanıp denemeye devam ettirir — ve limit hiç açılmaz.
  if (status === 429) return 'Çok fazla deneme yapıldı. Bir dakika bekleyip tekrar deneyin.';
  if (status === 401) return 'E-posta veya parola hatalı.';
  return 'Giriş yapılamadı. Lütfen tekrar deneyin.';
}

/** Panel giriş formu (docs/03 A0). Token'a DOKUNMAZ: /api/session httpOnly çerez yazar. */
export function LoginForm({ next }: { next: string }) {
  const router = useRouter();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function onSubmit(e: FormEvent<HTMLFormElement>): Promise<void> {
    e.preventDefault();
    if (busy) return;
    setBusy(true);
    setError(null);
    try {
      const res = await fetch('/api/session', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password }),
      });
      if (!res.ok) {
        setError(messageFor(res.status));
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
