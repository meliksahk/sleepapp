import { buildNightReportShare, type NightReportShare } from '../domain/report-share';
import type { ShareUrls } from '../domain/share';
import type { NightReportReader } from '../domain/ports';

/** Bir gecenin raporundan paylaşım kartı üretir; rapor yoksa null. */
export class GetReportShareUseCase {
  constructor(
    private readonly reader: NightReportReader,
    private readonly urls: ShareUrls,
  ) {}

  async execute(userId: string, nightDate: string): Promise<NightReportShare | null> {
    const report = await this.reader.reportFor(userId, nightDate);
    if (!report) return null;
    return buildNightReportShare(
      {
        nightDate: report.nightDate,
        totalDurationMinutes: report.totalDurationMinutes,
        calmScore: report.calmScore,
      },
      this.urls,
    );
  }
}
