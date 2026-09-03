/** Kullanıcı profili (docs/02 §3 profiles). id = users.id (1:1). Saf domain. */
export interface Profile {
  readonly userId: string;
  readonly displayName: string | null;
  readonly chronotype: string | null;
  readonly locale: string;
  readonly timezone: string;
  /** Push bildirim tercihi (opt-out). Varsayılan açık. */
  readonly notificationsEnabled: boolean;
  /**
   * Akşam hatırlatıcısının saati — KULLANICININ YEREL saati (0-23), UTC değil.
   * null = hatırlatıcı yok. "23:00'te hatırlat" kullanıcının duvar saatidir;
   * UTC'de saklasaydık seyahatte ve yaz saatinde kayardı.
   */
  readonly reminderHour: number | null;
  /** Sessiz saat aralığı (yerel, 0-23). İkisi de null = sessiz saat yok. */
  readonly quietHoursStart: number | null;
  readonly quietHoursEnd: number | null;
}

/** Henüz satırı olmayan kullanıcı için varsayılan projeksiyon (persist edilmez). */
export function defaultProfile(userId: string): Profile {
  return {
    userId,
    displayName: null,
    chronotype: null,
    locale: 'en',
    timezone: 'UTC',
    notificationsEnabled: true,
    reminderHour: null,
    quietHoursStart: null,
    quietHoursEnd: null,
  };
}

/** Kısmi güncelleme — verilmeyen alan değişmez (undefined), null açıkça temizler. */
export interface ProfileUpdate {
  readonly displayName?: string | null;
  readonly chronotype?: string | null;
  readonly locale?: string;
  readonly timezone?: string;
  readonly notificationsEnabled?: boolean;
  readonly reminderHour?: number | null;
  readonly quietHoursStart?: number | null;
  readonly quietHoursEnd?: number | null;
}
