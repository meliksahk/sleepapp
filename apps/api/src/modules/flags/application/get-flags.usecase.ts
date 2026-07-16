import {
  evaluateFlag,
  type BucketHasher,
  type EvalContext,
  type FlagRepository,
} from '../domain/flag';

/** Kullanıcı + context için tüm flag'leri değerlendirir → { key: boolean }. */
export class GetFlagsUseCase {
  constructor(
    private readonly flags: FlagRepository,
    private readonly hasher: BucketHasher,
  ) {}

  async execute(userId: string, ctx: EvalContext = {}): Promise<Record<string, boolean>> {
    const all = await this.flags.findAll();
    const result: Record<string, boolean> = {};
    for (const flag of all) {
      result[flag.key] = evaluateFlag(flag.rules, this.hasher.bucket(userId, flag.key), ctx);
    }
    return result;
  }
}
