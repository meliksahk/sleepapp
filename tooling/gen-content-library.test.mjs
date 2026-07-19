/**
 * `gen-content-library.mjs` + `check-content-drift.mjs` testleri.
 *
 * Çalıştır: `pnpm test:tooling` (dosya AÇIKÇA listelenir — `node --test tooling/`
 * gerçek script'leri ÇALIŞTIRIRDI).
 *
 * İki şeyi kanıtlıyor:
 *   1. SQL okuyucusu, regex'in sessizce yanlış okuyacağı girdileri doğru okuyor.
 *   2. Drift kapısı bozulmuş bir asset'te GERÇEKTEN exit 1 veriyor — kapının
 *      kendisi test edilmezse "kapı var" demek bir temenniden ibaret.
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { readFileSync, writeFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

import { tokenize, splitStatements, parseInsert, parsePgTextArray } from './sql-values.mjs';
import { buildLibraryJson, OUTPUT_PATH } from './gen-content-library.mjs';

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), '..');

test('SQL okuyucu: yorum içindeki parantez/virgül demeti bozmaz', () => {
  const sql = `
    -- Bir yorum: (parantez, virgül) ve hatta VALUES kelimesi
    INSERT INTO t (a, b) VALUES
      /* blok yorum ( , VALUES */
      ('x', 1),
      ('y', 2);
  `;
  const [statement] = splitStatements(tokenize(sql));
  const parsed = parseInsert(statement);
  assert.deepEqual(parsed.rows, [
    { a: 'x', b: 1 },
    { a: 'y', b: 2 },
  ]);
});

test('SQL okuyucu: kaçırılmış kesme işareti dizgiyi bölmez', () => {
  const sql = "INSERT INTO t (a) VALUES ('Gece''nin Sesi');";
  const [statement] = splitStatements(tokenize(sql));
  assert.equal(parseInsert(statement).rows[0].a, "Gece'nin Sesi");
});

test('SQL okuyucu: ::jsonb dönüşümü gerçekten JSON üretir', () => {
  const sql = `INSERT INTO t (p) VALUES ('{"layers": [{"gain": 0.5}]}'::jsonb);`;
  const [statement] = splitStatements(tokenize(sql));
  assert.deepEqual(parseInsert(statement).rows[0].p, { layers: [{ gain: 0.5 }] });
});

test('SQL okuyucu: SELECT ... FROM (VALUES ...) AS v (...) biçimi', () => {
  const sql = `
    INSERT INTO presets (a, b)
    SELECT v.a, v.b FROM (VALUES ('x', 1), ('y', 2)) AS v (a, b)
    WHERE NOT EXISTS (SELECT 1 FROM presets p WHERE p.a = v.a);
  `;
  const [statement] = splitStatements(tokenize(sql));
  assert.deepEqual(parseInsert(statement).rows, [
    { a: 'x', b: 1 },
    { a: 'y', b: 2 },
  ]);
});

test('SQL okuyucu: takma ad sütunları SIRA DIŞI ise PATLAR (sessiz eşleşme yok)', () => {
  const sql = `
    INSERT INTO presets (a, b)
    SELECT v.b, v.a FROM (VALUES ('x', 1)) AS v (b, a);
  `;
  const [statement] = splitStatements(tokenize(sql));
  assert.throws(() => parseInsert(statement), /AYNI SIRADA değil/);
});

test('SQL okuyucu: anlaşılmayan ifadede SESSİZCE null üretmez, patlar', () => {
  const sql = 'INSERT INTO t (a) VALUES (b + c);';
  const [statement] = splitStatements(tokenize(sql));
  assert.throws(() => parseInsert(statement), /anlaşılmayan ifade/);
});

test('text[] literali: boş, düz ve tırnaklı öğeler', () => {
  assert.deepEqual(parsePgTextArray('{}', 'test'), []);
  assert.deepEqual(parsePgTextArray('{a,b}', 'test'), ['a', 'b']);
  assert.deepEqual(parsePgTextArray('{"a,b",c}', 'test'), ['a,b', 'c']);
});

test('üretim DETERMİNİSTİK (aynı girdi → bayt bayt aynı çıktı)', () => {
  assert.equal(buildLibraryJson(), buildLibraryJson());
});

test('üretilen kütüphane seed\'deki yayınlanmış tarifleri taşır', () => {
  const parsed = JSON.parse(buildLibraryJson());
  const slugs = parsed.soundscapes.map((e) => e.soundscape.slug);
  assert.equal(slugs.length, 7);
  assert.ok(slugs.includes('hearth-and-static'), '#215 demo tarifi eksik');
  assert.equal(parsed.weekly.soundscapeSlugs.length, 3);
  // Haftalık yayında DONDURULMUŞ tarih olmamalı (kural cihazda uygulanır).
  assert.equal(parsed.weekly.weekStart, undefined);
});

test('ÇEKİRDEK: drift kapısı bozulmuş asset\'te exit 1 verir', () => {
  const original = readFileSync(OUTPUT_PATH, 'utf8');
  const gate = () =>
    spawnSync(process.execPath, [join(repoRoot, 'tooling/check-content-drift.mjs')], {
      encoding: 'utf8',
    });

  // Önce temiz hâlde geçtiğini gör — aksi halde "exit 1" hiçbir şey kanıtlamaz.
  assert.equal(gate().status, 0, 'commit\'li asset kaynağıyla senkron değil');

  try {
    const tampered = JSON.parse(original);
    tampered.soundscapes[0].soundscape.titleI18n.en = 'Elle Değiştirildi';
    writeFileSync(OUTPUT_PATH, `${JSON.stringify(tampered, null, 2)}\n`, 'utf8');

    const result = gate();
    assert.equal(result.status, 1, 'kapı bozulmuş asset\'i geçirdi');
    assert.match(result.stderr, /UYUŞMUYOR/);
  } finally {
    writeFileSync(OUTPUT_PATH, original, 'utf8');
  }

  assert.equal(gate().status, 0, 'test asset\'i geri yükleyemedi');
});
