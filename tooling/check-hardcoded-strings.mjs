#!/usr/bin/env node
/**
 * Hard-coded kullanıcı metni taraması — CLAUDE.md §4 kapısı.
 *
 * Kural: "tüm kullanıcı metinleri baştan itibaren i18n dosyalarında (mobil: arb).
 * Hard-code string PR'da reddedilir."
 *
 * NEDEN BU SCRIPT: kural yazılıydı ama zorlanmıyordu — ~20 iterasyon boyunca
 * (#109'a kadar) sessizce ihlal edildi ve ekranlar tek tek geri taşınmak zorunda
 * kaldı. İnsan disiplinine bırakılan kural, kural değil temennidir.
 *
 * KAPSAM (bilinçli olarak dar): widget'a DOĞRUDAN literal geçen iki desen —
 * `Text('...')` ve `label: '...'`. Dar tutuldu çünkü yanlış pozitif üreten bir
 * kapı, kapatılan bir kapıdır. Yeni bir metin taşıyıcı widget çıkarsa buraya
 * eklenir (ör. `hintText:`, `tooltip:`).
 */
import { readFileSync, readdirSync, statSync, existsSync } from 'node:fs';
import { join, extname, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const ROOT = join(repoRoot, 'apps/mobile/lib');

/** l10n üretilen/kaynak dosyaları: metnin YAŞAMASI GEREKEN yer → kapsam dışı. */
const SKIP_DIRS = new Set(['l10n', '.dart_tool', 'build', 'generated']);

/**
 * Metni doğrudan literal alan desenler. `Text(l10n.x)` veya `Text(s.title('en'))`
 * eşleşmez — yalnızca ilk argümanı tırnakla BAŞLAYAN çağrılar.
 */
const PATTERNS = [
  { re: /\bText\(\s*['"]/, what: "Text('...') — literal metin" },
  { re: /\blabel:\s*['"]/, what: "label: '...' — literal buton etiketi" },
];

function isComment(line) {
  const t = line.trim();
  return t.startsWith('//') || t.startsWith('*') || t.startsWith('/*');
}

function* walk(dir) {
  if (!existsSync(dir)) return;
  for (const entry of readdirSync(dir)) {
    if (SKIP_DIRS.has(entry)) continue;
    const full = join(dir, entry);
    if (statSync(full).isDirectory()) yield* walk(full);
    else if (extname(entry) === '.dart') yield full;
  }
}

const violations = [];
for (const file of walk(ROOT)) {
  const lines = readFileSync(file, 'utf8').split(/\r?\n/);
  lines.forEach((line, i) => {
    if (isComment(line)) return;
    for (const { re, what } of PATTERNS) {
      if (re.test(line)) {
        violations.push({
          file: file.replace(repoRoot, '').replace(/\\/g, '/'),
          line: i + 1,
          what,
          text: line.trim(),
        });
        break;
      }
    }
  });
}

if (violations.length > 0) {
  console.error(`[i18n] ✗ ${violations.length} hard-coded kullanıcı metni (CLAUDE.md §4):\n`);
  for (const v of violations) {
    console.error(`  ${v.file}:${v.line}  ${v.what}\n    ${v.text}\n`);
  }
  console.error(
    'Metni apps/mobile/lib/l10n/app_en.arb içine taşı ve AppL10n.of(context).<key>\n' +
      'ile oku. Çoğul varsa ICU plural kullan — Türkçe İngilizce -s mantığını izlemez.',
  );
  process.exit(1);
}

console.log('[i18n] ✓ mobil lib/ taramasında hard-coded kullanıcı metni yok.');
