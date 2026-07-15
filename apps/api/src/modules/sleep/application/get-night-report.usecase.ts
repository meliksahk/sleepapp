import { buildNightReport, type NightReport } from '../domain/report';
import type { SleepSessionRepository } from '../domain/ports';

/** Bir gecenin uyku raporu; o gecede oturum yoksa null (404). */
export class GetNightReportUseCase {
  constructor(private readonly repo: SleepSessionRepository) {}

  async execute(userId: string, nightDate: string): Promise<NightReport | null> {
    const sessions = await this.repo.findByNight(userId, nightDate);
    return buildNightReport(nightDate, sessions);
  }
}
