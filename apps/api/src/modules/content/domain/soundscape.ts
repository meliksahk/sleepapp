/**
 * İçerik domain (docs/02 §3, docs/04). Soundscape = ses TARİFİ (engine_params);
 * MP3 stream yok, üretim on-device. Feed archetype affinity'ye göre sıralanır (saf).
 */
export type ContentStatus = 'draft' | 'scheduled' | 'published';

export interface Soundscape {
  readonly id: string;
  readonly slug: string;
  readonly titleI18n: Record<string, string>;
  readonly engineParams: Record<string, unknown>;
  readonly layerDefs: unknown;
  readonly archetypeAffinity: readonly string[];
  readonly version: number;
}

export interface Preset {
  readonly archetypeSlug: string;
  readonly mixerState: unknown;
}

export interface SoundscapeDetail {
  readonly soundscape: Soundscape;
  readonly presets: readonly Preset[];
  /** MinIO nesne anahtarı (dahili); presigned URL'e çevrilir. */
  readonly previewAssetKey: string | null;
}

/** Asset presigned URL üretimi (S3/MinIO). Üretim offline'dır (imza hesabı). */
export interface AssetUrlSigner {
  presignedGetUrl(bucket: string, key: string, expirySeconds: number): Promise<string>;
}

export const ASSET_URL_SIGNER = Symbol('AssetUrlSigner');

/**
 * Affinity sıralaması: verilen archetype'a yakın soundscape'ler önce (stable),
 * gerisi sırayı korur. archetype yoksa liste değişmez.
 */
export function sortByAffinity<T extends Soundscape>(
  list: readonly T[],
  archetype: string | undefined,
): T[] {
  if (!archetype) return [...list];
  const match: T[] = [];
  const rest: T[] = [];
  for (const s of list) {
    (s.archetypeAffinity.includes(archetype) ? match : rest).push(s);
  }
  return [...match, ...rest];
}

export interface ContentRepository {
  findPublished(): Promise<Soundscape[]>;
  findPublishedBySlug(slug: string): Promise<SoundscapeDetail | null>;
}

export const CONTENT_REPOSITORY = Symbol('ContentRepository');
