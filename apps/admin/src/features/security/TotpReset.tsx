'use client';

import { useActionState } from 'react';
import { Button, Input } from '@nocta/ui';
import { useT } from '@/shared/i18n/I18nProvider';
import { resetTotp, type ResetState } from './actions';

const INITIAL: ResetState = {};

/**
 * 2FA sıfırlama (cihaz rotasyonu, #186). Yeni telefona geçen kullanıcı parolasıyla
 * mevcut 2FA'yı kaldırır, sonra baştan kurar. Parola alanı: doğrulama sunucuda ama
 * kullanıcı ne yaptığını bilerek yapsın diye burada da istenir.
 */
export function TotpReset() {
  const t = useT();
  const [state, action, pending] = useActionState(resetTotp, INITIAL);

  if (state.done === true) {
    return (
      <p role="status" className="text-body text-accent-sage">
        {t('security.resetDone')}
      </p>
    );
  }

  return (
    <form action={action} className="flex flex-col gap-3">
      <p className="text-caption text-ink-muted">{t('security.resetHint')}</p>
      <Input
        name="password"
        type="password"
        label={t('common.password')}
        autoComplete="current-password"
        required
      />
      {state.error !== undefined && (
        <p role="alert" className="text-body text-accent-ember">
          {t(state.error)}
        </p>
      )}
      <Button type="submit" disabled={pending}>
        {pending ? t('security.resetting') : t('security.resetSubmit')}
      </Button>
    </form>
  );
}
