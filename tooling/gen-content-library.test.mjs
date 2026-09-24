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

import { tokenize, splitStatements, parseInsert, parsePgTextArray, parseUpdate } from './sql-values.mjs';
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

/** Seed'in ifadeleri: beklentiler elle yazılmış sayılar yerine buradan türer. */
function seedStatements() {
  return splitStatements(tokenize(readFileSync(join(repoRoot, 'db/seed.sql'), 'utf8')));
}

function seedRows(table) {
  return seedStatements().flatMap((st) => {
    const parsed = parseInsert(st);
    return parsed?.table === table ? parsed.rows : [];
  });
}

test('üretilen kütüphane seed\'deki yayınlanmış tarifleri taşır', () => {
  const parsed = JSON.parse(buildLibraryJson());
  const slugs = parsed.soundscapes.map((e) => e.soundscape.slug);
  // Beklenti seed'den türer. Eskiden "7" ve "3" elle yazılıydı; seed 25 tarife
  // ve 4 haftalık parçaya büyüdü, bu test kırmızıya döndü ve CI bu dosyayı
  // koşmadığı için görünmedi.
  const published = seedRows('soundscapes').filter((r) => r.status === 'published');
  assert.deepEqual(slugs, published.map((r) => r.slug));
  assert.ok(slugs.includes('hearth-and-static'), '#215 demo tarifi eksik');
  assert.equal(
    parsed.weekly.soundscapeSlugs.length,
    seedRows('weekly_releases').at(-1).soundscape_ids.length,
  );
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

test('SQL okuyucu: seed biçimindeki UPDATE okunur', () => {
  const sql =
    "UPDATE soundscapes SET category = 'relaxing' WHERE slug IN ('a','b') AND category <> 'relaxing';";
  const [statement] = splitStatements(tokenize(sql));
  assert.deepEqual(parseUpdate(statement), {
    table: 'soundscapes',
    column: 'category',
    value: 'relaxing',
    key: 'slug',
    keys: ['a', 'b'],
  });
  const [insert] = splitStatements(tokenize('INSERT INTO t (a) VALUES (1);'));
  assert.equal(parseUpdate(insert), null);
});

test('SQL okuyucu: tanınmayan UPDATE biçiminde SESSİZCE atlamaz, patlar', () => {
  for (const sql of [
    "UPDATE soundscapes SET category = 'noise' WHERE id = 5;",
    // Koşul değeri SET'tekinden farklı: sonucu değiştirir, idempotentlik değil.
    "UPDATE soundscapes SET category = 'relaxing' WHERE slug IN ('a') AND category <> 'nature';",
  ]) {
    const [statement] = splitStatements(tokenize(sql));
    assert.throws(() => parseUpdate(statement), /desteklenmeyen UPDATE/, sql);
  }
});

test('ÇEKİRDEK: seed\'deki kategori ataması gömülü kütüphaneye yansır', () => {
  // Regresyon: üretici UPDATE'leri okumuyordu. 25 tarifin hepsi 'nature'
  // çıkıyordu ve cihazdaki "Rahatlatıcı" filtresi kurulu APK'da hep boştu.
  // Beklenen: seed'deki atamalar SIRAYLA uygulanmış hâli (son yazan kazanır).
  const expected = new Map();
  for (const u of seedStatements().map(parseUpdate)) {
    if (u?.table === 'soundscapes' && u.column === 'category') {
      for (const slug of u.keys) expected.set(slug, u.value);
    }
  }
  assert.ok(expected.size > 0, "seed'de kategori ataması yok: test anlamsızlaştı");

  const parsed = JSON.parse(buildLibraryJson());
  const bySlug = new Map(parsed.soundscapes.map((e) => [e.soundscape.slug, e.soundscape.category]));
  for (const [slug, category] of expected) assert.equal(bySlug.get(slug), category, slug);
  assert.equal(bySlug.get('deep-ocean-hush'), 'nature');

  // Cihazdaki üç filtrenin HİÇBİRİ boş kalmamalı. 'noise' temiz kurulumda boştu:
  // kategori göçü boş tabloya koşuyordu, atama seed'e taşındı.
  for (const category of ['noise', 'nature', 'relaxing']) {
    assert.ok([...bySlug.values()].includes(category), `'${category}' kategorisinde tarif yok`);
  }
});
