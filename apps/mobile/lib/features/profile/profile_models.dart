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
  });

  final String userId;
  final String? displayName;
  final String? chronotype;
  final String locale;
  final String timezone;
  final bool notificationsEnabled;

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        userId: json['userId'] as String,
        displayName: json['displayName'] as String?,
        chronotype: json['chronotype'] as String?,
        locale: json['locale'] as String,
        timezone: json['timezone'] as String,
        notificationsEnabled: json['notificationsEnabled'] as bool,
      );
}
