import type { Flag, FlagRepository } from '../domain/flag';

/**
 * Admin panel: TÜM feature flag tanımlarını (ham kurallarıyla) listeler — rollout
 * görünürlüğü (docs/03 A4). Client'ın `GetFlagsUseCase`'i kullanıcıya göre DEĞERLENDİRİR;
 * burada admin ham kuralları görür (yüzde/platform/sürüm) ki neyin nasıl açık olduğunu
 * denetleyebilsin.
 */
export class ListAllFlagsUseCase {
  constructor(private readonly flags: FlagRepository) {}

  execute(): Promise<Flag[]> {
    return this.flags.findAll();
  }
}
