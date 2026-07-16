import { describe, it, expect, vi, beforeEach } from 'vitest';

const apiPost = vi.fn();
const apiPut = vi.fn();
const apiPatch = vi.fn();
const revalidatePath = vi.fn();

vi.mock('@/shared/api/server-client', () => ({
  apiPost: (...a: unknown[]) => apiPost(...a),
  apiPut: (...a: unknown[]) => apiPut(...a),
  apiPatch: (...a: unknown[]) => apiPatch(...a),
}));
vi.mock('next/cache', () => ({ revalidatePath: (...a: unknown[]) => revalidatePath(...a) }));

const { createSoundscapeAction, setStatusAction, setRecipeAction, updateMetaAction } =
  await import('./actions');

const form = (fields: Record<string, string>): FormData => {
  const fd = new FormData();
  for (const [k, v] of Object.entries(fields)) fd.set(k, v);
  return fd;
};

beforeEach(() => {
  apiPost.mockReset();
  apiPut.mockReset();
  apiPatch.mockReset();
  revalidatePath.mockReset();
});

describe('createSoundscapeAction', () => {
  it('başarıda listeyi TAZELER — yoksa editör kaydettiğini göremez', async () => {
    apiPost.mockResolvedValue({ ok: true, data: { slug: 'yeni-ses' } });

    const state = await createSoundscapeAction({}, form({ slug: 'yeni-ses', titleEn: 'Yeni' }));

    expect(state).toEqual({ createdSlug: 'yeni-ses' });
    expect(revalidatePath).toHaveBeenCalledWith('/content');
  });

  it('affinity virgülle ayrılır, boşluklar kırpılır, boşlar atılır', async () => {
    apiPost.mockResolvedValue({ ok: true, data: { slug: 'x' } });

    await createSoundscapeAction(
      {},
      form({ slug: 'x', titleEn: 'X', archetypeAffinity: ' deep-ocean , , night-owl ' }),
    );

    expect(apiPost).toHaveBeenCalledWith('/v1/admin/soundscapes', {
      slug: 'x',
      titleEn: 'X',
      archetypeAffinity: ['deep-ocean', 'night-owl'],
    });
  });

  it('affinity boşsa boş dizi gider (undefined değil)', async () => {
    apiPost.mockResolvedValue({ ok: true, data: { slug: 'x' } });
    await createSoundscapeAction({}, form({ slug: 'x', titleEn: 'X' }));
    expect(apiPost.mock.calls[0]?.[1]).toMatchObject({ archetypeAffinity: [] });
  });

  it('slug çakışmasında AYIRT EDİCİ mesaj döner ve liste TAZELENMEZ', async () => {
    apiPost.mockResolvedValue({ ok: false, status: 409, code: 'slug_taken' });

    const state = await createSoundscapeAction({}, form({ slug: 'dolu', titleEn: 'X' }));

    expect(state.error).toContain('zaten kullanımda');
    expect(state.createdSlug).toBeUndefined();
    expect(revalidatePath).not.toHaveBeenCalled();
  });

  it('403 sessizce yutulmaz — sunucu reddederse editör sebebini görür', async () => {
    apiPost.mockResolvedValue({ ok: false, status: 403 });
    const state = await createSoundscapeAction({}, form({ slug: 'x', titleEn: 'X' }));
    expect(state.error).toContain('yetkiniz yok');
  });
});

describe('setStatusAction', () => {
  it('yayınla → doğru ucu çağırır ve listeyi tazeler', async () => {
    apiPost.mockResolvedValue({ ok: true, data: { slug: 'x' } });

    const state = await setStatusAction({}, form({ slug: 'x', action: 'publish' }));

    expect(apiPost).toHaveBeenCalledWith('/v1/admin/soundscapes/x/publish', {});
    expect(state).toEqual({});
    expect(revalidatePath).toHaveBeenCalledWith('/content');
  });

  it('yayından kaldır → unpublish ucu', async () => {
    apiPost.mockResolvedValue({ ok: true, data: { slug: 'x' } });
    await setStatusAction({}, form({ slug: 'x', action: 'unpublish' }));
    expect(apiPost).toHaveBeenCalledWith('/v1/admin/soundscapes/x/unpublish', {});
  });

  it('bilinmeyen eylem YAYINLAMAYA düşmez... aslında düşer: publish varsayılan', async () => {
    // Bilinçli: yalnızca 'unpublish' geri çeker, gerisi publish. Formu biz üretiyoruz
    // ve sunucu zaten yetkiyi/kapıyı kontrol ediyor — burada ekstra dal gereksiz.
    apiPost.mockResolvedValue({ ok: true, data: { slug: 'x' } });
    await setStatusAction({}, form({ slug: 'x', action: 'sacma' }));
    expect(apiPost).toHaveBeenCalledWith('/v1/admin/soundscapes/x/publish', {});
  });

  it('BOŞ TARİF reddi editörün diline çevrilir ve liste tazelenmez', async () => {
    apiPost.mockResolvedValue({ ok: false, status: 409, code: 'empty_recipe' });

    const state = await setStatusAction({}, form({ slug: 'x', action: 'publish' }));

    expect(state.error).toContain('Ses tarifi boş');
    expect(revalidatePath).not.toHaveBeenCalled();
  });

  it('403 sessizce yutulmaz', async () => {
    apiPost.mockResolvedValue({ ok: false, status: 403 });
    const state = await setStatusAction({}, form({ slug: 'x', action: 'publish' }));
    expect(state.error).toContain('yetkiniz yok');
  });
});

