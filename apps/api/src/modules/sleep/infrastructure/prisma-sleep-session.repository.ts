import type { PrismaService } from '../../../shared/infra/prisma.service';
import type { SleepSessionRepository } from '../domain/ports';
import type { NewSleepSession, SleepSession } from '../domain/sleep-session.entity';

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
  constructor(private readonly prisma: PrismaService) {}

  async save(userId: string, session: NewSleepSession): Promise<SleepSession> {
    const row = await this.prisma.sleep_sessions.create({
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
}
