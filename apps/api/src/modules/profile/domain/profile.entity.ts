/** Kullanıcı profili (docs/02 §3 profiles). id = users.id (1:1). Saf domain. */
export interface Profile {
  readonly userId: string;
  readonly displayName: string | null;
  readonly chronotype: string | null;
  readonly locale: string;
  readonly timezone: string;
  /** Push bildirim tercihi (opt-out). Varsayılan açık. */
  readonly notificationsEnabled: boolean;
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
  };
}

/** Kısmi güncelleme — verilmeyen alan değişmez (undefined), null açıkça temizler. */
export interface ProfileUpdate {
  readonly displayName?: string | null;
  readonly chronotype?: string | null;
  readonly locale?: string;
  readonly timezone?: string;
  readonly notificationsEnabled?: boolean;
}
