/**
 * Kullanıcının push bildirim opt-out tercihini okuyan port (docs/06).
 * Cross-module: profil modülünün notifications_enabled bayrağına, notification
 * profiles tablosuna DOKUNMADAN, port + module-def adaptörü üzerinden erişir
 * (sleep→profile timezone deseninin aynısı).
 */
export interface NotificationPreferenceReader {
  /** Kullanıcı push bildirimlere izin veriyor mu (profil opt-out bayrağı). */
  isEnabledFor(userId: string): Promise<boolean>;
}

export const NOTIFICATION_PREFERENCE_READER = Symbol('NotificationPreferenceReader');
