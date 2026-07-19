/**
 * Ses DOSYASI varlığı (audio_assets) — soundscape TARİFİNİN karşıtı.
 *
 * Soundscape bir tariftir (`engine_params` → on-device sentez, sunucu ses tutmaz).
 * AudioAsset ise gerçek bir dosyadır: MinIO'da (ileride S3/CDN) durur, uygulama onu
 * presigned URL ile ÇALAR, render etmez. İkisi mikserde YAN YANA duyulur.
 *
 * ## KATALOG VERİSİ — userId scoping YOK (ve neden)
 *
 * CLAUDE.md §3.2 "her sorgu, isteği yapan kullanıcının kimliğiyle kapsamlanır"
 * kuralı KİŞİSEL VERİ taşıyan tablolar içindir. `audio_assets` tam olarak
 * `soundscapes` gibi bir KATALOG tablosudur: satırların sahibi yoktur, herkes
 * aynı listeyi görür, hiçbir satır bir kullanıcıya ait değildir. Scope edilecek
 * `user_id` kolonu olmadığı için "A, B'nin verisini okuyamaz" testinin öznesi de
 * yoktur. Burada geçerli olan kural KİMLİK DOĞRULAMAdır: uçlar `ContentController`
 * içinde yaşar ve sınıf düzeyindeki `AuthGuard`'a tabidir (token yoksa 401).
 *
 * ⚠️ Kullanıcı KENDİ telefonundan dosya yüklerse bu tablo YETMEZ — o satırların
 * sahibi olur ve `user_id` + scoping ŞART olur. Bugün o yol yok (local import
 * kapsam dışı bırakıldı); eklenirse ayrı tablo/kolon + scoping testi gerekir.
 */

export interface AudioAsset {
  readonly id: string;
  /**
   * DEPOLAMA ANAHTARI — URL DEĞİL (ör. 'demo/pad-fire-demo.wav').
   * Backend taşınabilsin diye: URL saklasaydık MinIO→S3 geçişinde her satır bozulurdu.
   */
  readonly key: string;
  readonly title: string;
  readonly genre: string;
  readonly mood: readonly string[];
  readonly durationSeconds: number;
  /** Mağaza uyumu için ZORUNLU (DB'de CHECK ile boş dizgi de reddedilir). */
  readonly license: string;
  readonly source: string;
}

/** Tekil okuma sonucu: meta + kısa ömürlü indirme URL'si. */
export interface AudioAssetWithUrl {
  readonly asset: AudioAsset;
  readonly url: string;
  readonly expiresInSeconds: number;
}

/**
 * Liste filtresi. Alanların ikisi de opsiyonel; ikisi birden verilirse VE'lenir.
 * `mood` çok değerlidir ve ÖRTÜŞME (herhangi biri) semantiği taşır — kullanıcı
 * "sakin ya da odak" arar, "hem sakin hem odak" değil.
 */
export interface AudioAssetFilter {
  readonly genre?: string;
  readonly moods?: readonly string[];
}

export interface AudioAssetRepository {
  list(filter: AudioAssetFilter): Promise<AudioAsset[]>;
  findById(id: string): Promise<AudioAsset | null>;
}

export const AUDIO_ASSET_REPOSITORY = Symbol('AudioAssetRepository');

/**
 * Presigned URL ömrü. Kısa TUTULUR ama çalma süresinden kısa OLAMAZ: kullanıcı
 * sesi açıp uyur, URL çalarken dolarsa ses gecenin ortasında kesilir. 6 saat,
 * tipik bir gece uykusunu (7-8 saat) TAM kapsamaz — bilinçli bir denge:
 * uygulama dosyayı çalmadan önce indirir/tamponlar, yani süre yalnızca AÇILIŞTA
 * geçerli olmalıdır. Sınırsıza yakın bir URL ise sızdığında kalıcı erişim demektir.
 */
export const ASSET_URL_TTL_SECONDS = 6 * 60 * 60;

/** Filtre olarak kabul edilen azami mood sayısı (sorgu şişmesini engeller). */
export const MAX_MOOD_FILTER = 8;

/**
 * `?mood=calm,focus` → ['calm','focus']. Boş parçalar atılır, küçük harfe indirilir,
 * tekrarlar elenir ve [MAX_MOOD_FILTER] ile kırpılır. Saf fonksiyon — testi ucuz.
 *
 * Neden burada (controller'da değil): CLAUDE.md §3.2 "controller'da iş mantığı yasak".
 */
export function parseMoodFilter(raw: string | undefined): string[] | undefined {
  if (raw === undefined) return undefined;
  const parts = raw
    .split(',')
    .map((s) => s.trim().toLowerCase())
    .filter((s) => s.length > 0);
  const unique = [...new Set(parts)];
  return unique.length === 0 ? undefined : unique.slice(0, MAX_MOOD_FILTER);
}
