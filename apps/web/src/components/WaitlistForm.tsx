'use client';

import { useState, type FormEvent } from 'react';
import { joinWaitlist } from '@/lib/api';

export function WaitlistForm() {
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
        Teşekkürler — listedesin. Lansmanda haber vereceğiz.
      </p>
    );
  }

  return (
    <form onSubmit={onSubmit} className="flex gap-2">
      <input
        type="email"
        aria-label="E-posta"
        placeholder="you@example.com"
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
        Katıl
      </button>
      {status === 'error' && (
        <p role="alert" className="text-danger">
          Bir hata oldu.
        </p>
      )}
    </form>
  );
}
