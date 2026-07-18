#!/usr/bin/env node
/**
 * Arketip matrisi sürüklenme kapısı — `check-env-example.mjs` deseninin aynısı.
 *
 * NEDEN: `apps/mobile/assets/archetype/matrix.json` ÜRETİLEN bir dosya ama repoya
 * COMMIT ediliyor (cihaz onu asset olarak okuyor; build anında codegen koşmuyor).
 * Commit edilen üretilmiş dosya, kaynağı değişince sessizce bayatlar. Burada
 * bayatlamanın bedeli ağır: sunucu matrisi değişir, cihaz eski matriste kalır ve
 * AYNI cevaplar iki uygulamada FARKLI arketip üretir. Kullanıcı için felaket,
 * geliştirici için görünmez.
 *
 * Bu yüzden karşılaştırma BAYT BAYT: "aşağı yukarı aynı" diye bir şey yok.
 */
import { readFileSync, existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildMatrixJson, OUTPUT_PATH } from './gen-archetype-matrix.mjs';

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const rel = OUTPUT_PATH.replace(repoRoot, '').replace(/\\/g, '/');

if (!existsSync(OUTPUT_PATH)) {
  console.error(
    `[archetype-drift] ✗ ${rel} YOK.\n` +
      'Bu dosya olmadan uygulama arketip testini cihazda koşamaz.\n' +
      'Üretmek için: pnpm gen:archetype',
  );
  process.exit(1);
}

const expected = buildMatrixJson();
const actual = readFileSync(OUTPUT_PATH, 'utf8');

if (expected !== actual) {
  // İlk farklı satırı göster — "bir yerde farklı" demek hata ayıklamaz.
  const e = expected.split('\n');
  const a = actual.split('\n');
  let line = 0;
  while (line < Math.max(e.length, a.length) && e[line] === a[line]) line++;

  console.error(
    `[archetype-drift] ✗ ${rel} kaynağıyla UYUŞMUYOR (ilk fark: satır ${line + 1}).\n\n` +
      `  commit'li : ${a[line] ?? '<dosya bitti>'}\n` +
      `  beklenen  : ${e[line] ?? '<dosya bitti>'}\n\n` +
      'Sunucu matrisi (apps/api/src/modules/archetype/domain/) değişti ama cihazın\n' +
      'kopyası güncellenmedi. Bu hâlde AYNI cevaplar sunucuda ve cihazda FARKLI\n' +
      'arketip üretebilir.\n\n' +
      'Düzeltmek için: pnpm gen:archetype (ve çıkan dosyayı commit\'leyin)',
  );
  process.exit(1);
}

const parsed = JSON.parse(actual);
console.log(
  `[archetype-drift] ✓ ${rel} kaynağıyla senkron ` +
    `(${parsed.questions.length} soru, ${parsed.vectors.length} doğrulama vektörü).`,
);
