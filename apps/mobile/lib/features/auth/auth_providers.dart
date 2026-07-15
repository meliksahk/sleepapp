import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/flavor.dart';
import '../../core/api/nocta_api_client.dart';
import '../../core/storage/session_store.dart';
import 'auth_controller.dart';

/// API istemcisi — baseUrl aktif flavor'dan (dev/staging/prod).
final apiClientProvider = Provider<NoctaApiClient>((ref) {
  final client = NoctaApiClient(baseUrl: FlavorConfig.current.apiBaseUrl);
  ref.onDispose(client.close);
  return client;
});

/// Oturum saklama — üretimde secure storage (Keychain/Keystore).
final sessionStoreProvider = Provider<SessionStore>((ref) => SecureSessionStore());

/// Anonim oturum controller'ı.
final authControllerProvider = Provider<AuthController>((ref) {
  return AuthController(ref.read(apiClientProvider), ref.read(sessionStoreProvider));
});
