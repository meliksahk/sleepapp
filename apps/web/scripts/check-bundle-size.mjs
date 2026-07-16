#!/usr/bin/env node
/**
 * Ana sayfa JS bütçe kapısı (CLAUDE.md §3.4 CWV bütçesi).
 *
 * NE ÖLÇER: `/` rotasının ilk yüklemede çektiği JS chunk'larının (layout + page)
 * **gzip** toplamı. Next'in build çıktısındaki "First Load JS" değerine yakındır
 * ama birebir AYNI DEĞİLDİR (Next farklı sayar) — bu yüzden eşik kendi metriğimize
 * göre kalibre edilmiştir. Amaç mutlak doğruluk değil, **regresyon yakalamak**.
 *
 * ⚠️ EŞİK, CLAUDE.md'deki 90KB HEDEFİ DEĞİLDİR.
 * Ölçüm (2026-07): ~107 kB. Bunun ~102 kB'si React 19 + Next 15 App Router
 * runtime'ı (uygulama kodu ~1 kB) → 90KB hedefi bu mimariyle ULAŞILAMAZ.
 * Karar insana bırakıldı: DECISIONS_NEEDED.md · D-6.
 * Buradaki eşik o karara kadar "sessiz büyümeyi durduran" bir bekçidir.
 */
import { readFileSync, existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { gzipSync } from 'node:zlib';

const webRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const NEXT_DIR = join(webRoot, '.next');

/** Regresyon bekçisi eşiği (kB, gzip). CLAUDE.md hedefi değil — bkz. D-6. */
const GUARD_KB = 115;

/** Bir rotanın ilk-yükleme JS chunk'larının gzip toplamı (kB). */
export function firstLoadKb(manifest, readFile) {
  const files = new Set([...(manifest.pages['/layout'] ?? []), ...(manifest.pages['/page'] ?? [])]);
  let bytes = 0;
  for (const f of files) {
    if (!f.endsWith('.js')) continue;
    const content = readFile(f);
    if (content === null) continue;
    bytes += gzipSync(content).length;
  }
  return bytes / 1000;
}

const manifestPath = join(NEXT_DIR, 'app-build-manifest.json');
if (!existsSync(manifestPath)) {
  console.error('[size] .next/app-build-manifest.json yok — önce `next build` çalıştır.');
  process.exit(1);
}

const manifest = JSON.parse(readFileSync(manifestPath, 'utf8'));
const kb = firstLoadKb(manifest, (f) => {
  const p = join(NEXT_DIR, f);
  return existsSync(p) ? readFileSync(p) : null;
});

const rounded = kb.toFixed(1);
if (kb > GUARD_KB) {
  console.error(
    `[size] ✗ Ana sayfa JS ${rounded} kB > bekçi eşiği ${GUARD_KB} kB (gzip).\n` +
      '       Yeni bir bağımlılık mı eklendi? Bütçe bağlamı: DECISIONS_NEEDED.md · D-6.',
  );
  process.exit(1);
}
console.log(`[size] ✓ Ana sayfa JS ${rounded} kB ≤ ${GUARD_KB} kB (gzip, regresyon bekçisi).`);
