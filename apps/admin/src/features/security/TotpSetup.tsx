'use client';

import { useActionState, useState, useTransition } from 'react';
import { Button, Input } from '@nocta/ui';
import { useT } from '@/shared/i18n/I18nProvider';
import { confirmEnrollment, startEnrollment, type EnrollState } from './actions';

/**
 * 2FA kurulum akışı (docs/03 A0).
 *
 * NEDEN İKİ ADIM (kur → onayla): anahtar üretilir üretilmez 2FA'yı açsaydık, kodu
 * Authenticator'a girmeden (ya da yanlış girip) bırakan kullanıcı KENDİNİ KALICI
 * OLARAK KİLİTLERDİ — parolası doğru, ama asla üretemeyeceği bir kod isteniyor.
 * Geçerli kod, "üretebiliyorum" kanıtıdır.
 */
export function TotpSetup() {
  const t = useT();
  const [enroll, setEnroll] = useState<EnrollState>({});
  const [starting, startTransition] = useTransition();
  const [confirm, confirmAction, confirming] = useActionState(confirmEnrollment, {});

  function begin(): void {
    // QR ve anahtar tek çağrıda gelir — SVG'yi sunucu üretir.
    startTransition(async () => setEnroll(await startEnrollment()));
  }

  if (confirm.enabled === true) {
    return (
      <p role="status" className="text-body text-accent-sage">
        {t('security.enabledDone')}
      </p>
    );
  }

  if (enroll.secret === undefined) {
    return (
      <div className="flex flex-col gap-4">
        {enroll.error !== undefined && (
          <p role="alert" className="text-body text-accent-ember">
            {t(enroll.error)}
          </p>
        )}
        <Button type="button" onClick={begin} disabled={starting}>
          {starting ? t('security.preparing') : t('security.setupStart')}
        </Button>
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-6">
      <ol className="text-body flex list-decimal flex-col gap-2 pl-5">
        <li>{t('security.step1')}</li>
        <li>{t('security.step2')}</li>
        <li>{t('security.step3')}</li>
      </ol>

      {enroll.qrSvg !== undefined && (
        <div
          // QR sunucuda üretilmiş, sabit bir SVG dizesi: kullanıcı girdisi DEĞİL.
          // Girdiden üretilseydi burası XSS yolu olurdu.
          className="w-48 [&>svg]:h-auto [&>svg]:w-full"
          dangerouslySetInnerHTML={{ __html: enroll.qrSvg }}
        />
      )}

      <div className="flex flex-col gap-1">
        <span className="text-caption text-ink-muted">{t('security.setupKeyLabel')}</span>
        {/* Anahtar bir daha GÖSTERİLMEZ: onaylandıktan sonra sunucu onu geri vermez. */}
        <code className="text-body break-all select-all">{enroll.secret}</code>
      </div>

      <form action={confirmAction} className="flex flex-col gap-4">
        <Input
          label={t('security.codeLabel')}
          name="code"
          inputMode="numeric"
          autoComplete="one-time-code"
          pattern="[0-9]{6}"
          maxLength={6}
          required
        />
        {confirm.error !== undefined && (
          <p role="alert" className="text-body text-accent-ember">
            {t(confirm.error)}
          </p>
        )}
        <Button type="submit" disabled={confirming}>
          {confirming ? t('security.verifying') : t('security.enable')}
        </Button>
      </form>
    </div>
  );
}
