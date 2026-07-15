/** Uyku oturumu (docs/02 §3). Saf domain. YALNIZCA türetilmiş metrikler. */
export interface SleepSession {
  readonly id: string;
  readonly userId: string;
  readonly startedAt: Date;
  readonly endedAt: Date;
  /** Gece etiketi YYYY-MM-DD (kullanıcı yerel günü, 06:00 sınırı). */
  readonly nightDate: string;
  readonly durationMinutes: number;
  readonly movementEvents: number;
  readonly soundEvents: number;
  readonly createdAt: Date;
}

/** Kayıt girişi — on-device türetilmiş; ham mikrofon verisi ASLA (CLAUDE.md §6). */
export interface RecordSleepSessionInput {
  readonly startedAt: Date;
  readonly endedAt: Date;
  readonly movementEvents: number;
  readonly soundEvents: number;
}

/** Persist edilen kayıt (repository'ye giden). nightDate/duration sunucuda türetilir. */
export interface NewSleepSession {
  readonly startedAt: Date;
  readonly endedAt: Date;
  readonly nightDate: string;
  readonly durationMinutes: number;
  readonly movementEvents: number;
  readonly soundEvents: number;
}

/** Uyku süresi (dakika) — sunucuda started/ended'den türetilir, istemciye güvenilmez. */
export function durationMinutes(startedAt: Date, endedAt: Date): number {
  return Math.round((endedAt.getTime() - startedAt.getTime()) / 60_000);
}

/** ended > started olmalı. */
export function isValidRange(startedAt: Date, endedAt: Date): boolean {
  return endedAt.getTime() > startedAt.getTime();
}
