import { MAX_MIXER_LAYERS, parseLayers, type MixerLayer } from './mixer-state';

/**
 * `soundscapes.engine_params` sözleşmesi — ses TARİFİ (docs/04 §78: sunucudan MP3
 * stream edilmez, üretim on-device; engine_params yalnızca tariftir).
 *
 * ŞEMA SÜRÜMÜ ZORUNLU (docs/04 §79): "engine_params şeması versiyonludur
 * (schema_version); eski uygulama yeni şemayı görürse zarifçe eski preset'e düşer
 * (crash değil)". Sürüm olmadan eski istemci yeni alanları görüp çökerdi; sürümle
 * "bunu anlamıyorum" deyip geri düşebilir.
 *
 * VARSAYIM (bkz. DECISIONS_NEEDED D-9): tarifin TAMAMI burada — katmanlar dahil.
 * Şemadaki ikinci kolon `layer_defs`'in rolü belgede net değil ve şu an
 * KULLANILMIYOR. Bu varsayım yanlışsa katmanlar oraya taşınmalı.
 */
export const ENGINE_PARAMS_SCHEMA_VERSION = 1;

export interface EngineParams {
  readonly schemaVersion: number;
  readonly layers: readonly MixerLayer[];
}

/**
 * Serbest JSON → doğrulanmış [EngineParams]; geçersizse null.
 * Tolerans YOK: kısmen geçerli bir tarif, kullanıcının telefonunda çalma anında
 * patlar — bozuk içerik istemciye HİÇ ulaşmamalı (mixer-state.ts'teki aynı gerekçe).
 */
export function parseEngineParams(input: unknown): EngineParams | null {
  if (typeof input !== 'object' || input === null) return null;
  const { schemaVersion, layers } = input as Record<string, unknown>;

  // Sürüm zorunlu ve TANIDIĞIMIZ sürüm olmalı: ileriden gelen bir sürümü kabul edip
  // saklamak, anlamadığımız veriyi istemciye aktarmak olurdu.
  if (schemaVersion !== ENGINE_PARAMS_SCHEMA_VERSION) return null;

  const parsed = parseLayers(layers);
  if (parsed === null) return null;

  return { schemaVersion: ENGINE_PARAMS_SCHEMA_VERSION, layers: parsed };
}

export { MAX_MIXER_LAYERS };
