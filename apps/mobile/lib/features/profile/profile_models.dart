/// Kullanıcı profili (docs/04). API `GET/PATCH /v1/profile` yanıtının mobil görünümü.
/// DTO ≠ entity ayrımı interim; generated client B-3'te tipleri sağlayacak.
class Profile {
  const Profile({
    required this.userId,
    required this.displayName,
    required this.chronotype,
    required this.locale,
    required this.timezone,
    required this.notificationsEnabled,
    required this.reminderHour,
    required this.quietHoursStart,
    required this.quietHoursEnd,
  });

  final String userId;
  final String? displayName;
  final String? chronotype;
  final String locale;
  final String timezone;
  final bool notificationsEnabled;

  /// Akşam hatırlatıcısının saati — KULLANICININ YEREL saati (0-23), UTC değil.
  /// null = hatırlatıcı yok. Sunucu da yerel saat saklıyor (bkz. migration).
  final int? reminderHour;

  /// Sessiz saat aralığı (yerel, 0-23). İkisi de null = sessiz saat yok.
  final int? quietHoursStart;
  final int? quietHoursEnd;

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        userId: json['userId'] as String,
        displayName: json['displayName'] as String?,
        chronotype: json['chronotype'] as String?,
        locale: json['locale'] as String,
        timezone: json['timezone'] as String,
        notificationsEnabled: json['notificationsEnabled'] as bool,
        // Sunucu bu alanları henüz döndürmüyorsa (eski sürüm) null: uygulama
        // kırılmaz, yalnızca hatırlatıcı kapalı görünür.
        reminderHour: json['reminderHour'] as int?,
        quietHoursStart: json['quietHoursStart'] as int?,
        quietHoursEnd: json['quietHoursEnd'] as int?,
      );
}
