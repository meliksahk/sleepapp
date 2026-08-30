/**
 * Preset mixer_state **sözleşmesi** — saf domain.
 *
 * Neden var: `presets.mixer_state` şimdiye dek serbest `jsonb` idi (tip: `unknown`).
 * Editör oraya herhangi bir JSON koyabilirdi ve hata ancak **kullanıcının
 * telefonunda, çalma anında** ortaya çıkardı. Şema burada tanımlanır ve okuma
 * yolunda doğrulanır → bozuk içerik istemciye HİÇ ulaşmaz.
 *
 * Şekil, mobil ses motorunun `MixSpec`'iyle birebir hizalıdır (apps/mobile
 * core/audio_engine/dsp/mix_render.dart): katman = {id, type, gain}.
 * İkisi ayrı repo katmanında olduğu için sözleşme burada + docs'ta yazılıdır;
 * değişirse İKİSİ birlikte değişmelidir.
 */

/**
 * Motorun desteklediği jeneratif kaynaklar (mobil `LayerSource` enum'u ile AYNI).
 *
 * `white|pink|brown` düz gürültü; `waves|fire|rain` gürültü yatağı üstüne zarf ve
 * transient kuran meditatif dokular; `pad` tonal (içinde gürültü yok); `tone`
 * kullanıcının seçtiği frekanstaki saf sinüs (frekans katman başına
 * `frequencyHz` ile taşınır — tek parametrelidir). Hepsi on-device SENTEZDİR —
 * sunucu ses dosyası tutmaz, yalnızca tarifi doğrular.
 *
 * ⚠️ **SIRA ÖNEMLİ:** `tooling/check-layer-source-drift.mjs` bu listeyi mobil
 * enum'la ve admin panelinin kopyasıyla SIRA DAHİL karşılaştırır. Yeni kaynak
 * eklerken üçü birden güncellenmeli, yoksa CI kırmızıya döner. Kapının varlık
 * sebebi: liste ayrışırsa editör panelde geçerli görünen bir tarif kaydeder,
 * hata ancak KULLANICININ TELEFONUNDA çalma anında ortaya çıkar.
 */
export const LAYER_SOURCES = [
  'white',
  'pink',
  'brown',
  'waves',
  'fire',
  'rain',
  'pad',
  'tone',
  'chords',
  'arpeggio',
  'ceramic',
  'chimes',
] as const;
export type LayerSource = (typeof LAYER_SOURCES)[number];

/**
 * `tone` katmanının kabul edilen frekans aralığı. Mobil `tone.dart`'taki
 * `toneMinHz`/`toneMaxHz` ile AYNI sayılar ve aynı gerekçe (~20 Hz işitme
 * eşiği; 2 kHz üstü uyku bağlamında sert). İki taraf ayrışsaydı admin'de
 * kaydedilen bir tarif telefonda reddedilirdi — drift kapısı bunu yakalar.
 */
export const TONE_MIN_HZ = 20;
export const TONE_MAX_HZ = 2000;

/**
 * Binaural vuru aralığı — mobil `tone.dart` (toneBeatMinHz/Max) ile AYNI sayılar
 * ve aynı gerekçe: akustik vuru olayı, EEG/şifa adları ve iddiaları yasak (§1.1).
 *
 * **SÖZLEŞME ÜYESİDİR, süs değil:** tarifler parse edilmiş hâliyle yazılır
 * (SetSoundscapeRecipeUseCase) — alan burada taşınmazsa editörün kaydettiği
 * binaural tarif sessizce MONO'ya indirgenirdi. Opsiyoneldir: yokluk = mono;
 * `0` göndermek yerine alanın YOKLUĞU mono'nun tek tel ifadesidir.
 */
export const TONE_BEAT_MIN_HZ = 0.5;
export const TONE_BEAT_MAX_HZ = 20;

export interface MixerLayer {
  readonly id: string;
  readonly type: LayerSource;
  /** [0,1] — mikser kazancı. */
  readonly gain: number;
  /**
   * YALNIZCA `type === 'tone'`: temel frekans (Hz), [TONE_MIN_HZ, TONE_MAX_HZ].
   *
   * Sözleşme PAZARLIKSIZDIR: ton katmanında alan YOKSA tarif reddedilir,
   * ton DIŞI katmanda alan VARSA yine reddedilir. "Sessizce yok say" seçeneği
   * bilinçli olarak reddedildi — kısmen geçerli bir tarif, kullanıcının
   * telefonunda duyulmayan bir sapma üretir; bozuk içerik istemciye hiç
   * ulaşmamalı (bu dosyanın varlık sebebi tam olarak budur).
   */
  readonly frequencyHz?: number;
  /**
   * YALNIZCA `type === 'tone'`: binaural vuru (Hz/s), (TONE_BEAT_MIN_HZ,
   * TONE_BEAT_MAX_HZ]. Opsiyonel: YOKLUK mono demektir (0 gönderilmez).
   * Telefon bu katmanı STEREO çalar (L/R farklı perde); mobil `MixLayer.beatHz`
   * ile aynı kurallar.
   */
  readonly beatHz?: number;
}

