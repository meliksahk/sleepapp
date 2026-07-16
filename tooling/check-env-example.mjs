#!/usr/bin/env node
/**
 * `.env.example` sürüklenme kapısı — CLAUDE.md §6.
 *
 * Kural: "`.env` dosyaları gitignore'da, örnekleri `.env.example`".
 *
 * NEDEN BU SCRIPT: dosya vardı ama BAYATTI — şemadaki 23 değişkenin 11'i eksikti
 * (MAGIC_LINK_*, THROTTLE_*, ADMIN_LOGIN_LIMIT, REFRESH_REUSE_GRACE_MS, ...).
 * Sebebi basit: her yeni env eklendiğinde örneği güncellemek insan disiplinine
 * bırakılmıştı. Böyle bir dosya sessizce eskir ve yeni geliştirici neyin
 * gerektiğini bilemez — üstelik EKSİKLİĞİ ancak boot FAIL edince fark eder.
 *
 * ÜRETMEK YERİNE KAPI: `.env.example` yalnızca API'yi değil admin/web değişkenlerini
 * ve "neden böyle" yorumlarını da taşır; şemadan üretmek o bilgiyi silerdi. Kapı,
 * insanın yazdığı dosyanın şemayla ÇELİŞMEDİĞİNİ garanti eder.
 */
import { readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const schemaPath = join(repoRoot, 'apps/api/src/shared/config/env.ts');
const examplePath = join(repoRoot, '.env.example');

const schemaSource = readFileSync(schemaPath, 'utf8');

/**
 * `z.object({ ... })` gövdesini alır. Tam TS ayrıştırıcısı DEĞİL — kasıtlı:
 * şema düz bir nesne literali ve öyle kalmalı. Şekli değişirse burası ÇÖKER
 * (sessizce boş küme dönüp kapıyı işlevsiz bırakmaz — aşağıdaki kontrol).
 */
const objectStart = schemaSource.indexOf('z.object({');
if (objectStart === -1) {
  console.error('[env-example] ✗ env.ts içinde `z.object({` bulunamadı — şema mı değişti?');
  process.exit(1);
}
const body = schemaSource.slice(objectStart).split('\n});')[0];

const schemaKeys = [...body.matchAll(/^ {2}([A-Z][A-Z0-9_]*):/gm)].map((m) => m[1]);
if (schemaKeys.length === 0) {
  console.error('[env-example] ✗ şemadan hiç değişken çıkarılamadı — ayrıştırma bozuk.');
  process.exit(1);
}

const exampleSource = readFileSync(examplePath, 'utf8');
// Yorum satırındaki bir isim SAYILMAZ: `# THROTTLE_LIMIT=60` belgelemez, kandırır.
const exampleKeys = new Set(
  [...exampleSource.matchAll(/^([A-Z][A-Z0-9_]*)=/gm)].map((m) => m[1]),
);

const missing = schemaKeys.filter((k) => !exampleKeys.has(k));

if (missing.length > 0) {
  console.error(
    `[env-example] ✗ .env.example şemayla uyuşmuyor — ${missing.length} değişken EKSİK:\n`,
  );
  for (const k of missing) console.error(`  - ${k}`);
  console.error(
    '\nHer biri için `.env.example`a bir satır ekleyin (secret DEĞİL, lokal örnek değer).\n' +
      'Bu dosya yeni geliştiricinin neyin gerektiğini öğrendiği TEK yer; eksikse\n' +
      'eksikliği ancak boot FAIL edince fark eder.',
  );
  process.exit(1);
}

console.log(`[env-example] ✓ ${schemaKeys.length} env değişkeni .env.example ile senkron.`);
