import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../api/session.dart';

/// Oturum token'larının kalıcılığı. Soyutlama sayesinde test in-memory ile,
/// üretim secure storage ile çalışır.
abstract class SessionStore {
  Future<void> save(Session session);
  Future<Session?> read();
  Future<void> clear();
}

/// Test/mock için bellekte tutan store.
class InMemorySessionStore implements SessionStore {
  Session? _session;

  @override
  Future<void> save(Session session) async => _session = session;

  @override
  Future<Session?> read() async => _session;

  @override
  Future<void> clear() async => _session = null;
}

/// Üretim — flutter_secure_storage (Keychain/Keystore). Cihazda doğrulanır.
class SecureSessionStore implements SessionStore {
  SecureSessionStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'nocta.session';
  final FlutterSecureStorage _storage;

  @override
  Future<void> save(Session session) async {
    await _storage.write(
      key: _key,
      value: jsonEncode(<String, dynamic>{
        'accessToken': session.accessToken,
        'refreshToken': session.refreshToken,
        'accessTokenExpiresIn': session.accessTokenExpiresIn,
        'userId': session.userId,
      }),
    );
  }

  @override
  Future<Session?> read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    return Session.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> clear() async => _storage.delete(key: _key);
}
