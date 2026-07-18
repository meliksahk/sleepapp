'use client';

import { useActionState } from 'react';
import { Button, Input } from '@nocta/ui';
import { resetTotp, type ResetState } from './actions';

const INITIAL: ResetState = {};

/**
 * 2FA sıfırlama (cihaz rotasyonu, #186). Yeni telefona geçen kullanıcı parolasıyla
 * mevcut 2FA'yı kaldırır, sonra baştan kurar. Parola alanı: doğrulama sunucuda ama
 * kullanıcı ne yaptığını bilerek yapsın diye burada da istenir.
 */
export function TotpReset() {
  const [state, action, pending] = useActionState(resetTotp, INITIAL);

  if (state.done === true) {
    return (
      <p role="status" className="text-body text-accent-sage">
        İki adımlı doğrulama sıfırlandı. Sayfayı yenileyip yeni cihazınızda yeniden kurabilirsiniz.
      </p>
    );
  }

  return (
    <form action={action} className="flex flex-col gap-3">
      <p className="text-caption text-ink-muted">
        Yeni bir cihaza geçmek için parolanızla sıfırlayın; ardından baştan kurabilirsiniz.
      </p>
      <Input
        name="password"
        type="password"
        label="Parola"
        autoComplete="current-password"
        required
      />
      {state.error !== undefined && (
        <p role="alert" className="text-body text-accent-ember">
          {state.error}
        </p>
      )}
      <Button type="submit" disabled={pending}>
        {pending ? 'Sıfırlanıyor…' : 'İki adımlı doğrulamayı sıfırla'}
      </Button>
    </form>
  );
}
