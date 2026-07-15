import type { AssetUrlSigner, ContentRepository, Preset, Soundscape } from '../domain/soundscape';

export interface SoundscapeDetailResult {
  readonly soundscape: Soundscape;
  readonly presets: readonly Preset[];
  /** preview_asset_key varsa presigned GET URL, yoksa null. */
  readonly previewUrl: string | null;
}

const PREVIEW_TTL_SECONDS = 3600;

/** Yayınlanmış soundscape + preset + (varsa) presigned önizleme URL'i. */
export class GetSoundscapeUseCase {
  constructor(
    private readonly content: ContentRepository,
    private readonly signer: AssetUrlSigner,
    private readonly bucket: string,
  ) {}

  async execute(slug: string): Promise<SoundscapeDetailResult | null> {
    const detail = await this.content.findPublishedBySlug(slug);
    if (!detail) return null;
    const previewUrl = detail.previewAssetKey
      ? await this.signer.presignedGetUrl(this.bucket, detail.previewAssetKey, PREVIEW_TTL_SECONDS)
      : null;
    return { soundscape: detail.soundscape, presets: detail.presets, previewUrl };
  }
}
