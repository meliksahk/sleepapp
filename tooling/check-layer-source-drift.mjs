#!/usr/bin/env node
/**
 * Katman kaynağı (LayerSource) sürüklenme kapısı — `check-archetype-drift.mjs`
 * deseninin aynısı, üç taraflı hâli.
 *
 * NEDEN: mikserin çalabildiği kaynak listesi ÜÇ yerde yaşamak ZORUNDA, çünkü
 * `apps/*` birbirini import edemez (CLAUDE.md §2):
 *   1. mobil  : apps/mobile/lib/core/audio_engine/dsp/mix_render.dart (enum)
 *   2. sunucu : apps/api/src/modules/content/domain/mixer-state.ts   (LAYER_SOURCES)
 *   3. panel  : apps/admin/src/features/content/recipe-form.ts       (LAYER_SOURCES)
 *
 * Üçü ayrışınca hata SESSİZDİR ve en pahalı yerde patlar:
 * - panel > sunucu ise: editör listede gördüğü tipi seçer, kaydet 400 döner;
 * - sunucu > mobil ise: tarif kaydedilir, mağazadaki uygulama onu tanımaz ve
 *   `parseEngineParams` TÜM tarifi reddeder → kullanıcı sesi açar, SES GELMEZ.
 * İkincisi bir kullanıcı hatası olarak görünür ve haftalarca fark edilmez.
 *
 * Karşılaştırma SIRA DAHİL: liste sırası OpenAPI enum'una ve panel açılır
 * menüsüne yansır; "aynı küme ama farklı sıra" da bir ayrışmadır.
 */
import { readFileSync, existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), '..');

const DART = 'apps/mobile/lib/core/audio_engine/dsp/mix_render.dart';
const API = 'apps/api/src/modules/content/domain/mixer-state.ts';
const ADMIN = 'apps/admin/src/features/content/recipe-form.ts';

function read(rel) {
  const p = join(repoRoot, rel);
  if (!existsSync(p)) {
    console.error(`[layer-source-drift] ✗ ${rel} YOK.`);
    process.exit(1);
  }
  return readFileSync(p, 'utf8');
}

/** `enum LayerSource { a, b, c }` gövdesindeki adlar. */
function parseDartEnum(src, rel) {
  const m = src.match(/enum\s+LayerSource\s*\{([^}]*)\}/);
  if (!m) {
    console.error(`[layer-source-drift] ✗ ${rel} içinde 'enum LayerSource' bulunamadı.`);
    process.exit(1);
  }
  return m[1]
    .split(',')
    .map((s) => s.replace(/\/\/.*$/gm, '').trim())
    .filter((s) => s.length > 0);
}

/** `export const LAYER_SOURCES = [...] as const;` içindeki dizgiler. */
function parseTsList(src, rel) {
  const m = src.match(/export const LAYER_SOURCES\s*=\s*\[([\s\S]*?)\]\s*as const/);
  if (!m) {
    console.error(`[layer-source-drift] ✗ ${rel} içinde 'LAYER_SOURCES' dizisi bulunamadı.`);
    process.exit(1);
  }
  return [...m[1].matchAll(/'([^']+)'/g)].map((x) => x[1]);
}

const dart = parseDartEnum(read(DART), DART);
const api = parseTsList(read(API), API);
const admin = parseTsList(read(ADMIN), ADMIN);

/** İlk farkı göster — "bir yerde farklı" demek hata ayıklamaz. */
function firstDiff(a, b) {
  const n = Math.max(a.length, b.length);
  for (let i = 0; i < n; i++) {
    if (a[i] !== b[i]) return i;
  }
  return -1;
}

let failed = false;
for (const [nameA, listA, nameB, listB] of [
  ['mobil', dart, 'sunucu', api],
  ['sunucu', api, 'panel', admin],
]) {
  const i = firstDiff(listA, listB);
  if (i !== -1) {
    failed = true;
    console.error(
      `[layer-source-drift] ✗ ${nameA} ile ${nameB} UYUŞMUYOR (ilk fark: ${i + 1}. öğe).\n\n` +
        `  ${nameA.padEnd(7)}: ${listA.join(', ') || '<boş>'}\n` +
        `  ${nameB.padEnd(7)}: ${listB.join(', ') || '<boş>'}\n\n` +
        'Üç listenin de (mobil enum, sunucu LAYER_SOURCES, panel LAYER_SOURCES)\n' +
        'aynı adları AYNI SIRADA taşıması gerekir.',
    );
  }
}

if (failed) process.exit(1);

console.log(
  `[layer-source-drift] ✓ mobil/sunucu/panel senkron (${dart.length} kaynak: ${dart.join(', ')}).`,
);
