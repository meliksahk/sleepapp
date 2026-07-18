/**
 * Yayın durumu — content'ten import EDİLMEZ, admin'in KENDİ sözleşmesidir.
 * Boundary lint bunu zorluyor ve haklı: `domain/` dışa bağımlı olamaz (hexagonal).
 * Bedeli üç değerin tekrarı; kazancı, content'in iç tipini değiştirmesinin admin'i
 * sessizce kırmaması — eşleme module-def'te AÇIKÇA yapılır ve orada derleme hatası verir.
 */
export type CatalogStatus = 'draft' | 'scheduled' | 'published';

/**
 * Panelin gördüğü soundscape kaydı. Admin modülü content'in repo'suna DOKUNMAZ;
 * bu port module-def'te content'in PUBLIC use case'ine adapte edilir
 * (sleep→profile, content→archetype deseninin aynısı, docs/02 §2).
 */
export interface CatalogEntry {
  readonly id: string;
  readonly slug: string;
  readonly title: string;
  readonly status: CatalogStatus;
  readonly archetypeAffinity: readonly string[];
  readonly version: number;
  readonly createdAt: Date;
}

/** Yeni taslak girdisi (panelden). */
export interface NewCatalogEntry {
  readonly slug: string;
  readonly titleEn: string;
  readonly archetypeAffinity: readonly string[];
  readonly createdBy: string;
}

/** Tek kayıt + düzenlenecek ham tarif. */
export interface CatalogDetail {
  readonly entry: CatalogEntry;
  readonly recipe: unknown;
}

export interface SoundscapeCatalog {
  list(): Promise<CatalogEntry[]>;
  get(slug: string): Promise<CatalogDetail>;
  create(input: NewCatalogEntry): Promise<CatalogEntry>;
  publish(slug: string): Promise<CatalogEntry>;
  /** Ses tarifini yazar (doğrulama content'in işi). */
  setRecipe(slug: string, recipe: unknown): Promise<CatalogEntry>;
  /** Başlık/affinity günceller (kısmi). Slug DEĞİŞTİRİLEMEZ — derin linkte yaşar. */
  update(
    slug: string,
    patch: { titleEn?: string; archetypeAffinity?: string[] },
  ): Promise<CatalogEntry>;
  unpublish(slug: string): Promise<CatalogEntry>;
}

export const SOUNDSCAPE_CATALOG = Symbol('SoundscapeCatalog');

/**
 * Panel panosu rakamları. YALNIZCA bugün DOĞRU hesaplanabilenler burada:
 * D7 retention (kohort analizi) ve deneme→ücretli (F6/billing) henüz ölçülemez —
 * onlar için sahte sayı üretmektense panelde dürüst yer tutucu kalır.
 */
export interface Overview {
  readonly soundscapes: {
    readonly draft: number;
    readonly scheduled: number;
    readonly published: number;
  };
  readonly waitlist: number;
  /** Erişilebilir push kitlesi (#185): kayıtlı cihazı olan benzersiz kullanıcı = kampanya reach üst sınırı. */
  readonly pushAudience: number;
  /**
   * Viral kancanın sağlığı: kartını paylaşan / testi tamamlayan BENZERSİZ kullanıcı.
   * `rate` null olabilir — kimse testi tamamlamadıysa oran TANIMSIZDIR; 0 göstermek
   * "kimse paylaşmıyor" demek olurdu ve bu yanlış bir ifadedir.
   */
  readonly shareFunnel: {
    readonly completed: number;
    readonly shared: number;
    readonly rate: number | null;
  };
}

export interface OverviewSource {
  read(): Promise<Overview>;
}

export const OVERVIEW_SOURCE = Symbol('OverviewSource');
