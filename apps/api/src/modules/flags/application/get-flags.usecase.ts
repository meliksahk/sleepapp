import { evaluateFlag, type BucketHasher, type FlagRepository } from '../domain/flag';

/** Kullanıcı için tüm flag'leri değerlendirir → { key: boolean }. */
export class GetFlagsUseCase {
  constructor(
    private readonly flags: FlagRepository,
    private readonly hasher: BucketHasher,
  ) {}

  async execute(userId: string): Promise<Record<string, boolean>> {
    const all = await this.flags.findAll();
    const result: Record<string, boolean> = {};
    for (const flag of all) {
      result[flag.key] = evaluateFlag(flag.rules, this.hasher.bucket(userId, flag.key));
    }
    return result;
  }
}
