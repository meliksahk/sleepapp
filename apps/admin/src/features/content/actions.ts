'use server';

import { revalidatePath } from 'next/cache';
import { apiPost } from '@/shared/api/server-client';
import { createErrorMessage } from './error-message';
import type { AdminSoundscape } from './types';

export interface CreateState {
  error?: string;
  createdSlug?: string;
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
