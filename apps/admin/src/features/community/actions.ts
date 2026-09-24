'use server';

import { revalidatePath } from 'next/cache';
import { apiPost } from '@/shared/api/server-client';
import type { MessageKey } from '@/shared/i18n/dictionaries';
import type { AdminCommunitySound } from './types';

/**
 * Moderasyon kararı (Server Action). Doğrulama/durum makinesi API'dedir
 * (`POST /v1/admin/community-sounds/:id/moderate`); burada yalnızca yanıt,
 * editörün diline çevrilen bir MESAJ ANAHTARINA dönüşür — dizge taşımak,
 * kararı o anki dile çakmak olurdu (content/actions.ts'teki aynı kural).
 */
export interface ModerateState {
  error?: MessageKey;
  decided?: boolean;
}

export async function moderateSoundAction(
  soundId: string,
  decision: 'approve' | 'reject',
  rejectionReason: string,
): Promise<ModerateState> {
  const res = await apiPost<AdminCommunitySound>(
    `/v1/admin/community-sounds/${encodeURIComponent(soundId)}/moderate`,
    {
      decision,
      // approve'ta boş gerekçe gönderilmez; API alanı yok sayar, reject'te zorunludur.
      ...(decision === 'reject' ? { rejectionReason } : {}),
    },
  );

  if (!res.ok) {
    if (res.status === 409) return { error: 'community.errorConflict' };
    if (res.status === 400) return { error: 'community.errorReasonRequired' };
    if (res.status === 403) return { error: 'community.noPermission' };
    return { error: 'community.errorGeneric' };
  }

  revalidatePath('/community');
  return { decided: true };
}
