/**
 * İçerik domain (docs/02 §3, docs/04). Soundscape = ses TARİFİ (engine_params);
 * MP3 stream yok, üretim on-device. Feed archetype affinity'ye göre sıralanır (saf).
 */
import type { MixerState } from './mixer-state';

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
  /** Doğrulanmış mixer durumu — `unknown` DEĞİL: bozuk preset domain'e giremez
   * (adaptör okuma yolunda `parseMixerState` ile eler, bkz. mixer-state.ts). */
  readonly mixerState: MixerState;
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

export interface WeeklyRelease {
  readonly weekStart: string; // ISO date (YYYY-MM-DD)
  readonly notes: string | null;
  readonly soundscapes: readonly Soundscape[];
}

/**
 * Admin listesi için ÖZET — `Soundscape` DEĞİL, bilerek ayrı bir okuma modeli.
 * İki sebep: (1) panelin ihtiyacı olan `status` uygulama entity'sinde YOK ve oraya
 * eklemek, uygulamanın hiç umursamadığı bir alanı her yere taşırdı; (2) panel ağır
 * `engineParams`/`layerDefs` alanlarını listede taşımamalı (liste 100 satır olabilir).
 */
export interface SoundscapeSummary {
  readonly id: string;
  readonly slug: string;
  readonly titleI18n: Record<string, string>;
  readonly status: ContentStatus;
  readonly archetypeAffinity: readonly string[];
  readonly version: number;
  readonly createdAt: Date;
}

/** Yeni taslak girdisi (admin yazma yolu). Durum daima 'draft' — yayınlama ayrı adım. */
export interface NewSoundscape {
  readonly slug: string;
  readonly titleI18n: Record<string, string>;
  readonly archetypeAffinity: readonly string[];
  /** Denetim izi: hangi admin oluşturdu (soundscapes.created_by). */
  readonly createdBy: string;
}

export interface ContentRepository {
  findPublished(): Promise<Soundscape[]>;
  /** TÜM soundscape'ler (taslak/planlı/yayınlanmış) — yalnızca admin okuma yolu. */
  findAllSummaries(): Promise<SoundscapeSummary[]>;
  /** Taslak oluşturur. Slug çakışırsa null (UNIQUE ihlalini hataya çevirmez). */
  createDraft(input: NewSoundscape): Promise<SoundscapeSummary | null>;
  findPublishedBySlug(slug: string): Promise<SoundscapeDetail | null>;
  /** En güncel haftalık yayın (yayınlanmış soundscape'lerle çözülür), yoksa null. */
  findLatestWeeklyRelease(): Promise<WeeklyRelease | null>;
}

export const CONTENT_REPOSITORY = Symbol('ContentRepository');
