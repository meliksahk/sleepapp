#!/usr/bin/env node
/**
 * Arketip matrisi codegen: API domain'i → mobil asset (`assets/archetype/matrix.json`).
 *
 * ## NEDEN VAR
 *
 * Arketip testi (viral kanca #1) SUNUCUDA yaşıyordu: sorular sunucudan, puanlama
 * sunucuda, sonuç sunucudan. `api.nocta.app` daha ayakta olmadığı için kurulan
 * prod APK'da kanca ÖLÜYDU — "Kimliğini keşfet" → hata → yeniden dene.
 *
 * Çözüm testi cihaza almak. Ama matrisi Dart'a ELLE kopyalamak, iki uygulamanın
 * sessizce ayrışması demekti: sunucu matrisine bir soru eklenir, cihaz eski
 * matriste kalır, AYNI cevaplar FARKLI arketip üretir. Kullanıcı için felaket,
 * geliştirici için görünmez. Bu yüzden tek kaynak (API domain'i) korunur ve
 * cihazın kopyası ÜRETİLİR.
 *
 * Repo zaten bu deseni kullanıyor: `gen:api-types`, `gen:tokens`.
 *
 * ## NASIL
 *
 * TS domain dosyaları `typescript` derleyicisiyle bellekte transpile edilip
 * `node:vm` içinde çalıştırılır (küçük, göreli-import-only bir CJS yükleyici).
 * Böylece matris METİN olarak değil, ÇALIŞAN KOD olarak okunur — regex ile
 * ayrıştırma, sabit listesi yeniden biçimlendiği an sessizce yanlış üretirdi.
 *
 * ## DOĞRULAMA VEKTÖRLERİ
 *
 * Üretilen JSON, sunucunun `scoreAnswers` fonksiyonuyla BURADA hesaplanmış
 * beklenen çıktıları da taşır (`vectors`). Dart tarafı aynı cevaplarla kendi
 * puanlamasını koşup bu çıktılarla karşılaştırır → iki uygulamanın eşdeğerliği
 * test edilebilir bir olguya döner (bkz. archetype_matrix_test.dart ve
 * archetype-matrix-export.spec.ts).
 */
