#!/usr/bin/env node
/**
 * İçerik kütüphanesi codegen: `db/seed.sql` → `apps/mobile/assets/content/library.json`.
 *
 * ## NEDEN VAR
 *
 * Kütüphane (soundscape'ler + preset'ler + haftalık yayın) SUNUCUDA yaşıyordu:
 * `content_controller.dart`'ta üç uç da KOŞULSUZ ağa gidiyordu ve yerel yedek
 * YOKTU. `api.nocta.app` ayakta olmadığı için kurulan prod APK'da kütüphane
 * BOŞTU — kullanıcı "Kütüphane"ye giriyor, hata ekranı görüyordu. Bu, CLAUDE.md
 * §3.1'in "uygulama offline-first: ses üretimi ve mikser internetsiz tam çalışır"
 * kuralının doğrudan ihlaliydi.
 *
 * Üstelik #215'te eklenen "Hearth & Static" (müzik + gürültü + efekt bir arada
 * olan TEK referans tarif) yalnızca seed'de yaşıyordu: motorun pad/fire yeteneği
 * kullanıcının kuracağı APK'da HİÇ görünmüyordu.
 *
 * Çözüm kütüphaneyi cihaza almak. Ama tarifleri Dart'a ELLE kopyalamak, sunucu
 * ile cihazın sessizce ayrışması demekti (arketip matrisinde yaşanan sorunun
 * aynısı). Bu yüzden tek kaynak (`db/seed.sql`) korunur ve cihazın kopyası
 * ÜRETİLİR — `gen-archetype-matrix.mjs` + `check-archetype-drift.mjs` deseninin
 * birebir aynısı.
 *
 * ## KAYNAK SEÇİMİ VE AYRIŞTIRMA YÖNTEMİ
 *
 * Kaynak `db/seed.sql`; ayrıştırma gerçek bir SQL sözcükleyicisiyle yapılır
 * (`sql-values.mjs`). Regex'in neden yetersiz, "seed'i çalıştırıp DB'den okumak"
 * yolunun neden reddedildiği (determinizm + CI'da Docker bağımlılığı) o dosyanın
 * başlığında ayrıntılı yazılı.
 *
 * ## DOĞRULAMA
 *
 * Üretilen her tarif, SUNUCUNUN sözleşmesine göre (LAYER_SOURCES +
 * MAX_MIXER_LAYERS, `apps/api/.../mixer-state.ts`'ten OKUNUR — burada elle
 * yazılmaz) doğrulanır. Geçersiz bir tarif sessizce atlanmaz: üretim PATLAR.
 * Sebep: cihazdaki `parseEngineParams` geçersiz tarifi null'a çevirir ve
 * kullanıcı "ses gelmiyor" olarak yaşar — bu, CI'da yakalanması gereken bir hata.
 */
import { readFileSync, existsSync, mkdirSync, writeFileSync } from 'node:fs';
import { join, dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { tokenize, splitStatements, parseInsert, parsePgTextArray } from './sql-values.mjs';

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), '..');

const SEED_PATH = join(repoRoot, 'db/seed.sql');
const MIXER_STATE_PATH = join(repoRoot, 'apps/api/src/modules/content/domain/mixer-state.ts');
const MIGRATION_PATH = join(repoRoot, 'db/migrations/20260715120005_add_content.sql');

export const OUTPUT_PATH = join(repoRoot, 'apps/mobile/assets/content/library.json');

/**
 * Gömülü kütüphanenin biçim sürümü. Cihaz bunu tanımıyorsa asset'i REDDEDER
 * (`content_library_source.dart`). Alan yapısı değişirse burası artar.
 */
const LIBRARY_SCHEMA_VERSION = 1;

// ─────────────────────────────────────────────────────────────────────────────
// Sunucu sözleşmesini OKU (elle kopyalama yok — `check-layer-source-drift.mjs`
// ile aynı okuma deseni).
// ─────────────────────────────────────────────────────────────────────────────

function readServerContract() {
  const src = readFileSync(MIXER_STATE_PATH, 'utf8');

  const sourcesMatch = src.match(/export const LAYER_SOURCES\s*=\s*\[([\s\S]*?)\]\s*as const/);
  if (!sourcesMatch) {
    throw new Error(`[content-library] ✗ LAYER_SOURCES bulunamadı: ${MIXER_STATE_PATH}`);
  }
  const layerSources = [...sourcesMatch[1].matchAll(/'([^']+)'/g)].map((m) => m[1]);

  const maxMatch = src.match(/export const MAX_MIXER_LAYERS\s*=\s*(\d+)/);
  if (!maxMatch) {
    throw new Error(`[content-library] ✗ MAX_MIXER_LAYERS bulunamadı: ${MIXER_STATE_PATH}`);
  }

  return { layerSources, maxLayers: Number(maxMatch[1]) };
}

