import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/key_value_store.dart';
import '../auth/auth_providers.dart';

/// Açılış imzası (aura) sesi açık mı?
///
/// **Kapatılabilir olması opsiyonel değil, ZORUNLU:** bu bir uyku uygulaması ve
/// açılış sesi gece 23:00'te, yanında biri uyurken çalabilir. Kapatılamayan bir
/// açılış sesi garantili tek yıldızdır. Varsayılan AÇIK (marka aurası ürünün
/// istenen parçası), ama tek dokunuşla susar.
class SignatureSoundStore {
  SignatureSoundStore(this._kv);

  final KeyValueStore _kv;
  static const String key = 'signature_sound_enabled';

  /// Kayıt yoksa AÇIK sayılır.
  Future<bool> isEnabled() async => (await _kv.read(key)) != 'false';

  Future<void> setEnabled(bool value) => _kv.write(key, value ? 'true' : 'false');
}

final signatureSoundStoreProvider = Provider<SignatureSoundStore>(
  (ref) => SignatureSoundStore(ref.read(keyValueStoreProvider)),
);

final signatureSoundEnabledProvider = FutureProvider<bool>(
  (ref) => ref.read(signatureSoundStoreProvider).isEnabled(),
);
