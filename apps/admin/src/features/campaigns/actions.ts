'use server';

import { apiPost } from '@/shared/api/server-client';
import { campaignErrorMessage } from './campaign-error-message';
import type { CampaignResult } from './types';

export interface SendCampaignState {
  error?: string;
  result?: CampaignResult;
}

/**
 * Push kampanyası gönder (Server Action). Token httpOnly çerezde → çağrı SUNUCUDAN gider
 * (#116). Rol/doğrulama TEKRAR EDİLMEZ: kural API'de (#183, owner-kapılı + DTO). Buradaki
 * iş yalnızca gövdeyi kurup reddi owner'ın diline çevirmek.
 *
 * Boş/geçersiz platform GÖNDERİLMEZ (undefined → "tüm push kullanıcıları"); boş string
 * API'de 400 olurdu.
 */
export async function sendCampaignAction(
  _prev: SendCampaignState,
  formData: FormData,
): Promise<SendCampaignState> {
  const title = String(formData.get('title') ?? '').trim();
  const body = String(formData.get('body') ?? '').trim();
  const platformRaw = String(formData.get('platform') ?? '').trim();
  const platform = platformRaw === 'ios' || platformRaw === 'android' ? platformRaw : undefined;

  const res = await apiPost<CampaignResult>('/v1/admin/campaigns', { title, body, platform });
  if (!res.ok) {
    return { error: campaignErrorMessage(res.status) };
  }
  return { result: res.data };
}
