import type { PrismaService } from '../../../shared/infra/prisma.service';
import type { OutboxWriter } from '../../../shared/outbox/outbox-writer';
import type { SleepSessionRepository } from '../domain/ports';
import type { NewSleepSession, SleepSession } from '../domain/sleep-session.entity';
import type { SleepAggregate } from '../domain/stats';

interface Row {
  id: string;
  user_id: string;
  started_at: Date;
  ended_at: Date;
  night_date: Date;
  duration_minutes: number;
  movement_events: number;
  sound_events: number;
  created_at: Date;
}

function toDomain(row: Row): SleepSession {
  return {
    id: row.id,
    userId: row.user_id,
    startedAt: row.started_at,
    endedAt: row.ended_at,
    // @db.Date → UTC gün; YYYY-MM-DD'ye indir.
    nightDate: row.night_date.toISOString().slice(0, 10),
    durationMinutes: row.duration_minutes,
    movementEvents: row.movement_events,
    soundEvents: row.sound_events,
    createdAt: row.created_at,
  };
}

export class PrismaSleepSessionRepository implements SleepSessionRepository {
  constructor(
    private readonly prisma: PrismaService,
    private readonly outbox: OutboxWriter,
  ) {}

  async save(userId: string, session: NewSleepSession): Promise<SleepSession> {
    // Oturum insert'i + outbox olayı AYNI transaction'da (atomik). Böylece "oturum yazıldı
    // ama bildirim olayı kayboldu" durumu imkânsız: ikisi birlikte commit olur ya da hiç.
    // Olay ham veri taşımaz (§6) — yalnız id/gece referansı.
    const row = await this.prisma.$transaction(async (tx) => {
      const created = await tx.sleep_sessions.create({
        data: {
          user_id: userId,
          started_at: session.startedAt,
          ended_at: session.endedAt,
          night_date: new Date(`${session.nightDate}T00:00:00.000Z`),
          duration_minutes: session.durationMinutes,
          movement_events: session.movementEvents,
          sound_events: session.soundEvents,
        },
      });
      await this.outbox.append(tx, {
        aggregateType: 'sleep_session',
        eventType: 'sleep.session_recorded',
        payload: { userId, sessionId: created.id, nightDate: session.nightDate },
      });
      return created;
    });
    return toDomain(row);
  }

  async listRecentByUser(userId: string, limit: number): Promise<SleepSession[]> {
    const rows = await this.prisma.sleep_sessions.findMany({
      where: { user_id: userId },
      orderBy: [{ night_date: 'desc' }, { started_at: 'desc' }],
      take: limit,
    });
    return rows.map(toDomain);
  }

  async findByNight(userId: string, nightDate: string): Promise<SleepSession[]> {
    const rows = await this.prisma.sleep_sessions.findMany({
      where: { user_id: userId, night_date: new Date(`${nightDate}T00:00:00.000Z`) },
      orderBy: { started_at: 'asc' },
    });
    return rows.map(toDomain);
  }

  async listByNightRange(userId: string, from: string, to: string): Promise<SleepSession[]> {
    const rows = await this.prisma.sleep_sessions.findMany({
      where: {
        user_id: userId,
        night_date: {
          gte: new Date(`${from}T00:00:00.000Z`),
          lte: new Date(`${to}T00:00:00.000Z`),
        },
      },
      orderBy: [{ night_date: 'desc' }, { started_at: 'desc' }],
    });
    return rows.map(toDomain);
  }

  /**
   * TÜM oturumların toplamı — DB'de hesaplanır (bellek/pencere yok).
   * `nights` için groupBy: benzersiz gece sayısı; COUNT(DISTINCT) Prisma'da yok.
   */
  async aggregateFor(userId: string): Promise<SleepAggregate> {
    const [totals, nights] = await Promise.all([
      this.prisma.sleep_sessions.aggregate({
        where: { user_id: userId },
        _count: { _all: true },
        _sum: { duration_minutes: true },
      }),
      this.prisma.sleep_sessions.groupBy({
        by: ['night_date'],
        where: { user_id: userId },
      }),
    ]);
    return {
      nights: nights.length,
      sessionCount: totals._count._all,
      totalDurationMinutes: totals._sum.duration_minutes ?? 0,
    };
  }

  /**
   * Kullanıcının TÜM benzersiz gece tarihleri. **Sınır YOK** (bilinçli):
   * `computeStreak` hem `totalNights` (= tarih sayısı) hem `longest` (tüm zamanların
   * en uzun serisi) için tarihlerin TAMAMINA ihtiyaç duyar. Eskiden `take: 400`
   * vardı → 400+ gecesi olan kullanıcıda ikisi de SESSİZCE yanlıştı.
   * Maliyet küçük: yalnızca distinct tarih kolonu (10 yıl ≈ 3.6k satır).
   */
  async listNightDates(userId: string): Promise<string[]> {
    const rows = await this.prisma.sleep_sessions.findMany({
      where: { user_id: userId },
      distinct: ['night_date'],
      select: { night_date: true },
      orderBy: { night_date: 'desc' },
    });
    return rows.map((r) => r.night_date.toISOString().slice(0, 10));
  }
}
