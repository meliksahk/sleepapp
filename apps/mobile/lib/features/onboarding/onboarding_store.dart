import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/key_value_store.dart';
import '../auth/auth_providers.dart';

/// İlk açılış karşılama akışının "görüldü" durumu.
///
/// Neden kalıcı: onboarding YALNIZCA ilk açılışta gösterilir; her açılışta tekrar
/// göstermek kullanıcıyı bıktırır. Anahtar sürümlü (`_v1`) — ileride akış değişip
/// yeniden göstermek gerekirse sürüm artırılır, eski kullanıcılar bir kez daha görür.
class OnboardingStore {
  OnboardingStore(this._kv);

  final KeyValueStore _kv;
  static const String key = 'onboarding_seen_v1';

  Future<bool> hasSeen() async => (await _kv.read(key)) == 'true';

  Future<void> markSeen() => _kv.write(key, 'true');
}

final onboardingStoreProvider = Provider<OnboardingStore>(
  (ref) => OnboardingStore(ref.read(keyValueStoreProvider)),
);

/// İlk açılış mı? Uygulama kökü bunu bekler (çözülene dek splash).
final onboardingSeenProvider = FutureProvider<bool>(
  (ref) => ref.read(onboardingStoreProvider).hasSeen(),
);
