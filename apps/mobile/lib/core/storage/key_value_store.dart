import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Basit string key-value kalıcılık soyutlaması (device-id gibi küçük değerler).
/// Soyutlama sayesinde test in-memory, üretim secure storage ile çalışır.
abstract class KeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

/// Test/mock için bellekte tutan store.
class InMemoryKeyValueStore implements KeyValueStore {
  final Map<String, String> _data = <String, String>{};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async => _data[key] = value;
}

/// Üretim — flutter_secure_storage (Keychain/Keystore). Cihazda doğrulanır.
class SecureKeyValueStore implements KeyValueStore {
  SecureKeyValueStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);
}
