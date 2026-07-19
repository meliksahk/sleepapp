#!/usr/bin/env node
/**
 * İçerik kütüphanesi sürüklenme kapısı — `check-archetype-drift.mjs` deseninin aynısı.
 *
 * NEDEN: `apps/mobile/assets/content/library.json` ÜRETİLEN bir dosya ama repoya
 * COMMIT ediliyor (cihaz onu asset olarak okuyor; build anında codegen koşmuyor).
 * Commit edilen üretilmiş dosya, kaynağı değişince sessizce bayatlar.
 *
 * Bayatlamanın bedeli: seed'e yeni bir soundscape eklenir (ya da bir tarifin
 * kazancı düzeltilir), sunucu onu servis eder, ama kurulan APK eski kütüphaneyi
 * taşır. Kullanıcı için "bende yok" / "ses farklı"; geliştirici için GÖRÜNMEZ.
 *
 * Bu yüzden karşılaştırma BAYT BAYT: "aşağı yukarı aynı" diye bir şey yok.
 */
import { readFileSync, existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildLibraryJson, OUTPUT_PATH } from './gen-content-library.mjs';

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const rel = OUTPUT_PATH.replace(repoRoot, '').replace(/\\/g, '/');

if (!existsSync(OUTPUT_PATH)) {
  console.error(
    `[content-drift] ✗ ${rel} YOK.\n` +
      'Bu dosya olmadan kurulan APK\'da kütüphane BOŞ kalır (CLAUDE.md §3.1 offline-first).\n' +
      'Üretmek için: pnpm gen:content',
  );
  process.exit(1);
}

const expected = buildLibraryJson();
const actual = readFileSync(OUTPUT_PATH, 'utf8');

if (expected !== actual) {
  // İlk farklı satırı göster — "bir yerde farklı" demek hata ayıklamaz.
  const e = expected.split('\n');
  const a = actual.split('\n');
  let line = 0;
  while (line < Math.max(e.length, a.length) && e[line] === a[line]) line++;

  console.error(
    `[content-drift] ✗ ${rel} kaynağıyla UYUŞMUYOR (ilk fark: satır ${line + 1}).\n\n` +
      `  commit'li : ${a[line] ?? '<dosya bitti>'}\n` +
      `  beklenen  : ${e[line] ?? '<dosya bitti>'}\n\n` +
      'db/seed.sql (ya da sunucunun katman sözleşmesi) değişti ama cihazın gömülü\n' +
      'kütüphanesi güncellenmedi. Bu hâlde kurulan APK ile sunucu FARKLI içerik\n' +
      'gösterir ve fark yalnızca gerçek cihazda görülür.\n\n' +
      'Düzeltmek için: pnpm gen:content (ve çıkan dosyayı commit\'leyin)',
  );
  process.exit(1);
}

const parsed = JSON.parse(actual);
const presetCount = parsed.soundscapes.reduce((n, e) => n + e.presets.length, 0);
console.log(
  `[content-drift] ✓ ${rel} kaynağıyla senkron ` +
    `(${parsed.soundscapes.length} soundscape, ${presetCount} preset).`,
);
