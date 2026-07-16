#!/usr/bin/env node
/**
 * İlk admin hesabını kurar (docs/03 A0). Davet akışı gelene kadar tek yol budur.
 *
 *   pnpm --filter @nocta/api admin:create -- owner@example.com 'parola' owner
 *
 * NEDEN SCRIPT, NEDEN ENDPOINT DEĞİL: "ilk admini yaratan" bir HTTP ucu, tanımı
 * gereği kimliksiz erişilebilir olmak zorundadır — yarış/kötüye kullanım yüzeyi.
 * Sunucuya erişebilen kişi zaten DB'ye erişebilir; hesabı oradan kurmak daha az
 * saldırı yüzeyi demektir.
 *
 * PAROLA ARGÜMANDAN GELİR ve shell geçmişine düşer. Bilinçli takas: alternatif
 * (stdin prompt) CI/otomasyonda kullanılamaz. Kurulumdan sonra geçmişi temizleyin
 * veya komutu boşlukla başlatın. Parola HİÇBİR yere loglanmaz.
 */
import { config } from 'dotenv';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { PrismaClient } from '@prisma/client';
import { Algorithm, hash } from '@node-rs/argon2';

// DATABASE_URL kök .env'den (test kurulumuyla aynı desen); mevcut env EZİLMEZ.
config({ path: resolve(dirname(fileURLToPath(import.meta.url)), '../../../.env') });

const ADMIN_ROLES = ['owner', 'editor', 'analyst', 'support'];
const MIN_PASSWORD_LENGTH = 12;

// pnpm, `-- ` ayıracını argümanlara AYNEN geçirir → süz. (Denemeden fark
// edilmezdi: script "--"yı e-posta sanıp anlamsız hata veriyordu.)
const argv = process.argv.slice(2).filter((a) => a !== '--');
const [email, password, ...roles] = argv;

if (!email || !password) {
  console.error(
    'Kullanım: admin:create -- <email> <parola> [rol...]\n' +
      `Roller: ${ADMIN_ROLES.join(', ')} (varsayılan: owner)`,
  );
  process.exit(1);
}
if (password.length < MIN_PASSWORD_LENGTH) {
  console.error(`Parola en az ${MIN_PASSWORD_LENGTH} karakter olmalı.`);
  process.exit(1);
}

const assigned = roles.length > 0 ? roles : ['owner'];
const unknown = assigned.filter((r) => !ADMIN_ROLES.includes(r));
if (unknown.length > 0) {
  console.error(`Tanınmayan rol: ${unknown.join(', ')}. Geçerli: ${ADMIN_ROLES.join(', ')}`);
  process.exit(1);
}

const normalized = email.trim().toLowerCase();
const prisma = new PrismaClient();

try {
  // argon2id parametreleri Argon2idPasswordHasher ile AYNI olmalı (OWASP 2024).
  const passwordHash = await hash(password, {
    algorithm: Algorithm.Argon2id,
    memoryCost: 19456,
    timeCost: 2,
    parallelism: 1,
  });

  // Idempotent: aynı e-posta ile yeniden çağrı parolayı/rolleri günceller.
  // (Parola sıfırlamanın da tek yolu şimdilik bu.)
  const user = await prisma.users.upsert({
    where: { email: normalized },
    update: { kind: 'admin', password_hash: passwordHash, roles: assigned, deleted_at: null },
    create: {
      email: normalized,
      kind: 'admin',
      password_hash: passwordHash,
      roles: assigned,
      email_verified_at: new Date(),
    },
  });

  console.log(`[admin:create] ✓ ${normalized} → ${assigned.join(', ')} (id: ${user.id})`);
} finally {
  await prisma.$disconnect();
}
