#!/usr/bin/env node
/**
 * `apps/api/assets-inbox/` → MinIO + `audio_assets` tablosu.
 *
 * ## Neden bir "inbox" klasörü
 *
 * Ses dosyaları REPOYA GİRMEZ (boyut) ama bir yerden gelmeleri gerekir. Inbox,
 * dosyayı bırakıp tek komut çalıştırdığımız yer:
 *
 *   apps/api/assets-inbox/<kategori>/<ad>.<uzantı>   ← ses
 *   apps/api/assets-inbox/<kategori>/<ad>.json       ← meta (ZORUNLU)
 *
 * Depolama anahtarı `<kategori>/<ad>.<uzantı>` olur. Kategori klasörü hem
 * anahtarı hem de düzeni verir.
 *
 * ## LİSANS ZORUNLU — script BURADA durur
 *
 * `license` veya `source` boşsa dosya YÜKLENMEZ ve script hata koduyla çıkar.
 * Sebep pazarlıksız (CLAUDE.md §6, docs/04 §1.2.0): mağazaya çıkarken her
 * dosyanın nereden geldiğini kanıtlamak zorundayız. "Sonra doldururuz" diye
 * geçilen tek bir satır, aylar sonra kaynağı hatırlanmayan bir dosyaya dönüşür.
 *
 * ## Idempotency
 *
 * `audio_assets.key` UNIQUE ve upsert anahtarı. Aynı dosya iki kez yüklenince
 * ikinci kopya OLUŞMAZ. Ayrıca sha256 tutuluyor: içerik değişmediyse MinIO'ya
 * yükleme de ATLANIR (yalnızca meta değiştiyse DB güncellenir). Yani script
 * defalarca çalıştırılabilir ve ikinci çalıştırma hiçbir şey bozmaz.
 *
 * Çalıştır: node tooling/upload-audio-assets.mjs [--dry-run]
 */
import { createHash } from 'node:crypto';
import { existsSync, readFileSync, readdirSync, statSync } from 'node:fs';
import { createRequire } from 'node:module';
import { basename, extname, join, dirname } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const inboxRoot = join(repoRoot, 'apps/api/assets-inbox');

/**
 * Bağımlılıklar `apps/api`'nin node_modules'ünde yaşıyor (kök workspace'te
 * @aws-sdk/prisma YOK). Kökten import edilemezler; `createRequire` ile apps/api
 * bağlamında çözüyoruz. Alternatif (kök package.json'a ikinci kopya bağımlılık
 * eklemek) aynı paketin iki sürümünün sürüklenmesi riskini getirirdi.
 */
const requireFromApi = createRequire(join(repoRoot, 'apps/api/package.json'));

/** Kabul edilen ses uzantıları. Meta dosyası (.json) bu listede DEĞİL. */
const AUDIO_EXT = new Set(['.mp3', '.wav', '.ogg', '.m4a', '.flac', '.opus']);

const CONTENT_TYPE = {
  '.mp3': 'audio/mpeg',
  '.wav': 'audio/wav',
  '.ogg': 'audio/ogg',
  '.m4a': 'audio/mp4',
  '.flac': 'audio/flac',
  '.opus': 'audio/opus',
};

const dryRun = process.argv.includes('--dry-run');

// ─────────────────────────────── .env ───────────────────────────────

/**
 * Kök `.env` — Node 20 kendiliğinden okumaz ve script'e dotenv bağımlılığı
 * eklemek (kök workspace'te yok) bu iş için fazla. Format basit: KEY=value.
 * Zaten var olan ortam değişkeni EZİLMEZ (CI/prod önceliği).
 */
function loadDotEnv() {
  const path = join(repoRoot, '.env');
  if (!existsSync(path)) return;
  for (const line of readFileSync(path, 'utf8').split('\n')) {
    const trimmed = line.trim();
    if (trimmed === '' || trimmed.startsWith('#')) continue;
    const eq = trimmed.indexOf('=');
    if (eq <= 0) continue;
    const key = trimmed.slice(0, eq).trim();
    let value = trimmed.slice(eq + 1).trim();
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }
    if (process.env[key] === undefined) process.env[key] = value;
  }
}

