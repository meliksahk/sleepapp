import { randomBytes } from 'node:crypto';
import type { SlugGenerator } from '../domain/web';

/** ~11 karakter base64url paylaşım slug'ı (URL-güvenli, tahmin edilemez). */
export class RandomSlugGenerator implements SlugGenerator {
  generate(): string {
    return randomBytes(8).toString('base64url');
  }
}
