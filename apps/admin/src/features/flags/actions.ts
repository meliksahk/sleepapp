'use server';

import { revalidatePath } from 'next/cache';
import { apiPut } from '@/shared/api/server-client';
import { flagErrorMessage } from './flag-error-message';
import type { AdminFlag } from './types';

export interface UpsertFlagState {
  error?: string;
  savedKey?: string;
}

/**
 * Flag oluştur/değiştir (Server Action). Token httpOnly çerezde → çağrı SUNUCUDAN
 * gider (#116). Rol/anahtar/yüzde DOĞRULAMASI burada TEKRAR EDİLMEZ: kural API'de
 * (#167, owner-kapılı + DTO). Buradaki iş yalnızca reddi owner'ın diline çevirmek.
 *
 * Boş opsiyonel alanlar GÖNDERİLMEZ (JSON.stringify undefined'ı düşürür) → API onları
 * "tanımsız" (herkes / segment yok) olarak yorumlar; boş string göndermek 400 olurdu.
 */
export async function upsertFlagAction(
  _prev: UpsertFlagState,
  formData: FormData,
): Promise<UpsertFlagState> {
  const key = String(formData.get('key') ?? '').trim();
  const enabled = String(formData.get('enabled') ?? 'false') === 'true';

  const rolloutRaw = String(formData.get('rolloutPercentage') ?? '').trim();
  const parsedRollout = Number(rolloutRaw);
  // Yalnızca sonlu bir sayıysa gönder: boş → undefined (herkes), çöp → gönderme
  // (API'ye NaN/null sızdırıp sessizce "rollout yok"a düşmesini engelle).
  const rolloutPercentage =
    rolloutRaw.length > 0 && Number.isFinite(parsedRollout) ? parsedRollout : undefined;

  const platformsRaw = String(formData.get('platforms') ?? '').trim();
  const platforms =
    platformsRaw.length > 0
      ? platformsRaw
          .split(',')
          .map((p) => p.trim())
          .filter((p) => p.length > 0)
      : undefined;

  const minAppVersionRaw = String(formData.get('minAppVersion') ?? '').trim();
  const minAppVersion = minAppVersionRaw.length > 0 ? minAppVersionRaw : undefined;

  const res = await apiPut<AdminFlag>(`/v1/admin/flags/${encodeURIComponent(key)}`, {
    enabled,
    rolloutPercentage,
    platforms,
    minAppVersion,
  });

  if (!res.ok) {
    return { error: flagErrorMessage(res.status, res.code) };
  }

  // Liste sunucuda render ediliyor → yeni/değişen flag'in görünmesi için tazele.
  revalidatePath('/flags');
  return { savedKey: res.data.key };
}
