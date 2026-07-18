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

/**
 * Ana sayfanın manifest anahtarları. `(en)` bir ROTA GRUBUDUR: URL `/` olarak kalır
 * ama manifest anahtarı dosya yolunu izler → `/(en)/page`. TR eklenirken bu değişti.
 */
const LAYOUT_KEY = '/(en)/layout';
const PAGE_KEY = '/(en)/page';

/**
 * KAPI KORUMASI: manifest'te beklenen anahtar yoksa HATA VER.
 *
 * Bu koruma olmadan kapı SESSİZCE ölürdü: `manifest.pages['/page']` yoksa
 * `?? []` boş küme döner, toplam 0 kB çıkar ve eşik daima "geçer". Rota grubu
 * eklemek/silmek (tam da bu PR'ın yaptığı) anahtarları değiştirdiği için bu
 * senaryo teorik değil — bir kez gerçekten olabilirdi.
 */
export function assertExpectedKeys(manifest) {
  const missing = [LAYOUT_KEY, PAGE_KEY].filter((k) => !Array.isArray(manifest.pages?.[k]));
  if (missing.length === 0) return;
  const available = Object.keys(manifest.pages ?? {}).sort().join('\n         ');
  throw new Error(
    `Manifest'te beklenen ana sayfa anahtarı yok: ${missing.join(', ')}.\n` +
      '       Rota yapısı değişmiş olabilir (rota grubu eklendi/silindi/yeniden adlandırıldı).\n' +
      '       check-bundle-size.mjs içindeki LAYOUT_KEY/PAGE_KEY sabitlerini güncelle —\n' +
      '       aksi hâlde bu bütçe kapısı sessizce ölçüm yapmadan yeşil geçer.\n' +
      `       Manifest'teki anahtarlar:\n         ${available}`,
  );
}

/** Bir rotanın ilk-yükleme JS chunk'larının gzip toplamı (kB). */
export function firstLoadKb(manifest, readFile) {
  assertExpectedKeys(manifest);
  const files = new Set([...manifest.pages[LAYOUT_KEY], ...manifest.pages[PAGE_KEY]]);
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
let kb;
try {
  kb = firstLoadKb(manifest, (f) => {
    const p = join(NEXT_DIR, f);
    return existsSync(p) ? readFileSync(p) : null;
  });
} catch (err) {
  console.error(`[size] ✗ ${err instanceof Error ? err.message : String(err)}`);
  process.exit(1);
}

const rounded = kb.toFixed(1);
if (kb > GUARD_KB) {
  console.error(
    `[size] ✗ Ana sayfa JS ${rounded} kB > bekçi eşiği ${GUARD_KB} kB (gzip).\n` +
      '       Yeni bir bağımlılık mı eklendi? Bütçe bağlamı: DECISIONS_NEEDED.md · D-6.',
  );
  process.exit(1);
}
console.log(`[size] ✓ Ana sayfa JS ${rounded} kB ≤ ${GUARD_KB} kB (gzip, regresyon bekçisi).`);
