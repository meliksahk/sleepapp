/// Aktif oturum özeti (GET /v1/auth/sessions). Token HİÇ taşınmaz — yalnızca meta.
class SessionInfo {
  const SessionInfo({
    required this.familyId,
    required this.createdAt,
    required this.expiresAt,
  });

  final String familyId;
  final String createdAt;
  final String expiresAt;

  factory SessionInfo.fromJson(Map<String, dynamic> json) => SessionInfo(
        familyId: json['familyId'] as String,
        createdAt: json['createdAt'] as String,
        expiresAt: json['expiresAt'] as String,
      );
}
