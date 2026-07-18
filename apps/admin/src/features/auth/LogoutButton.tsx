'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { Button } from '@nocta/ui';
import { useT } from '@/shared/i18n/I18nProvider';

/** Çıkış — /api/session sunucudaki oturumu da iptal eder, sonra çerezleri siler. */
export function LogoutButton() {
  const t = useT();
  const router = useRouter();
  const [busy, setBusy] = useState(false);

  async function onClick(): Promise<void> {
    if (busy) return;
    setBusy(true);
    try {
      await fetch('/api/session', { method: 'DELETE' });
    } catch {
      // Ağ hatası olsa bile login'e git: kullanıcı "çık" dedi, ekranda tutmak yanlış.
    } finally {
      router.push('/login');
      router.refresh();
    }
  }

  return (
    <Button variant="ghost" onClick={onClick} disabled={busy}>
      {busy ? t('common.loggingOut') : t('common.logout')}
    </Button>
  );
}
