import 'dart:convert';
import '../../core/api/nocta_api_client.dart';
import '../../core/api/session.dart';
import '../auth/auth_controller.dart';

/// Feature flag istemcisi (docs/03 A4). `GET /v1/flags` context'iyle (platform +
/// appVersion) değerlendirilmiş haritayı çeker (AuthController.authorizedRequest →
/// 401 refresh). `isEnabled` bilinmeyen/çekilmemiş anahtarda güvenli varsayılan false.
class FeatureFlagsController {
  FeatureFlagsController(
    this._auth,
    this._client, {
    required this.platform,
    required this.appVersion,
  });

  final AuthController _auth;
  final NoctaApiClient _client;
  final String platform;
  final String appVersion;

  Map<String, bool> _flags = <String, bool>{};

  bool isEnabled(String key) => _flags[key] ?? false;

  Map<String, bool> get all => Map<String, bool>.unmodifiable(_flags);

  Future<void> refresh() async {
    final path =
        '/v1/flags?platform=${Uri.encodeQueryComponent(platform)}'
        '&appVersion=${Uri.encodeQueryComponent(appVersion)}';
    final res = await _auth.authorizedRequest((token) => _client.getAuthed(path, token));
    if (res.statusCode != 200) throw ApiException(res.statusCode, res.body);
    final map = jsonDecode(res.body) as Map<String, dynamic>;
    _flags = map.map((k, v) => MapEntry(k, v == true));
  }
}
