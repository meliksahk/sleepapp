import { LAYER_SOURCES } from './mixer-state';

/** content domain hataları — tipli hiyerarşi (CLAUDE.md §4). */
export class ContentError extends Error {
  constructor(
    readonly code: string,
    message: string,
  ) {
    super(message);
    this.name = 'ContentError';
  }
}

export class SlugTakenError extends ContentError {
  constructor(slug: string) {
    super('slug_taken', `Bu slug zaten kullanımda: ${slug}`);
  }
}

export class InvalidSlugError extends ContentError {
  constructor() {
    super('invalid_slug', 'Slug küçük harf ve tire içermeli (ör. deep-ocean-drift).');
  }
}

/**
 * Ses tarifi (engine_params) boş olan kayıt yayınlanamaz.
 *
 * NEDEN KURAL: feed DTO'su `engineParams`'ı uygulamaya taşır ve ses ON-DEVICE bu
 * tariften üretilir. Boş tarifle yayınlamak, kütüphanede görünen ama SES ÇIKARMAYAN
 * bir kayıt demektir — sessiz bozuk içerik. Taslak boş doğar (iskelet), ama boş
 * KALDIĞI sürece kullanıcıya ulaşamaz.
 */
export class EmptyRecipeError extends ContentError {
  constructor() {
    super(
      'empty_recipe',
      'Ses tarifi boş olan kayıt yayınlanamaz. Önce engine_params doldurulmalı.',
    );
  }
}

/** İstenen soundscape yok. */
export class SoundscapeNotFoundError extends ContentError {
  constructor(slug: string) {
    super('soundscape_not_found', `Soundscape bulunamadı: ${slug}`);
  }
}

/** Ses tarifi sözleşmeye uymuyor (bkz. engine-params.ts). */
export class InvalidRecipeError extends ContentError {
  constructor() {
    super(
      'invalid_recipe',
      'Ses tarifi geçersiz: schemaVersion=1 ve 1–8 arası benzersiz katman ' +
        `({id, type: ${LAYER_SOURCES.join('|')}, gain: 0–1}) gerekir.`,
    );
  }
}
