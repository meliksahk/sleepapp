/// Oturum token çifti (POST /v1/auth/device yanıtı). Üretilen client gelince
/// api_client paketindeki modelle değişecek (interim).
class Session {
  const Session({
    required this.accessToken,
    required this.refreshToken,
    required this.accessTokenExpiresIn,
    required this.userId,
  });

  final String accessToken;
  final String refreshToken;
  final int accessTokenExpiresIn;
  final String userId;

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      accessTokenExpiresIn: json['accessTokenExpiresIn'] as int,
      userId: json['userId'] as String,
    );
  }
}

/// API hata sözleşmesi (RFC7807 problem+json ileride tiplenecek).
class ApiException implements Exception {
  const ApiException(this.statusCode, this.body);

  final int statusCode;
  final String body;

  @override
  String toString() => 'ApiException($statusCode): $body';
}
