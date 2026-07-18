'use client';

import { useState, type FormEvent } from 'react';
import { joinWaitlist } from '@/lib/api';
import { t, type Locale } from '@/lib/i18n';

/**
 * Bekleme listesi formu. Metinler sözlükten gelir (CLAUDE.md §4: hard-code string yasak).
 * NOT: bu bileşen bir süre `lang="en"` altında TÜRKÇE metin render ediyordu ("Katıl",
 * "E-posta"); o karışıklık burada kapandı — EN sürümü artık gerçekten İngilizce.
 */
export function WaitlistForm({ locale = 'en' }: { locale?: Locale }) {
  const [email, setEmail] = useState('');
  const [status, setStatus] = useState<'idle' | 'sending' | 'done' | 'error'>('idle');

  const onSubmit = async (e: FormEvent) => {
    e.preventDefault();
    setStatus('sending');
    try {
      await joinWaitlist(email);
      setStatus('done');
    } catch {
      setStatus('error');
    }
  };

  if (status === 'done') {
    return (
      <p role="status" className="text-accent-deep">
        {t(locale, 'waitlist.success')}
      </p>
    );
  }

  return (
    <form onSubmit={onSubmit} className="flex gap-2">
      <input
        type="email"
        aria-label={t(locale, 'waitlist.emailLabel')}
        placeholder={t(locale, 'waitlist.emailPlaceholder')}
        required
        value={email}
        onChange={(e) => setEmail(e.target.value)}
        className="flex-1 rounded-button bg-bg-raised px-4 py-3 text-ink-primary"
      />
      <button
        type="submit"
        disabled={status === 'sending'}
        className="rounded-button bg-accent-aurora px-5 py-3 text-bg-base disabled:opacity-50"
      >
        {t(locale, 'waitlist.submit')}
      </button>
      {status === 'error' && (
        <p role="alert" className="text-danger">
          {t(locale, 'waitlist.error')}
        </p>
      )}
    </form>
  );
}
