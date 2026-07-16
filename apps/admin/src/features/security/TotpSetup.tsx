'use client';

import { useActionState, useState, useTransition } from 'react';
import { Button, Input } from '@nocta/ui';
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
        İki adımlı doğrulama etkinleştirildi. Bundan sonra her girişte uygulamanızdaki kod
        istenecek.
      </p>
    );
  }

  if (enroll.secret === undefined) {
    return (
      <div className="flex flex-col gap-4">
        {enroll.error !== undefined && (
          <p role="alert" className="text-body text-accent-ember">
            {enroll.error}
          </p>
        )}
        <Button type="button" onClick={begin} disabled={starting}>
          {starting ? 'Hazırlanıyor…' : 'İki adımlı doğrulamayı kur'}
        </Button>
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-6">
      <ol className="text-body flex list-decimal flex-col gap-2 pl-5">
        <li>
          Doğrulama uygulamanızda (Google Authenticator, 1Password, Aegis…) yeni hesap ekleyin.
        </li>
        <li>Aşağıdaki kodu okutun veya anahtarı elle girin.</li>
        <li>Uygulamanın ürettiği 6 haneli kodu yazıp onaylayın.</li>
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
        <span className="text-caption text-ink-muted">Kurulum anahtarı (elle giriş için)</span>
        {/* Anahtar bir daha GÖSTERİLMEZ: onaylandıktan sonra sunucu onu geri vermez. */}
        <code className="text-body break-all select-all">{enroll.secret}</code>
      </div>

      <form action={confirmAction} className="flex flex-col gap-4">
        <Input
          label="Uygulamadaki 6 haneli kod"
          name="code"
          inputMode="numeric"
          autoComplete="one-time-code"
          pattern="[0-9]{6}"
          maxLength={6}
          required
        />
        {confirm.error !== undefined && (
          <p role="alert" className="text-body text-accent-ember">
            {confirm.error}
          </p>
        )}
        <Button type="submit" disabled={confirming}>
          {confirming ? 'Doğrulanıyor…' : 'Etkinleştir'}
        </Button>
      </form>
    </div>
  );
}
