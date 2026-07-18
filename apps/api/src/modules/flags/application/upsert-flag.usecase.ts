import { assertValidFlagKey, type Flag, type FlagRepository, type FlagRules } from '../domain/flag';

/**
 * Bir feature flag'i oluşturur ya da kurallarını değiştirir (docs/03 A4).
 * Anahtar domain'de kapılanır (URL'den gelir); kural gövdesi DTO'da doğrulanır.
 * `actorId` denetim izi + `updated_by` için token'dan gelir, gövdeden DEĞİL.
 */
export class UpsertFlagUseCase {
  constructor(private readonly flags: FlagRepository) {}

  execute(key: string, rules: FlagRules, actorId: string): Promise<Flag> {
    assertValidFlagKey(key);
    return this.flags.upsert(key, rules, actorId);
  }
}
