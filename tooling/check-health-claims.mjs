#!/usr/bin/env node
/**
 * Sağlık iddiası taraması — CLAUDE.md §1.1 kapısı.
 *
 * Kural: "Hiçbir yerde (kod, UI metni, store metni, site, push) 'tedavi',
 * 'treatment', 'cures', '%100 science-backed' tarzı ifade kullanılmaz.
 * Konumlandırma: relaxation & sleep ritual. Bu bir UYUM (FTC/App Store/reklam
 * kurulu) ve itibar kuralıdır; metin üreten her PR'da kontrol edilir."
 *
 * Bu kural şimdiye dek yalnızca web'in birkaç testinde (JSON-LD + archetype
 * içeriği) zorlanıyordu; MOBİL metinler, API açıklamaları ve llms.txt hiç
 * taranmıyordu. Bu script kuralı depo genelinde makineleştirir.
 *
 * KAPSAM: kullanıcıya ulaşabilen kaynaklar. YORUM SATIRLARI ATLANIR — yorum
 * kullanıcıya gösterilmez ve kuralın kendisini belgeleyen yorumlar ("cure/treat
 * kullanma") aksi halde yanlış pozitif olurdu. Test dosyaları da atlanır: onlar
 * yasak kelimeleri BİLEREK içerir (yokluğunu iddia etmek için).
 */
import { readFileSync, readdirSync, statSync, existsSync } from 'node:fs';
import { join, extname, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), '..');

/** Taranan kökler — kullanıcıya ulaşan metnin yaşadığı yerler. */
const ROOTS = [
  'apps/mobile/lib',
  'apps/web/src',
  'apps/admin/src',
  'apps/api/src',
  'packages/ui/src',
];
/** Ek tekil dosyalar (AI/arama yüzeyi). */
const FILES = ['apps/web/public/llms.txt'];

const EXTENSIONS = new Set(['.dart', '.ts', '.tsx', '.js', '.jsx', '.txt', '.md']);
const SKIP_DIRS = new Set(['node_modules', '.next', 'generated', 'build', '.dart_tool']);

/**
 * Yasak ifadeler. UYDURULMADI: CLAUDE.md §1.1'in verdiği örnekler + mevcut web
 * testlerinin (schema.test.ts, archetypes.test.ts) hâlihazırda kullandığı kümenin
 * birleşimi. Yeni kelime eklemek ürün/hukuk kararıdır — buraya sessizce eklenmez.
 */
const BANNED = [
  /\bcures?\b/i,
  /\bcured\b/i,
  /\btreats?\b/i,
  /\btreatments?\b/i,
  /\btherapy\b/i,
  /\btherapeutic\b/i,
  /\bclinical(ly)?\b/i,
  /\bmedical(ly)?\b/i,
  /\bdiseases?\b/i,
  /\btedavi\b/i,
  /science[- ]backed/i,
  /doctor[- ]approved/i,
];

/**
 * İNCELENMİŞ İSTİSNALAR — yasak kelimeyi **olumsuzlama/feragat** için içeren satırlar.
 * Bunlar sağlık iddiası DEĞİL, iddianın açık REDDİ; hukuken değerli metin ve
 * silmek zarar verirdi (kapıyı geçirmek için feragat silinmez).
 *
 * TAM SATIR eşleşmesi bilinçli: metin bir karakter bile değişirse kapı yeniden
 * düşer → istisna otomatik yenilenmez, insan yeniden inceler.
 */
const REVIEWED_DISCLAIMERS = new Set([
  '> generative sound engine. Relaxation and ritual — not a medical product.',
  '- Positioned as a relaxation and sleep ritual, with no health or treatment claims.',
  '- NOCTA is a "sleep ritual app". It does not diagnose, treat, or cure anything.',
]);

/** Yorum satırı mı? (yorum kullanıcıya gösterilmez → kapsam dışı) */
function isComment(line) {
  const t = line.trim();
  return t.startsWith('//') || t.startsWith('*') || t.startsWith('/*') || t.startsWith('#');
}

function isTestFile(path) {
  return /\.(spec|test)\.[tj]sx?$/.test(path) || /_test\.dart$/.test(path);
}

function* walk(dir) {
  if (!existsSync(dir)) return;
  for (const entry of readdirSync(dir)) {
    if (SKIP_DIRS.has(entry)) continue;
    const full = join(dir, entry);
    if (statSync(full).isDirectory()) yield* walk(full);
    else if (EXTENSIONS.has(extname(entry))) yield full;
  }
}

const targets = [
  ...ROOTS.flatMap((r) => [...walk(join(repoRoot, r))]),
  ...FILES.map((f) => join(repoRoot, f)).filter((f) => existsSync(f)),
];

const violations = [];
for (const file of targets) {
  if (isTestFile(file)) continue;
  const lines = readFileSync(file, 'utf8').split(/\r?\n/);
  lines.forEach((line, i) => {
    if (isComment(line)) return;
    if (REVIEWED_DISCLAIMERS.has(line.trim())) return;
    for (const re of BANNED) {
      if (re.test(line)) {
        violations.push({ file: file.replace(repoRoot, '').replace(/\\/g, '/'), line: i + 1, text: line.trim() });
        break;
      }
    }
  });
}

if (violations.length > 0) {
  console.error(`[health-claims] ✗ ${violations.length} olası sağlık iddiası (CLAUDE.md §1.1):\n`);
  for (const v of violations) {
    console.error(`  ${v.file}:${v.line}\n    ${v.text}\n`);
  }
  console.error(
    'Konumlandırma "relaxation & sleep ritual" olmalı. Bu bir UYUM kuralıdır\n' +
      '(FTC/App Store/reklam kurulu) — metni değiştir, kapıyı gevşetme.',
  );
  process.exit(1);
}

console.log(`[health-claims] ✓ ${targets.length} dosya tarandı, sağlık iddiası yok.`);
