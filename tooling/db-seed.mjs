#!/usr/bin/env node
/**
 * `db/seed.sql`'i lokal Postgres'e uygular (yalnızca geliştirme).
 *
 * NEDEN NODE SCRIPT, NEDEN DÜZ `psql -f` DEĞİL:
 * 1. Windows'ta `psql` binary'si genellikle PATH'te YOKTUR — veritabanı Docker
 *    içinde çalışıyor, host'a client kurulmuş olması gerekmiyor. Bu yüzden
 *    varsayılan yol `docker exec`: hiçbir ek kurulum istemez.
 * 2. package.json script'ine `docker exec -i ... < db/seed.sql` yazmak shell'e
 *    bağımlı olurdu (cmd.exe / PowerShell / sh yönlendirmeyi aynı ele almıyor;
 *    PowerShell'de `<` zaten parse hatasıdır). Dosyayı Node'un okuyup child
 *    process'in stdin'ine yazması shell'den tamamen bağımsızdır.
 * 3. `ON_ERROR_STOP=1`: psql varsayılanda hatalı ifadeden sonra DEVAM eder ve
 *    çıkış kodu 0 olur. O hâlde bozuk bir seed "başarılı" görünürdü.
 *
 * PATH'te `psql` varsa onu kullanır (docker exec'ten hızlı ve DATABASE_URL'e
 * saygılı); yoksa container'a düşer. Container adı NOCTA_DB_CONTAINER ile
 * değiştirilebilir.
 */
import { spawn, spawnSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const seedPath = join(repoRoot, 'db/seed.sql');
const container = process.env.NOCTA_DB_CONTAINER ?? 'nocta-local-db-1';
const dbUser = process.env.NOCTA_DB_USER ?? 'nocta';
const dbName = process.env.NOCTA_DB_NAME ?? 'nocta';

let sql;
try {
  sql = readFileSync(seedPath, 'utf8');
} catch (err) {
  console.error(`db:seed — ${seedPath} okunamadı: ${err.message}`);
  process.exit(1);
}

function hasLocalPsql() {
  // `--version` her platformda çalışır; bulunamazsa spawnSync error döndürür.
  const probe = spawnSync('psql', ['--version'], { stdio: 'ignore', shell: false });
  return probe.error === undefined && probe.status === 0;
}

const useLocalPsql = hasLocalPsql() && process.env.DATABASE_URL;

const [cmd, args] = useLocalPsql
  ? ['psql', [process.env.DATABASE_URL, '-v', 'ON_ERROR_STOP=1', '-f', '-']]
  : [
      'docker',
      ['exec', '-i', container, 'psql', '-U', dbUser, '-d', dbName, '-v', 'ON_ERROR_STOP=1'],
    ];

console.log(
  useLocalPsql
    ? 'db:seed — lokal psql + DATABASE_URL kullanılıyor'
    : `db:seed — psql bulunamadı, docker exec ${container} kullanılıyor`,
);

const child = spawn(cmd, args, { stdio: ['pipe', 'inherit', 'inherit'] });

child.on('error', (err) => {
  console.error(`db:seed — "${cmd}" çalıştırılamadı: ${err.message}`);
  console.error('Docker ayakta mı? `docker compose up -d` ile lokal yığını başlatın.');
  process.exit(1);
});

child.on('close', (code) => {
  if (code === 0) {
    console.log('db:seed — tamam (idempotent: tekrar çalıştırmak güvenli).');
  } else {
    console.error(`db:seed — psql ${code} koduyla çıktı.`);
  }
  process.exit(code ?? 1);
});

child.stdin.on('error', (err) => {
  // EPIPE: psql erkenden öldü; asıl hata zaten stderr'den geçti, burada susmuyoruz.
  console.error(`db:seed — stdin yazılamadı: ${err.message}`);
});
child.stdin.end(sql);
