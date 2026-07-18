import 'dart:ui' show PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/flavor.dart';
import '../../core/api/nocta_api_client.dart';
import '../../core/device/device_identity.dart';
import '../../core/storage/key_value_store.dart';
import '../../core/storage/session_store.dart';
import '../settings/locale_store.dart';
import 'auth_controller.dart';
import 'session_info.dart';

/// API istemcisi — baseUrl aktif flavor'dan (dev/staging/prod).
///
/// **Dili İZLEMEZ, İSTEK ANINDA OKUR (`read`, `watch` değil).** Bu bilinçli:
/// `watch` etseydik dil değişiminde provider yeniden kurulur, `onDispose` eski
/// `http.Client`'ı kapatır ve onu `read` ile tutan `AuthController` kapanmış bir
/// client'la kalırdı — dil değiştiren kullanıcıda tüm API çağrıları ölürdü
/// (bu hata emülatörde gerçekten yaşandı). Client ömür boyu tek; dili her istekte
/// `resolveLanguage` tazeler.
final apiClientProvider = Provider<NoctaApiClient>((ref) {
  final client = NoctaApiClient(
    baseUrl: FlavorConfig.current.apiBaseUrl,
    // Seçim yoksa (null = sistem dili) CİHAZIN dili kullanılır; o da çözülemezse
    // başlık hiç gönderilmez ve sunucu varsayılanı (EN) geçerli olur.
    resolveLanguage: () {
      final selected = ref.read(appLocaleProvider).maybeWhen(
            data: (l) => l?.languageCode,
            orElse: () => null,
          );
      final language = selected ?? PlatformDispatcher.instance.locale.languageCode;
      return language.isEmpty ? null : language;
    },
  );
  ref.onDispose(client.close);
  return client;
});

/// Oturum saklama — üretimde secure storage (Keychain/Keystore).
final sessionStoreProvider = Provider<SessionStore>((ref) => SecureSessionStore());

/// Küçük string kalıcılık (device-id) — üretimde secure storage.
final keyValueStoreProvider = Provider<KeyValueStore>((ref) => SecureKeyValueStore());

/// Anonim cihaz kimliği (get-or-create, kalıcı).
final deviceIdentityProvider = Provider<DeviceIdentity>(
  (ref) => DeviceIdentity(ref.read(keyValueStoreProvider)),
);

/// Anonim oturum controller'ı.
final authControllerProvider = Provider<AuthController>((ref) {
  return AuthController(ref.read(apiClientProvider), ref.read(sessionStoreProvider));
});

/// Kullanıcının aktif oturumları — settings ekranı cihaz listesi bunu izler.
final activeSessionsProvider = FutureProvider<List<SessionInfo>>((ref) {
  return ref.read(authControllerProvider).listSessions();
});

/// Açılış oturumu: device-id çözülür, kayıtlı oturum yoksa anonim kaydolunur
/// (docs/04 M0). Kök widget bunu izler; çözülene dek splash gösterir.
final sessionBootstrapProvider = FutureProvider<void>((ref) async {
  final deviceId = await ref.read(deviceIdentityProvider).getOrCreate();
  await ref.read(authControllerProvider).ensureSession(deviceId);
});