export interface MixerState {
  readonly layers: readonly MixerLayer[];
}

/** Tek preset'te izin verilen azami katman (CPU + headroom sınırı). */
export const MAX_MIXER_LAYERS = 8;

const MAX_LAYER_ID_LENGTH = 40;

function isLayerSource(v: unknown): v is LayerSource {
  return typeof v === 'string' && (LAYER_SOURCES as readonly string[]).includes(v);
}

export function parseLayer(input: unknown): MixerLayer | null {
  if (typeof input !== 'object' || input === null) return null;
  const { id, type, gain, frequencyHz, beatHz } = input as Record<string, unknown>;

  if (typeof id !== 'string' || id.length === 0 || id.length > MAX_LAYER_ID_LENGTH) return null;
  if (!isLayerSource(type)) return null;
  // NaN/Infinity da elenmeli: Number.isFinite hem tipi hem geçerliliği kontrol eder.
  if (typeof gain !== 'number' || !Number.isFinite(gain) || gain < 0 || gain > 1) return null;

  // `frequencyHz` sözleşmesi (yukarıdaki arayüz yorumu): tone'da ZORUNLU,
  // ton dışında YASAK. Mobil `engine_params.dart` _parseLayer ile birebir aynı
  // kurallar — iki tarafın ayrışması, kaydedilen tarifin çalınmaması demekti.
  let freq: number | undefined;
  if (frequencyHz !== undefined) {
    if (
      typeof frequencyHz !== 'number' ||
      !Number.isFinite(frequencyHz) ||
      frequencyHz < TONE_MIN_HZ ||
      frequencyHz > TONE_MAX_HZ
    ) {
      return null;
    }
    if (type !== 'tone') return null;
    freq = frequencyHz;
  }
  if (type === 'tone' && freq === undefined) return null;

  // `beatHz` (binaural vuru): tone'da OPSİYONEL (yokluk=mono), ton dışında
  // YASAK. 0 geçersizdir — mono'nun tel ifadesi alanın YOKLUĞUDUR; "0 ile
  // yokluk" iki ayrı gösterim, ileride hangisinin ne demek olduğu tartılır.
  let beat: number | undefined;
  if (beatHz !== undefined) {
    if (
      typeof beatHz !== 'number' ||
      !Number.isFinite(beatHz) ||
      type !== 'tone' ||
      beatHz < TONE_BEAT_MIN_HZ ||
      beatHz > TONE_BEAT_MAX_HZ
    ) {
      return null;
    }
    beat = beatHz;
  }

  return {
    id,
    type,
    gain,
    ...(freq !== undefined ? { frequencyHz: freq } : {}),
    ...(beat !== undefined ? { beatHz: beat } : {}),
  };
}

/**
 * Serbest JSON'u doğrulanmış [MixerState]'e çevirir; geçersizse **null**.
 * Kural: en az 1, en fazla [MAX_MIXER_LAYERS] katman; katman id'leri benzersiz.
 * Tolerans YOK — bozuk preset sessizce "kısmen" yüklenmemeli.
 */
export function parseMixerState(input: unknown): MixerState | null {
  if (typeof input !== 'object' || input === null) return null;
  const { layers } = input as Record<string, unknown>;
  const parsed = parseLayers(layers);
  return parsed === null ? null : { layers: parsed };
}

/**
 * Katman listesini doğrular. `parseMixerState` ve `parseEngineParams` ortak kullanır —
 * kural iki yerde yaşasaydı biri sessizce eskirdi (ör. MAX değişimi tek yerde kalırdı).
 */
export function parseLayers(input: unknown): MixerLayer[] | null {
  if (!Array.isArray(input)) return null;
  if (input.length === 0 || input.length > MAX_MIXER_LAYERS) return null;

  const parsed: MixerLayer[] = [];
  const seen = new Set<string>();
  for (const raw of input) {
    const layer = parseLayer(raw);
    if (!layer) return null;
    if (seen.has(layer.id)) return null; // aynı id iki kez → belirsiz mix
    seen.add(layer.id);
    parsed.push(layer);
  }
  return parsed;
}
