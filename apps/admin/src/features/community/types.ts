/** Panel görüntüsü — API `AdminUserSoundDto` ile birebir (community modülü). */
export interface AdminCommunitySound {
  id: string;
  userId: string;
  title: string;
  status: 'pending' | 'approved' | 'rejected';
  byteSize: number | null;
  durationSeconds: number;
  rejectionReason: string | null;
  moderatedAt: string | null;
  createdAt: string;
}

/**
 * Moderasyon = editoryal karar → owner/editor. analyst salt-okunur, support
 * moderasyon yapmaz. Tek kaynak API'dir (@Roles('owner','editor')); bu fonksiyon
 * yalnızca BÖLÜM GÖRÜNÜRLÜĞÜNÜ belirler — "UI gizleme yeterli değil" (§3.3).
 */
export function canModerateCommunity(roles: readonly string[]): boolean {
  return roles.includes('owner') || roles.includes('editor');
}