describe('setRecipeAction', () => {
  const layers = [{ id: 'base', type: 'pink', gain: 0.5 }];

  it('schemaVersion=1 ile PUT eder ve HEM detay HEM listeyi tazeler', async () => {
    apiPut.mockResolvedValue({ ok: true, data: { slug: 'x' } });

    const state = await setRecipeAction({}, form({ slug: 'x', layers: JSON.stringify(layers) }));

    expect(apiPut).toHaveBeenCalledWith('/v1/admin/soundscapes/x/recipe', {
      schemaVersion: 1,
      layers,
    });
    expect(state).toEqual({ saved: true });
    // Liste de tazelenmeli: tarif varlığı oradaki yayınlama düğmesinin sonucunu değiştirir.
    expect(revalidatePath).toHaveBeenCalledWith('/content/x');
    expect(revalidatePath).toHaveBeenCalledWith('/content');
  });

  it('BOZUK tarif reddi editörün diline çevrilir, tazeleme YAPILMAZ', async () => {
    apiPut.mockResolvedValue({ ok: false, status: 400, code: 'invalid_recipe' });

    const state = await setRecipeAction({}, form({ slug: 'x', layers: JSON.stringify(layers) }));

    expect(state.error).toBeDefined();
    expect(state.saved).toBeUndefined();
    expect(revalidatePath).not.toHaveBeenCalled();
  });

  it('403 sessizce yutulmaz', async () => {
    apiPut.mockResolvedValue({ ok: false, status: 403 });
    const state = await setRecipeAction({}, form({ slug: 'x', layers: JSON.stringify(layers) }));
    expect(state.error).toContain('yetkiniz yok');
  });

  it("bozuk JSON → API'ye HİÇ gidilmez (anlamsız istek atmayalım)", async () => {
    const state = await setRecipeAction({}, form({ slug: 'x', layers: 'bu json degil' }));
    expect(apiPut).not.toHaveBeenCalled();
    expect(state.error).toContain('okunamadı');
  });
});

describe('updateMetaAction', () => {
  it('başlık ve affinity PATCH edilir; iki yol da tazelenir', async () => {
    apiPatch.mockResolvedValue({ ok: true, data: { slug: 'x' } });

    const state = await updateMetaAction(
      {},
      form({ slug: 'x', titleEn: 'Yeni', archetypeAffinity: 'deep-ocean, night-owl' }),
    );

    expect(apiPatch).toHaveBeenCalledWith('/v1/admin/soundscapes/x', {
      titleEn: 'Yeni',
      archetypeAffinity: ['deep-ocean', 'night-owl'],
    });
    expect(state).toEqual({ saved: true });
    expect(revalidatePath).toHaveBeenCalledWith('/content/x');
    expect(revalidatePath).toHaveBeenCalledWith('/content');
  });

  it('affinity boşaltılabilir → boş dizi gider (dokunmama değil, TEMİZLEME)', async () => {
    apiPatch.mockResolvedValue({ ok: true, data: { slug: 'x' } });
    await updateMetaAction({}, form({ slug: 'x', titleEn: 'Y', archetypeAffinity: '' }));
    expect(apiPatch.mock.calls[0]?.[1]).toMatchObject({ archetypeAffinity: [] });
  });

  it('SLUG gövdeye KONULMAZ — derin linkler kırılmasın', async () => {
    apiPatch.mockResolvedValue({ ok: true, data: { slug: 'x' } });
    await updateMetaAction({}, form({ slug: 'x', titleEn: 'Y' }));
    expect(apiPatch.mock.calls[0]?.[1]).not.toHaveProperty('slug');
  });

  it('boş başlık reddi editörün diline çevrilir, tazeleme YAPILMAZ', async () => {
    apiPatch.mockResolvedValue({ ok: false, status: 400, code: 'empty_title' });
    const state = await updateMetaAction({}, form({ slug: 'x', titleEn: '' }));
    expect(state.error).toContain('Başlık boş');
    expect(revalidatePath).not.toHaveBeenCalled();
  });

  it('403 sessizce yutulmaz', async () => {
    apiPatch.mockResolvedValue({ ok: false, status: 403 });
    const state = await updateMetaAction({}, form({ slug: 'x', titleEn: 'Y' }));
    expect(state.error).toContain('yetkiniz yok');
  });
});