loadDotEnv();

const config = {
  endpoint: process.env.MINIO_ENDPOINT ?? 'http://localhost:9000',
  region: process.env.MINIO_REGION ?? 'us-east-1',
  accessKey: process.env.MINIO_ROOT_USER ?? 'nocta',
  secretKey: process.env.MINIO_ROOT_PASSWORD ?? 'nocta_local_dev',
  bucket: process.env.MINIO_BUCKET_AUDIO_ASSETS ?? 'audio-assets',
};

// ────────────────────────── inbox tarama ──────────────────────────

/**
 * Inbox'ı tarar: `<kategori>/<ad>.<ses uzantısı>` + yanındaki `<ad>.json`.
 * Meta dosyası YOKSA bu bir hatadır (lisans bilinmiyor demektir), sessizce
 * atlanmaz.
 */
export function scanInbox() {
  if (!existsSync(inboxRoot)) return [];
  const found = [];
  for (const category of readdirSync(inboxRoot)) {
    const categoryDir = join(inboxRoot, category);
    if (!statSync(categoryDir).isDirectory()) continue;
    for (const file of readdirSync(categoryDir)) {
      const ext = extname(file).toLowerCase();
      if (!AUDIO_EXT.has(ext)) continue;
      const stem = basename(file, extname(file));
      found.push({
        category,
        file,
        ext,
        stem,
        audioPath: join(categoryDir, file),
        metaPath: join(categoryDir, `${stem}.json`),
        key: `${category}/${file}`,
      });
    }
  }
  return found.sort((a, b) => a.key.localeCompare(b.key));
}

export function readMeta(entry) {
  if (!existsSync(entry.metaPath)) {
    throw new Error(
      `meta dosyası YOK: ${entry.stem}.json — lisans/kaynak bilinmeden yükleme yapılmaz.`,
    );
  }
  let meta;
  try {
    meta = JSON.parse(readFileSync(entry.metaPath, 'utf8'));
  } catch (err) {
    throw new Error(`meta JSON ayrıştırılamadı (${entry.stem}.json): ${err.message}`);
  }

  const nonBlank = (v) => typeof v === 'string' && v.trim() !== '';

  // LİSANS KAPISI — burada durur.
  if (!nonBlank(meta.license)) {
    throw new Error(`'license' alanı boş/eksik (${entry.stem}.json). Yükleme reddedildi.`);
  }
  if (!nonBlank(meta.source)) {
    throw new Error(`'source' alanı boş/eksik (${entry.stem}.json). Yükleme reddedildi.`);
  }
  if (!nonBlank(meta.genre)) {
    throw new Error(`'genre' alanı boş/eksik (${entry.stem}.json).`);
  }

  const mood = Array.isArray(meta.mood)
    ? [...new Set(meta.mood.filter(nonBlank).map((m) => m.trim().toLowerCase()))]
    : [];

  return {
    // Başlık verilmezse dosya adına düşülür — bu güvenli bir varsayılan
    // (lisansın aksine, yanlış olması kimseyi riske atmaz).
    title: nonBlank(meta.title) ? meta.title.trim() : entry.stem,
    genre: meta.genre.trim().toLowerCase(),
    mood,
    license: meta.license.trim(),
    source: meta.source.trim(),
    durationSeconds: Number.isFinite(meta.durationSeconds)
      ? Math.max(0, Math.round(meta.durationSeconds))
      : null,
  };
}

/**
 * WAV başlığından süre. Yalnızca WAV — MP3/OGG süresi çözücü gerektirir ve
 * bunun için bir bağımlılık eklemek (ffprobe/music-metadata) bu iş için fazla.
 * Çözemediğimizde TAHMİN ÜRETMİYORUZ: meta dosyasındaki `durationSeconds`
 * kullanılır, o da yoksa 0 yazılır ve UYARI basılır.
 *
 * Dönen: saniye (int) ya da null.
 */
