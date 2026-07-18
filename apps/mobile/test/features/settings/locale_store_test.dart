import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/core/storage/key_value_store.dart';
import 'package:nocta/features/settings/locale_store.dart';
import 'package:nocta/l10n/app_localizations.dart';

/// Dil tercihi. Çeviriler baştan beri tamdı ama SEÇİLEMİYORDU (yalnız cihaz dili).
void main() {
  test('ÇEKİRDEK: varsayılan sistem dili (null)', () async {
    expect(await LocaleStore(InMemoryKeyValueStore()).read(), isNull);
  });

  test('ÇEKİRDEK: seçim KALICI (uygulama yeniden açılsa da)', () async {
    final kv = InMemoryKeyValueStore();
    await LocaleStore(kv).write(const Locale('tr'));
    expect((await LocaleStore(kv).read())?.languageCode, 'tr');
  });

  test('sisteme geri dönülebilir', () async {
    final kv = InMemoryKeyValueStore();
    final store = LocaleStore(kv);
    await store.write(const Locale('tr'));
    await store.write(null);
    expect(await store.read(), isNull);
  });

  test('ÇEKİRDEK: desteklenen diller AppL10n ile AYNI (sessiz sapma olmasın)', () {
    final appCodes = AppL10n.supportedLocales.map((l) => l.languageCode).toSet();
    final storeCodes = LocaleStore.supported.map((l) => l.languageCode).toSet();
    expect(storeCodes, appCodes);
  });

  test('bilinmeyen kod sisteme düşer (bozuk veri çökmesin)', () async {
    final kv = InMemoryKeyValueStore();
    await kv.write(LocaleStore.key, 'xx');
    expect(await LocaleStore(kv).read(), isNull);
  });
}
