import { Algorithm, hash, verify } from '@node-rs/argon2';
import type { PasswordHasher } from '../domain/ports';

/**
 * argon2id parola hash'i (CLAUDE.md §3.3). Kripto YALNIZCA identity'de (docs/02 §2.1).
 *
 * Parametreler OWASP 2024 asgari önerisi (19 MiB bellek, 2 tur, paralellik 1).
 * UYDURULMADI; artırmak isteyen "daha güvenli" diye rastgele büyütmesin: bellek
 * maliyeti eşzamanlı giriş sayısıyla ÇARPILIR (19 MiB × N istek) — VPS'te tek
 * kaynak bellek olduğu için bu bir kapasite kararıdır.
 *
 * Salt ve parametreler üretilen hash STRING'İNİN İÇİNDE saklanır (PHC formatı) →
 * ayrı kolon gerekmez, ileride parametre yükseltmesi eski hash'leri bozmaz.
 */
export class Argon2idPasswordHasher implements PasswordHasher {
  private static readonly OPTIONS = {
    algorithm: Algorithm.Argon2id,
    memoryCost: 19456,
    timeCost: 2,
    parallelism: 1,
  } as const;

  async hash(plain: string): Promise<string> {
    return hash(plain, Argon2idPasswordHasher.OPTIONS);
  }

  async verify(storedHash: string, plain: string): Promise<boolean> {
    try {
      return await verify(storedHash, plain, Argon2idPasswordHasher.OPTIONS);
    } catch {
      // Bozuk/boş hash → "eşleşmedi". Atmak, çağıranda 500'e dönüşür ve bir
      // hesabın hash'inin bozuk olduğunu dışarıya SIZDIRIRDI.
      return false;
    }
  }
}