export function wavDurationSeconds(buffer) {
  if (buffer.length < 12) return null;
  if (buffer.toString('ascii', 0, 4) !== 'RIFF') return null;
  if (buffer.toString('ascii', 8, 12) !== 'WAVE') return null;

  let offset = 12;
  let byteRate = null;
  while (offset + 8 <= buffer.length) {
    const chunkId = buffer.toString('ascii', offset, offset + 4);
    const chunkSize = buffer.readUInt32LE(offset + 4);
    if (chunkId === 'fmt ' && offset + 8 + 16 <= buffer.length) {
      byteRate = buffer.readUInt32LE(offset + 16);
    } else if (chunkId === 'data') {
      if (!byteRate) return null;
      return Math.round(chunkSize / byteRate);
    }
    // Chunk'lar çift hizalıdır; tek boyutta 1 dolgu baytı vardır.
    offset += 8 + chunkSize + (chunkSize % 2);
  }
  return null;
}

// ──────────────────────────── ana akış ────────────────────────────

async function main() {
  const entries = scanInbox();
  if (entries.length === 0) {
    console.log(
      `[upload-audio-assets] inbox boş: ${inboxRoot}\n` +
        '  Dosya koyun: assets-inbox/<kategori>/<ad>.mp3 + <ad>.json ' +
        '(title/genre/mood/license/source)\n' +
        '  Örnek üretmek için: cd apps/mobile && dart run tool/render_demo_asset.dart',
    );
    return;
  }

  // Meta'lar ÖNCE okunur: tek bir lisanssız dosya varsa HİÇBİRİ yüklenmez.
  // Yarısı yüklenmiş bir inbox, hangi dosyanın geçtiğini takip etmeyi zorlaştırır.
  const prepared = [];
  const errors = [];
  for (const entry of entries) {
    try {
      prepared.push({ ...entry, meta: readMeta(entry) });
    } catch (err) {
      errors.push(`  ✗ ${entry.key}: ${err.message}`);
    }
  }
  if (errors.length > 0) {
    console.error(
      `[upload-audio-assets] ✗ ${errors.length} dosya reddedildi — HİÇBİRİ yüklenmedi:\n` +
        errors.join('\n'),
    );
    process.exit(1);
  }

  const { S3Client, PutObjectCommand, HeadBucketCommand, CreateBucketCommand } =
    requireFromApi('@aws-sdk/client-s3');
  const { PrismaClient } = requireFromApi('@prisma/client');

  const s3 = new S3Client({
    endpoint: config.endpoint,
    region: config.region,
    credentials: { accessKeyId: config.accessKey, secretAccessKey: config.secretKey },
    forcePathStyle: true, // MinIO path-style
  });
  const prisma = new PrismaClient();

  let created = 0;
  let updated = 0;
  let unchanged = 0;

  try {
    await ensureBucket(s3, { HeadBucketCommand, CreateBucketCommand });

    for (const entry of prepared) {
      const bytes = readFileSync(entry.audioPath);
      const checksum = createHash('sha256').update(bytes).digest('hex');
      const duration =
        entry.meta.durationSeconds ?? (entry.ext === '.wav' ? wavDurationSeconds(bytes) : null);

      if (duration === null) {
        console.warn(
          `  ⚠ ${entry.key}: süre belirlenemedi (${entry.ext} çözücüsü yok, meta'da ` +
            "'durationSeconds' de yok) → 0 yazılıyor.",
        );
      }

      const existing = await prisma.audio_assets.findUnique({ where: { key: entry.key } });
      const contentChanged = !existing || existing.checksum !== checksum;

      if (dryRun) {
        console.log(
          `  [dry-run] ${entry.key}: ${existing ? (contentChanged ? 'güncellenecek' : 'meta kontrolü') : 'eklenecek'}`,
        );
        continue;
      }

      // İçerik değişmediyse MinIO'ya DOKUNMA: aynı baytları yeniden yüklemek
      // idempotency'yi bozmaz ama büyük dosyalarda boşuna zaman ve trafiktir.
      if (contentChanged) {
        await s3.send(
          new PutObjectCommand({
            Bucket: config.bucket,
            Key: entry.key,
            Body: bytes,
            ContentType: CONTENT_TYPE[entry.ext] ?? 'application/octet-stream',
          }),
        );
      }

      const data = {
        title: entry.meta.title,
        genre: entry.meta.genre,
        mood: entry.meta.mood,
        duration_seconds: duration ?? 0,
        license: entry.meta.license,
        source: entry.meta.source,
        checksum,
        byte_size: BigInt(bytes.length),
        content_type: CONTENT_TYPE[entry.ext] ?? 'application/octet-stream',
      };

      if (!existing) {
        await prisma.audio_assets.create({ data: { key: entry.key, ...data } });
        created++;
        console.log(`  + ${entry.key} (${(bytes.length / 1024).toFixed(0)} KB, ${duration ?? 0}s)`);
      } else if (contentChanged || metaDiffers(existing, data)) {
        await prisma.audio_assets.update({
          where: { key: entry.key },
          data: { ...data, updated_at: new Date() },
        });
        updated++;
        console.log(`  ~ ${entry.key} (${contentChanged ? 'içerik + meta' : 'yalnızca meta'})`);
      } else {
        unchanged++;
        console.log(`  = ${entry.key} (değişmedi)`);
      }
    }
  } finally {
    await prisma.$disconnect();
    s3.destroy();
  }

  if (dryRun) {
    console.log(`[upload-audio-assets] dry-run bitti — ${prepared.length} dosya incelendi.`);
    return;
  }
  console.log(
    `[upload-audio-assets] ✓ bucket '${config.bucket}': ` +
      `${created} eklendi, ${updated} güncellendi, ${unchanged} değişmedi.`,
  );
}

