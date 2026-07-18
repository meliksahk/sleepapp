import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/key_value_store.dart';
import '../auth/auth_providers.dart';

/// Uygulama dili tercihi.
///
/// **Neden gerekli:** çeviriler (EN/TR) baştan beri tamdı ama seçilemiyordu —
/// uygulama yalnızca CİHAZ diline uyuyordu. Türkçe telefonu olmayan bir kullanıcı
/// Türkçe'yi göremiyordu; İngilizce isteyen Türk kullanıcı da telefonunu
/// değiştirmek zorundaydı. Bu, var olan bir yeteneğin erişilemez kalmasıydı.
///
/// `null` = sistem dili (varsayılan). Aksi halde açık seçim kalıcıdır.
class LocaleStore {
  LocaleStore(this._kv);

  final KeyValueStore _kv;
  static const String key = 'app_locale';

  /// Desteklenen diller — `AppL10n.supportedLocales` ile aynı küme olmalı.
  static const List<Locale> supported = <Locale>[Locale('en'), Locale('tr')];

  Future<Locale?> read() async {
    final code = await _kv.read(key);
    if (code == null || code.isEmpty) return null; // sistem
    return supported.where((l) => l.languageCode == code).firstOrNull;
  }

  /// `null` yazmak sistem diline döner.
  Future<void> write(Locale? locale) =>
      _kv.write(key, locale?.languageCode ?? '');
}

final localeStoreProvider = Provider<LocaleStore>(
  (ref) => LocaleStore(ref.read(keyValueStoreProvider)),
);

/// Seçili dil; `null` → sistem dili. Uygulama kökü bunu MaterialApp'e verir.
final appLocaleProvider = FutureProvider<Locale?>(
  (ref) => ref.read(localeStoreProvider).read(),
);