/**
 * `soundscapes.version` sütununun DEFAULT değeri. Seed satırları `version`
 * yazmıyor → DB varsayılanı geçerli. Sabit `1` yazmak, migration bir gün
 * varsayılanı değiştirdiğinde sessizce yanlış olurdu.
 */
function readVersionDefault() {
  const src = readFileSync(MIGRATION_PATH, 'utf8');
  const m = src.match(/version\s+int\s+NOT NULL\s+DEFAULT\s+(\d+)/i);
  if (!m) {
    throw new Error(
      `[content-library] ✗ soundscapes.version DEFAULT değeri okunamadı: ${MIGRATION_PATH}`,
    );
  }
  return Number(m[1]);
}

// ─────────────────────────────────────────────────────────────────────────────
// Tarif doğrulama — `apps/api/.../mixer-state.ts` parseLayers ile aynı kurallar.
// ─────────────────────────────────────────────────────────────────────────────

function assertValidLayers(layers, contract, context) {
  if (!Array.isArray(layers)) throw new Error(`[content-library] ✗ ${context}: layers dizi değil.`);
  if (layers.length === 0 || layers.length > contract.maxLayers) {
    throw new Error(
      `[content-library] ✗ ${context}: katman sayısı ${layers.length} — 1..${contract.maxLayers} olmalı.`,
    );
  }
  const seen = new Set();
  for (const layer of layers) {
    if (typeof layer?.id !== 'string' || layer.id === '') {
      throw new Error(`[content-library] ✗ ${context}: katman id'si dizgi olmalı.`);
    }
    if (seen.has(layer.id)) {
      throw new Error(`[content-library] ✗ ${context}: tekrar eden katman id'si "${layer.id}".`);
    }
    seen.add(layer.id);
    if (!contract.layerSources.includes(layer.type)) {
      throw new Error(
        `[content-library] ✗ ${context}: bilinmeyen katman tipi "${layer.type}". ` +
          `Tanınanlar: ${contract.layerSources.join(', ')}. ` +
          'Cihazdaki motor bu tarifi TAMAMEN reddederdi (ses gelmezdi).',
      );
    }
    if (typeof layer.gain !== 'number' || !Number.isFinite(layer.gain) || layer.gain < 0 || layer.gain > 1) {
      throw new Error(`[content-library] ✗ ${context}: gain ∈ [0,1] olmalı (${layer.gain}).`);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/** Üretilecek JSON'u (string olarak) döndürür. Drift kapısı da bunu çağırır. */
export function buildLibraryJson() {
  if (!existsSync(SEED_PATH)) {
    throw new Error(`[content-library] ✗ kaynak yok: ${SEED_PATH}`);
  }

  const contract = readServerContract();
  const versionDefault = readVersionDefault();

  const statements = splitStatements(tokenize(readFileSync(SEED_PATH, 'utf8')));
  const inserts = { soundscapes: [], presets: [], weekly_releases: [] };
  for (const statement of statements) {
    const parsed = parseInsert(statement);
    if (parsed && parsed.table in inserts) inserts[parsed.table].push(...parsed.rows);
  }

  if (inserts.soundscapes.length === 0) {
    throw new Error('[content-library] ✗ seed.sql içinde soundscapes INSERT bulunamadı.');
  }

  // ── Soundscape'ler ────────────────────────────────────────────────────────
  // YALNIZCA 'published': sunucunun `findPublished()` yolunun aynısı. Taslak bir
  // tarifi APK'ya gömmek, "yayınlamadım" diyen editörün kararını çiğnerdi.
  const byId = new Map();
  const entries = [];
  for (const row of inserts.soundscapes) {
    if (row.status !== 'published') continue;

    const context = `soundscape "${row.slug}"`;
    const engineParams = row.engine_params;
    if (typeof engineParams !== 'object' || engineParams === null) {
      throw new Error(`[content-library] ✗ ${context}: engine_params nesne değil.`);
    }
    assertValidLayers(engineParams.layers, contract, context);

    const soundscape = {
      id: row.id,
      slug: row.slug,
      titleI18n: row.title_i18n,
      archetypeAffinity: parsePgTextArray(row.archetype_affinity, context),
      // Seed `version` yazmıyor → sütun DEFAULT'u. Yazarsa ona saygı duyulur.
      version: typeof row.version === 'number' ? row.version : versionDefault,
      engineParams,
    };

    // Cihaz tarafı `SoundscapeDetail.fromJson` ile birebir aynı biçim — model
    // kodu yeniden kullanılabilsin diye (ayrı bir ayrıştırıcı = ayrı bir hata
    // yüzeyi). previewUrl daima null: seed'de önizleme nesnesi yok ve zaten
    // gömülü kütüphanenin ağa çıkmama sözü var.
    const entry = { soundscape, presets: [], previewUrl: null };
    byId.set(row.id, entry);
    entries.push(entry);
  }

  // ── Preset'ler ────────────────────────────────────────────────────────────
  for (const row of inserts.presets) {
    const entry = byId.get(row.soundscape_id);
    if (entry === undefined) {
      // Yayınlanmamış/olmayan bir soundscape'e preset — sessizce atlamak yerine
      // duruyoruz: bu, seed'de gerçek bir tutarsızlıktır.
      throw new Error(
        `[content-library] ✗ preset, yayınlanmış bir soundscape'e ait değil: ${row.soundscape_id} ` +
          `(archetype: ${row.archetype_slug}).`,
      );
    }
    const context = `preset "${entry.soundscape.slug}/${row.archetype_slug}"`;
    const mixerState = row.mixer_state;
    if (typeof mixerState !== 'object' || mixerState === null) {
      throw new Error(`[content-library] ✗ ${context}: mixer_state nesne değil.`);
    }
    assertValidLayers(mixerState.layers, contract, context);
    entry.presets.push({ archetypeSlug: row.archetype_slug, mixerState });
  }

  // Determinizm: preset sırası seed'deki INSERT sırasına bağlı kalmasın diye
  // archetype slug'ına göre sıralanır (kapı bayt bayt karşılaştırıyor).
  for (const entry of entries) {
    entry.presets.sort((a, b) => a.archetypeSlug.localeCompare(b.archetypeSlug, 'en'));
  }

  // ── Haftalık yayın ────────────────────────────────────────────────────────
  //
  // `week_start` BİLEREK ÜRETİLMİYOR. Seed'de `date_trunc('week', now())::date`
  // yazıyor, yani "içinde bulunulan haftanın pazartesisi" — bir TARİH değil bir
  // KURAL. O tarihi üretim anında dondurmak iki şeyi bozardı: (1) çıktı her hafta
  // değişir, bayt bayt karşılaştıran drift kapısı sürekli kırmızı yanardı;
  // (2) APK'daki yayın, kurulumdan haftalar sonra "geçmiş hafta" görünürdü.
  // Kural cihazda uygulanır (`content_library_source.dart`).
  const weeklyRow = inserts.weekly_releases.at(-1) ?? null;
  let weekly = null;
  if (weeklyRow !== null) {
    const ids = weeklyRow.soundscape_ids;
    if (!Array.isArray(ids)) {
      throw new Error('[content-library] ✗ weekly_releases.soundscape_ids dizi değil.');
    }
    const slugs = ids.map((id) => {
      const entry = byId.get(id);
      if (entry === undefined) {
        throw new Error(
          `[content-library] ✗ haftalık yayın, yayınlanmamış/olmayan bir soundscape'e işaret ediyor: ${id}.`,
        );
      }
      return entry.soundscape.slug;
    });
    weekly = { notes: weeklyRow.notes ?? null, soundscapeSlugs: slugs };
  }

  const payload = {
    $generated:
      'ÜRETİLEN DOSYA — ELLE DÜZENLEMEYİN. Kaynak: db/seed.sql. ' +
      'Yeniden üretmek için: pnpm gen:content',
    schemaVersion: LIBRARY_SCHEMA_VERSION,
    soundscapes: entries,
    weekly,
  };

  // Sondaki `\n`: POSIX metin dosyası kuralı + git diff gürültüsünü keser.
  return `${JSON.stringify(payload, null, 2)}\n`;
}

/** CLI: `node tooling/gen-content-library.mjs` */
function main() {
  const json = buildLibraryJson();
  mkdirSync(dirname(OUTPUT_PATH), { recursive: true });
  writeFileSync(OUTPUT_PATH, json, 'utf8');
  const parsed = JSON.parse(json);
  const presetCount = parsed.soundscapes.reduce((n, e) => n + e.presets.length, 0);
  console.log(
    `[content-library] ✓ ${parsed.soundscapes.length} soundscape · ${presetCount} preset · ` +
      `haftalık yayın: ${parsed.weekly ? `${parsed.weekly.soundscapeSlugs.length} parça` : 'yok'} → ` +
      OUTPUT_PATH.replace(repoRoot, '').replace(/\\/g, '/'),
  );
}

if (process.argv[1] && resolve(process.argv[1]) === resolve(fileURLToPath(import.meta.url))) {
  main();
}
