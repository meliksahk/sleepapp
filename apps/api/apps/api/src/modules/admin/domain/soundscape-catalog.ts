import type { ContentStatus } from '../../content';

/**
 * Panelin gördüğü soundscape kaydı. Admin modülü content'in repo'suna DOKUNMAZ;
 * bu port module-def'te content'in PUBLIC use case'ine adapte edilir
 * (sleep→profile, content→archetype deseninin aynısı, docs/02 §2).
 */
export interface CatalogEntry {
  readonly id: string;
  readonly slug: string;
  readonly title: string;
  readonly status: ContentStatus;
  readonly archetypeAffinity: readonly string[];
  readonly version: number;
  readonly createdAt: Date;
}

export interface SoundscapeCatalog {
  list(): Promise<CatalogEntry[]>;
}

export const SOUNDSCAPE_CATALOG = Symbol('SoundscapeCatalog');
