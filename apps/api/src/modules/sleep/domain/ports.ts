import type { NewSleepSession, SleepSession } from './sleep-session.entity';

/** sleep_sessions erişimi — her metod userId ile scope'lanır (docs/02 §2.1). */
export interface SleepSessionRepository {
  save(userId: string, session: NewSleepSession): Promise<SleepSession>;
  listRecentByUser(userId: string, limit: number): Promise<SleepSession[]>;
  /** Belirli bir gecenin (YYYY-MM-DD) tüm oturumları. userId ile scope'lu. */
  findByNight(userId: string, nightDate: string): Promise<SleepSession[]>;
  /** Kullanıcının kayıtlı benzersiz gece tarihleri (YYYY-MM-DD, streak için). */
  listNightDates(userId: string): Promise<string[]>;
}

/** Kullanıcı saat dilimini (başka modül) soyut okur — gece gruplaması için. */
export interface ProfileTimezoneReader {
  timezoneFor(userId: string): Promise<string>;
}

/** Zaman kaynağı — test'te sabitlenebilir (streak "bugün" hesabı). */
export type Clock = () => Date;

export const SLEEP_SESSION_REPOSITORY = Symbol('SleepSessionRepository');
export const PROFILE_TIMEZONE_READER = Symbol('ProfileTimezoneReader');
export const CLOCK = Symbol('Clock');
