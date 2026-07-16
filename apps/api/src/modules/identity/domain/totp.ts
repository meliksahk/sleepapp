import { createHmac, randomBytes, timingSafeEqual } from 'node:crypto';

/**
 * TOTP — RFC 6238 (RFC 4226/HOTP üzerine). Admin 2FA (CLAUDE.md §3.3).
 *
 * **NEDEN KÜTÜPHANE DEĞİL:** TOTP bir kripto TASARIMI değil, iyi tanımlanmış bir
 * KURGUDUR: HMAC (node:crypto'dan — kendimiz yazmıyoruz) + sayaç + kırpma. Toplam
 * ~40 satır ve **RFC 6238 Appendix B'nin RESMÎ TEST VEKTÖRLERİYLE** doğrulanabilir
 * (bkz. totp.spec.ts) — yani doğruluk iddiası benim değil, RFC'nin.
 *
 * Alternatifler ölçüldü: otplib 580KB, otpauth 953KB. İkisi de asıl riskleri
 * (tekrar saldırısı, pencere toleransı) ZATEN ÇÖZMÜYOR — onlar yine bizim işimiz.
 * Kripto YALNIZCA identity'de yaşar (CLAUDE.md §6); bu dosya o kuralın içinde.
 *
 * "Kendi kriptonu yazma" normunu biliyorum; buradaki takas bilinçli: HMAC'i
 * yazmıyoruz, RFC vektörleriyle kanıtlıyoruz ve bağımlılık eklemiyoruz.
 */

/** Adım (sn) — RFC 6238 varsayılanı; Google Authenticator vb. bunu bekler. */
export const TOTP_STEP_SECONDS = 30;

/** Kod uzunluğu — 6 hane standart. */
export const TOTP_DIGITS = 6;

/**
 * Kabul penceresi: ±1 adım (±30 sn). Neden 0 değil: kullanıcının telefonu ile
 * sunucunun saati birkaç saniye kayabilir ve kod tam geçişte yazılabilir; 0 pencere
 * "doğru kodu yazdım ama kabul etmedi" demek olurdu. Neden büyük değil: her adım,
 * çalınan bir kodun geçerli kalma süresini uzatır.
 */
export const TOTP_WINDOW_STEPS = 1;

const BASE32_ALPHABET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

/** Yeni gizli anahtar (base32, 20 bayt = RFC 4226 önerisi). */
export function generateTotpSecret(): string {
  return base32Encode(randomBytes(20));
}

/**
 * Kimlik doğrulayıcı uygulamasının okuduğu URI (QR'a gömülür).
 * `issuer` iki yerde geçer (etiket öneki + parametre): Authenticator uyumluluğu.
 */
export function totpAuthUri(secret: string, account: string, issuer = 'NOCTA'): string {
  const label = encodeURIComponent(`${issuer}:${account}`);
  const params = new URLSearchParams({
    secret,
    issuer,
    algorithm: 'SHA1',
    digits: String(TOTP_DIGITS),
    period: String(TOTP_STEP_SECONDS),
  });
  return `otpauth://totp/${label}?${params.toString()}`;
}

/** Verilen sayaç için kod (RFC 4226 HOTP). */
export function hotpCode(secret: string, counter: number): string {
  const key = base32Decode(secret);

  // Sayaç 8 baytlık big-endian. `writeBigUInt64BE`: 2^32'yi aşan sayaçlar (2106
  // sonrası) 32-bit yazımda sessizce taşardı.
  const counterBuf = Buffer.alloc(8);
  counterBuf.writeBigUInt64BE(BigInt(counter));

  const hmac = createHmac('sha1', key).update(counterBuf).digest();

  // Dinamik kırpma (RFC 4226 §5.3).
  const offset = hmac[hmac.length - 1]! & 0x0f;
  const binary =
    ((hmac[offset]! & 0x7f) << 24) |
    ((hmac[offset + 1]! & 0xff) << 16) |
    ((hmac[offset + 2]! & 0xff) << 8) |
    (hmac[offset + 3]! & 0xff);

  return String(binary % 10 ** TOTP_DIGITS).padStart(TOTP_DIGITS, '0');
}

/** Zaman → sayaç (RFC 6238 §4.2). */
export function totpCounter(atMs: number): number {
  return Math.floor(atMs / 1000 / TOTP_STEP_SECONDS);
}

/** Verilen anda geçerli kod. */
export function totpCode(secret: string, atMs: number): string {
  return hotpCode(secret, totpCounter(atMs));
}

/**
 * Kodu doğrular; geçerliyse KULLANILAN SAYACI döner (null = geçersiz).
 *
 * **SAYACI DÖNMESİ ŞART — TEKRAR SALDIRISI:** RFC 6238 §5.2 aynı kodun İKİ KEZ
 * kabul edilmesini yasaklar. Omuz üstünden kodu gören biri 30 sn içinde aynı kodla
 * girebilirdi. Çağıran, dönen sayacı saklar ve bir sonraki denemede "bu sayaç
 * zaten kullanıldı mı?" diye bakar — durum burada tutulmaz (domain saf kalır).
 *
 * `lastUsedCounter` verilirse o sayaç ve öncesi REDDEDİLİR.
 */
export function verifyTotp(
  secret: string,
  code: string,
  atMs: number,
  lastUsedCounter?: number,
): number | null {
  if (!/^\d{6}$/.test(code)) return null;

  const current = totpCounter(atMs);
  for (let drift = -TOTP_WINDOW_STEPS; drift <= TOTP_WINDOW_STEPS; drift++) {
    const counter = current + drift;
    if (counter < 0) continue;
    // Kullanılmış (veya daha eski) sayaç asla kabul edilmez.
    if (lastUsedCounter !== undefined && counter <= lastUsedCounter) continue;

    if (constantTimeEquals(hotpCode(secret, counter), code)) return counter;
  }
  return null;
}

/**
 * Sabit zamanlı karşılaştırma: `===` ilk farklı karakterde durur ve doğru kodun
 * kaç hanesinin tuttuğunu zamanlamayla sızdırırdı.
 */
function constantTimeEquals(a: string, b: string): boolean {
  const bufA = Buffer.from(a, 'utf8');
  const bufB = Buffer.from(b, 'utf8');
  // timingSafeEqual eşit uzunluk ister; uzunluk farkı zaten gizli değil.
  if (bufA.length !== bufB.length) return false;
  return timingSafeEqual(bufA, bufB);
}

function base32Encode(buf: Buffer): string {
  let bits = 0;
  let value = 0;
  let out = '';
  for (const byte of buf) {
    value = (value << 8) | byte;
    bits += 8;
    while (bits >= 5) {
      out += BASE32_ALPHABET[(value >>> (bits - 5)) & 31];
      bits -= 5;
    }
  }
  if (bits > 0) out += BASE32_ALPHABET[(value << (5 - bits)) & 31];
  return out;
}

function base32Decode(input: string): Buffer {
  // Padding ve boşluk temizlenir: kullanıcılar gizli anahtarı boşluklu yapıştırır.
  const clean = input.toUpperCase().replace(/[=\s]/g, '');
  let bits = 0;
  let value = 0;
  const out: number[] = [];
  for (const char of clean) {
    const idx = BASE32_ALPHABET.indexOf(char);
    if (idx === -1) throw new Error('Geçersiz base32 karakteri');
    value = (value << 5) | idx;
    bits += 5;
    if (bits >= 8) {
      out.push((value >>> (bits - 8)) & 0xff);
      bits -= 8;
    }
  }
  return Buffer.from(out);
}
