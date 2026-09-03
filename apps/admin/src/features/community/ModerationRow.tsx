'use client';

import { useState, useTransition } from 'react';
import { Button } from '@nocta/ui';
import { useT } from '@/shared/i18n/I18nProvider';
import { moderateSoundAction } from './actions';
import type { AdminCommunitySound } from './types';

/**
 * Tek moderasyon satırı — dinle (3b) + onay (tek tık) + red (gerekçe ister).
 *
 * **Önizleme URL'i SUNUCUDA üretilir** (presigned) ve prop olarak hazır gelir;
 * bu bileşen ağ görmez. `<audio controls>` yereldir: ek JS player'ı, ek paket,
 * ek saldırı yüzeyi yok.
 *
 * **Red gerekçesi İSTEMCİDE zorunlu tutulur ama gerçek kapı API'dedir** (400):
 * istemci kontrolü UX'tir, güvenlik değil. Gerekçesiz red, kullanıcıya
 * "nedenini söyleyemediğimiz bir sansür" demektir — API CHECK kısıtı da bunu
 * veritabanı seviyesinde yasaklar.
 */
export function ModerationRow({
  sound,
  previewUrl,
}: {
  sound: AdminCommunitySound;
  previewUrl?: string;
}) {
  const t = useT();
  const [pending, startTransition] = useTransition();
  const [rejecting, setRejecting] = useState(false);
  const [playing, setPlaying] = useState(false);
  const [reason, setReason] = useState('');
  const [error, setError] = useState<string | null>(null);

  const decide = (decision: 'approve' | 'reject') => {
    setError(null);
    startTransition(async () => {
      const res = await moderateSoundAction(sound.id, decision, reason.trim());
      if (res.error) {
        setError(t(res.error));
        return;
      }
      // Başarıda satır listeden düşer: sayfa revalidatePath ile tazelenir.
    });
  };

  return (
    <li className="border-b border-ink-faint/20 py-3">
      <div className="flex flex-wrap items-center gap-3">
        <span className="min-w-0 flex-1 truncate text-body text-ink-primary" title={sound.title}>
          {sound.title}
        </span>
        <span className="text-caption text-ink-secondary">
          {Math.round(sound.durationSeconds / 60)} min
        </span>
        {previewUrl && (
          <Button variant="ghost" onClick={() => setPlaying((v) => !v)}>
            {playing ? t('community.hidePlayer') : t('community.play')}
          </Button>
        )}
        <Button variant="ghost" onClick={() => decide('approve')} disabled={pending}>
          {t('community.approve')}
        </Button>
        <Button variant="ghost" onClick={() => setRejecting((v) => !v)} disabled={pending}>
          {t('community.reject')}
        </Button>
      </div>
      {/* Yerel audio elementi: presigned URL doğrudan kaynağa gider; API'den stream edilmez. */}
      {playing && previewUrl && (
        <audio controls preload="none" src={previewUrl} className="mt-2 w-full max-w-md">
          <track kind="captions" />
        </audio>
      )}
      {rejecting && (
        <div className="mt-2 flex flex-wrap gap-2">
          <input
            value={reason}
            onChange={(e) => setReason(e.target.value)}
            maxLength={500}
            placeholder={t('community.reasonPlaceholder')}
            aria-label={t('community.reasonPlaceholder')}
            className="min-h-11 flex-1 rounded-chip border border-ink-faint/40 bg-bg-base px-3 text-body"
          />
          <Button onClick={() => decide('reject')} disabled={pending || reason.trim().length === 0}>
            {t('community.rejectConfirm')}
          </Button>
        </div>
      )}
      {error && (
        <p role="alert" className="mt-2 text-caption text-accent-ember">
          {error}
        </p>
      )}
    </li>
  );
}