import { readFileSync, existsSync, mkdirSync, writeFileSync } from 'node:fs';
import { join, dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';
import vm from 'node:vm';

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const require = createRequire(import.meta.url);
const ts = require('typescript');

const DOMAIN_DIR = join(repoRoot, 'apps/api/src/modules/archetype/domain');
export const OUTPUT_PATH = join(repoRoot, 'apps/mobile/assets/archetype/matrix.json');

// ─────────────────────────────────────────────────────────────────────────────
// Minik TS yükleyici: transpile → vm. Yalnızca GÖRELİ importları çözer; bir
// pakete (nestjs, prisma…) uzanan bir domain dosyası burada PATLAR — sessizce
// yanlış üretmektense kırılmak doğrudur.
// ─────────────────────────────────────────────────────────────────────────────
const moduleCache = new Map();

function loadTsModule(file) {
  const cached = moduleCache.get(file);
  if (cached) return cached.exports;

  const source = readFileSync(file, 'utf8');
  const { outputText } = ts.transpileModule(source, {
    compilerOptions: {
      module: ts.ModuleKind.CommonJS,
      target: ts.ScriptTarget.ES2022,
    },
    fileName: file,
  });

  const mod = { exports: {} };
  moduleCache.set(file, mod);

  const localRequire = (specifier) => {
    if (!specifier.startsWith('.')) {
      throw new Error(
        `[archetype-matrix] ✗ ${file} paket importu yapıyor: "${specifier}".\n` +
          'Bu yükleyici yalnızca göreli domain importlarını çözer. Arketip domain\'i\n' +
          'saf kalmalı (CLAUDE.md §3.2 hexagonal: domain framework tanımaz).',
      );
    }
    const base = resolve(dirname(file), specifier);
    for (const candidate of [base, `${base}.ts`, join(base, 'index.ts')]) {
      if (existsSync(candidate) && candidate.endsWith('.ts')) return loadTsModule(candidate);
    }
    throw new Error(`[archetype-matrix] ✗ çözülemedi: "${specifier}" (${file})`);
  };

  vm.runInNewContext(outputText, {
    module: mod,
    exports: mod.exports,
    require: localRequire,
    console,
  });
  return mod.exports;
}

// ─────────────────────────────────────────────────────────────────────────────
// Vektör üretimi — DETERMİNİSTİK (aynı girdi → bayt bayt aynı çıktı).
// `Math.random` kullanılamaz: her çalıştırma farklı JSON üretir ve drift kapısı
// her seferinde kırmızı yanardı.
// ─────────────────────────────────────────────────────────────────────────────

/** Sabit tohumlu doğrusal eşleşik üreteç (Numerical Recipes katsayıları). */
function lcg(seed) {
  let state = seed >>> 0;
  return () => {
    state = (Math.imul(state, 1664525) + 1013904223) >>> 0;
    return state / 0x100000000;
  };
}

/**
 * Doğrulama vektörleri: her soruya bir seçenek atayan tam cevap kümeleri.
 *
 * Kapsam bilinçli: (1) her arketip için "hepsi aynı" süpürmesi — net kazananı
 * kilitler, (2) deterministik rastgele karışım — BERABERLİK durumlarını yakalar.
 * Beraberlik, iki uygulamanın en kolay ayrışacağı yerdir (TS'te kural
 * "ARCHETYPES sırasında ilk gelen kazanır"); rastgele karışımların önemli bir
 * kısmı 3-3 ve 2-2-1-1 beraberliği üretir.
 */
function buildVectors(matrix, scoreAnswers) {
  const questions = matrix.questions;
  const vectors = [];

  const push = (answers) => {
    const scored = scoreAnswers(matrix, answers);
    vectors.push({
      answers,
      archetypeSlug: scored.archetypeSlug,
      scores: scored.scores,
    });
  };

  // (1) Süpürme: her soruda i'inci seçenek.
  const maxOptions = Math.max(...questions.map((q) => q.options.length));
  for (let i = 0; i < maxOptions; i++) {
    const answers = {};
    for (const q of questions) {
      answers[q.id] = q.options[Math.min(i, q.options.length - 1)].id;
    }
    push(answers);
  }

  // (2) Deterministik karışım.
  const rand = lcg(20260717);
  for (let n = 0; n < 60; n++) {
    const answers = {};
    for (const q of questions) {
      answers[q.id] = q.options[Math.floor(rand() * q.options.length)].id;
    }
    push(answers);
  }

  return vectors;
}

// ─────────────────────────────────────────────────────────────────────────────

/** Üretilecek JSON'u (string olarak) döndürür. Drift kapısı da bunu çağırır. */
export function buildMatrixJson() {
  const { ARCHETYPES, ARCHETYPE_MATRIX_V1, scoreAnswers } = loadTsModule(
    join(DOMAIN_DIR, 'archetype.ts'),
  );
  const { localizeMatrix } = loadTsModule(join(DOMAIN_DIR, 'archetype-i18n.ts'));
  const { listArchetypeInfo } = loadTsModule(join(DOMAIN_DIR, 'archetype-content.ts'));
  const { SUPPORTED_LOCALES } = loadTsModule(join(repoRoot, 'apps/api/src/shared/locale.ts'));

  const matrix = ARCHETYPE_MATRIX_V1;

  // Sorunun YAPISI dilden bağımsızdır (id + arketip eşlemesi). Metinler ayrı
  // yaşar — sunucudaki tasarım kuralının aynısı (archetype-i18n.ts): skorlama
  // yalnızca id'lere bakar, yani TR test eden ile EN test eden aynı sonucu alır.
  const questions = matrix.questions.map((q) => ({
    id: q.id,
    options: q.options.map((o) => ({ id: o.id, archetype: o.archetype })),
  }));

  const text = {};
  for (const locale of SUPPORTED_LOCALES) {
    const localized = localizeMatrix(matrix, locale);
    const questionText = {};
    for (const q of localized.questions) {
      const options = {};
      for (const o of q.options) options[o.id] = o.label;
      questionText[q.id] = { prompt: q.prompt, options };
    }
    const archetypeText = {};
    for (const info of listArchetypeInfo(locale)) {
      archetypeText[info.slug] = {
        name: info.name,
        tagline: info.tagline,
        summary: info.summary,
      };
    }
    text[locale] = { questions: questionText, archetypes: archetypeText };
  }

  const payload = {
    $generated:
      'ÜRETİLEN DOSYA — ELLE DÜZENLEMEYİN. Kaynak: apps/api/src/modules/archetype/domain/. ' +
      'Yeniden üretmek için: pnpm gen:archetype',
    version: matrix.version,
    archetypes: [...ARCHETYPES],
    locales: [...SUPPORTED_LOCALES],
    questions,
    text,
    vectors: buildVectors(matrix, scoreAnswers),
  };

  // Sondaki `\n`: POSIX metin dosyası kuralı + git diff gürültüsünü keser.
  return `${JSON.stringify(payload, null, 2)}\n`;
}

/** CLI: `node tooling/gen-archetype-matrix.mjs` */
function main() {
  const json = buildMatrixJson();
  mkdirSync(dirname(OUTPUT_PATH), { recursive: true });
  writeFileSync(OUTPUT_PATH, json, 'utf8');
  const parsed = JSON.parse(json);
  console.log(
    `[archetype-matrix] ✓ ${parsed.questions.length} soru · ` +
      `${parsed.locales.length} dil · ${parsed.vectors.length} doğrulama vektörü → ` +
      OUTPUT_PATH.replace(repoRoot, '').replace(/\\/g, '/'),
  );
}

if (process.argv[1] && resolve(process.argv[1]) === resolve(fileURLToPath(import.meta.url))) {
  main();
}
