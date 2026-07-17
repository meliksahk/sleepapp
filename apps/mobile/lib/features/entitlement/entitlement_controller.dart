import 'dart:convert';

import '../../core/api/nocta_api_client.dart';
import '../../core/api/session.dart';
import '../auth/auth_controller.dart';
import 'entitlement_models.dart';

/// Entitlement veri katmanı — `GET /v1/me/entitlement` (docs/02 §183).
/// `authorizedRequest` ile sarılı (401'de otomatik refresh+retry). Kapsam token
/// sub'ından gelir; istemci id yollamaz.
class EntitlementController {
  EntitlementController(this._auth, this._client);

  final AuthController _auth;
  final NoctaApiClient _client;

  Future<Entitlement> get() async {
    final res = await _auth.authorizedRequest(
      (token) => _client.getAuthed('/v1/me/entitlement', token),
    );
    if (res.statusCode != 200) throw ApiException(res.statusCode, res.body);
    return Entitlement.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }
}
