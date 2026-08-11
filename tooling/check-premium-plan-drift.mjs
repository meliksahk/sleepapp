#!/usr/bin/env node
/**
 * Premium sınırı sürüklenme kapısı (F5) — `check-layer-source-drift.mjs` deseni.
 *
 * NEDEN: "hangi özellik premium" listesi İKİ yerde yaşamak zorunda, çünkü
 * `apps/*` birbirini import edemez (CLAUDE.md §2):
 *   1. mobil : apps/mobile/lib/features/entitlement/premium_plan.dart (enum + sabitler)
 *   2. panel : apps/admin/src/features/plan/premium-plan.ts            (PREMIUM_FEATURES)
 *
 * Ayrışırsa hata SESSİZDİR ve pahalıdır: panelde "premium" görünen bir özellik
 * uygulamada ücretsiz kalır (ya da tersi) — yani ekibin fiyat vaadi ile ürünün
 * davranışı ayrışır. Deneme süresi ve ücretsiz kotalar da aynı sebeple kilitli.
 *
 * Karşılaştırma SIRA DAHİL: paywall listesi bu sırayla çiziliyor.
 */
import { readFileSync, existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), '..');

const DART = 'apps/mobile/lib/features/entitlement/premium_plan.dart';
const ADMIN = 'apps/admin/src/features/plan/premium-plan.ts';

function read(rel) {
  const p = join(repoRoot, rel);
  if (!existsSync(p)) {
    console.error(`[premium-plan-drift] ✗ ${rel} YOK.`);
    process.exit(1);
  }
  return readFileSync(p, 'utf8');
}

function fail(message) {
  console.error(`[premium-plan-drift] ✗ ${message}`);
  process.exit(1);
}

/** `enum PremiumFeature { a, b }` gövdesindeki adlar (yorumlar atılır). */
function parseDartEnum(src) {
  const m = src.match(/enum\s+PremiumFeature\s*\{([\s\S]*?)\n\}/);
  if (!m) fail(`${DART} içinde 'enum PremiumFeature' bulunamadı.`);
  return m[1]
    .replace(/\/\/\/.*$/gm, '')
    .replace(/\/\/.*$/gm, '')
    .split(',')
    .map((s) => s.trim())
    .filter((s) => /^[a-zA-Z_][a-zA-Z0-9_]*$/.test(s));
}

/** `export const PREMIUM_FEATURES = [...] as const;` içindeki dizgiler. */
function parseTsList(src) {
  const m = src.match(/export const PREMIUM_FEATURES\s*=\s*\[([\s\S]*?)\]\s*as const/);
  if (!m) fail(`${ADMIN} içinde 'PREMIUM_FEATURES' dizisi bulunamadı.`);
  return [...m[1].matchAll(/'([^']+)'/g)].map((x) => x[1]);
}

/** `const int kAd = 7;` / `export const AD = 7;` sayısı. */
function num(src, re, where) {
  const m = src.match(re);
  if (!m) fail(`${where} içinde sayı bulunamadı: ${re}`);
  return Number(m[1]);
}

const dartSrc = read(DART);
const adminSrc = read(ADMIN);

const dart = parseDartEnum(dartSrc);
const admin = parseTsList(adminSrc);

if (dart.length !== admin.length || dart.some((v, i) => v !== admin[i])) {
  console.error('[premium-plan-drift] ✗ mobil ile panel UYUŞMUYOR.\n');
  console.error(`  mobil : ${dart.join(', ')}`);
  console.error(`  panel : ${admin.join(', ')}\n`);
  console.error('İki liste aynı adları AYNI SIRADA taşımalı.');
  process.exit(1);
}

const pairs = [
  ['deneme günü', num(dartSrc, /kTrialDays\s*=\s*(\d+)/, DART), num(adminSrc, /TRIAL_DAYS\s*=\s*(\d+)/, ADMIN)],
  [
    'ücretsiz kütüphane',
    num(dartSrc, /kFreeLibrarySize\s*=\s*(\d+)/, DART),
    num(adminSrc, /FREE_LIBRARY_SIZE\s*=\s*(\d+)/, ADMIN),
  ],
  [
    'ücretsiz mix',
    num(dartSrc, /kFreeMixSlots\s*=\s*(\d+)/, DART),
    num(adminSrc, /FREE_MIX_SLOTS\s*=\s*(\d+)/, ADMIN),
  ],
];

for (const [label, a, b] of pairs) {
  if (a !== b) fail(`${label} ayrışmış: mobil ${a}, panel ${b}.`);
}

console.log(
  `[premium-plan-drift] ✓ mobil/panel senkron (${dart.length} premium özellik, ` +
    `${pairs[0][1]} gün deneme, ücretsiz ${pairs[1][1]} ses / ${pairs[2][1]} mix).`,
);
