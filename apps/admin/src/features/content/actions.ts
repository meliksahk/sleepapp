'use server';

import { revalidatePath } from 'next/cache';
import { apiPatch, apiPost, apiPut } from '@/shared/api/server-client';
import { createErrorMessage } from './error-message';
import type { AdminSoundscape } from './types';

export interface CreateState {
  error?: string;
  createdSlug?: string;
}

export interface StatusState {
  error?: string;
}

export interface RecipeState {
  error?: string;
  saved?: boolean;
}

export interface MetaState {
  error?: string;
  saved?: boolean;
}

/**
 * Taslak oluşturma (Server Action). Token httpOnly çerezde olduğu için çağrı
 * SUNUCUDAN gitmek zorunda — tarayıcı API'ye doğrudan gidemez (#116 kararı).
 *
 * DOĞRULAMA BURADA DEĞİL, SUNUCUDA: slug kuralı, çakışma ve rol kontrolü API'nin
 * işi (#120). Burada tekrar etmek iki farklı doğruluk kaynağı yaratır ve biri
 * sessizce eskir. Burada yalnızca yanıtı editörün diline çeviriyoruz.
 */
export async function createSoundscapeAction(
  _prev: CreateState,
  formData: FormData,
): Promise<CreateState> {
  const slug = String(formData.get('slug') ?? '');
  const titleEn = String(formData.get('titleEn') ?? '');
  const affinityRaw = String(formData.get('archetypeAffinity') ?? '');

  const archetypeAffinity = affinityRaw
    .split(',')
    .map((s) => s.trim())
    .filter((s) => s.length > 0);

  const res = await apiPost<AdminSoundscape>('/v1/admin/soundscapes', {
    slug,
    titleEn,
    archetypeAffinity,
  });

  if (!res.ok) {
    return { error: createErrorMessage(res.status, res.code) };
  }

  // Liste sunucuda render ediliyor → yeni kaydın görünmesi için tazele.
  revalidatePath('/content');
  return { createdSlug: res.data.slug };
}

/**
 * Yayınla / yayından kaldır (Server Action).
 *
 * Kapıyı (boş tarif) tekrar ETMEZ: karar sunucunun (#122). Buradaki iş, reddi
 * editörün anlayacağı bir cümleye çevirmek — "409" göstermek işe yaramaz.
 */
export async function setStatusAction(
  _prev: StatusState,
  formData: FormData,
): Promise<StatusState> {
  const slug = String(formData.get('slug') ?? '');
  const action = String(formData.get('action') ?? '');
  const path = action === 'unpublish' ? 'unpublish' : 'publish';

  const res = await apiPost<AdminSoundscape>(`/v1/admin/soundscapes/${slug}/${path}`, {});
  if (!res.ok) {
    return { error: createErrorMessage(res.status, res.code) };
  }

  revalidatePath('/content');
  return {};
}

/**
 * Ses tarifini kaydet (Server Action).
 *
 * Katmanlar JSON olarak gelir: dinamik satır sayısını düz FormData alanlarıyla ifade
 * etmek ad çakışması ve sıra hataları üretirdi. Şema DOĞRULAMASI burada TEKRAR
 * EDİLMEZ — kural API'de (#123); buradaki iş, reddi editörün diline çevirmek.
 */
export async function setRecipeAction(
  _prev: RecipeState,
  formData: FormData,
): Promise<RecipeState> {
  const slug = String(formData.get('slug') ?? '');
  const layersJson = String(formData.get('layers') ?? '[]');

  let layers: unknown;
  try {
    layers = JSON.parse(layersJson);
  } catch {
    return { error: 'Katmanlar okunamadı. Sayfayı yenileyip tekrar deneyin.' };
  }

  const res = await apiPut<AdminSoundscape>(`/v1/admin/soundscapes/${slug}/recipe`, {
    schemaVersion: 1,
    layers,
  });
  if (!res.ok) {
    return { error: createErrorMessage(res.status, res.code) };
  }

  // Hem detay hem LİSTE: tarif varlığı listedeki yayınlama düğmesinin sonucunu değiştirir.
  revalidatePath(`/content/${slug}`);
  revalidatePath('/content');
  return { saved: true };
}

/**
 * Başlık/affinity güncelle (Server Action).
 *
 * Slug alanı YOK ve olmayacak: derin linkte yaşar; değiştirmek dışarıdaki linkleri
 * sessizce kırardı (API de gövdedeki slug'ı reddediyor — #125).
 */
export async function updateMetaAction(_prev: MetaState, formData: FormData): Promise<MetaState> {
  const slug = String(formData.get('slug') ?? '');
  const titleEn = String(formData.get('titleEn') ?? '');
  const affinityRaw = String(formData.get('archetypeAffinity') ?? '');

  const archetypeAffinity = affinityRaw
    .split(',')
    .map((s) => s.trim())
    .filter((s) => s.length > 0);

  const res = await apiPatch<AdminSoundscape>(`/v1/admin/soundscapes/${slug}`, {
    titleEn,
    archetypeAffinity,
  });
  if (!res.ok) {
    return { error: createErrorMessage(res.status, res.code) };
  }

  revalidatePath(`/content/${slug}`);
  revalidatePath('/content');
  return { saved: true };
}