/** Bucket yoksa oluşturur. Varsa dokunmaz (yeniden çalıştırma güvenli). */
async function ensureBucket(s3, { HeadBucketCommand, CreateBucketCommand }) {
  try {
    await s3.send(new HeadBucketCommand({ Bucket: config.bucket }));
  } catch (err) {
    // 404/NotFound = yok → oluştur. Başka hata (bağlantı, yetki) YUTULMAZ.
    const status = err?.$metadata?.httpStatusCode;
    if (status !== 404 && err?.name !== 'NotFound' && err?.name !== 'NoSuchBucket') {
      throw new Error(
        `MinIO'ya erişilemedi (${config.endpoint}): ${err.message}\n` +
          '  `docker compose up -d` çalışıyor mu?',
      );
    }
    await s3.send(new CreateBucketCommand({ Bucket: config.bucket }));
    console.log(`[upload-audio-assets] bucket oluşturuldu: ${config.bucket}`);
  }
}

/** Meta değişmiş mi (içerik aynıyken). Dizi karşılaştırması SIRA DAHİL. */
export function metaDiffers(row, data) {
  return (
    row.title !== data.title ||
    row.genre !== data.genre ||
    row.license !== data.license ||
    row.source !== data.source ||
    row.duration_seconds !== data.duration_seconds ||
    row.mood.length !== data.mood.length ||
    row.mood.some((m, i) => m !== data.mood[i])
  );
}

/**
 * YALNIZCA doğrudan çalıştırıldığında iş yapar. Testler bu dosyayı IMPORT eder
 * (saf yardımcıları sınamak için) ve import bir yükleme başlatmamalı — aksi
 * halde `node --test` çalıştırmak MinIO'ya yazardı.
 */
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch((err) => {
    console.error(`[upload-audio-assets] ✗ ${err.message}`);
    process.exit(1);
  });
}
