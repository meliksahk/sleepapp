import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/core/storage/key_value_store.dart';
import 'package:nocta/features/settings/signature_sound_store.dart';

/// Açılış aurası anahtarı.
///
/// **Neden test:** ses kapatılabilir OLMALI (uyku uygulaması, gece çalıyor).
/// Varsayılanın AÇIK, kapatmanın KALICI olması ürün kararı — regresyona kapalı olsun.
void main() {
  test('ÇEKİRDEK: varsayılan AÇIK (kayıt yokken)', () async {
    expect(await SignatureSoundStore(InMemoryKeyValueStore()).isEnabled(), isTrue);
  });

  test('ÇEKİRDEK: kapatma KALICI (uygulama yeniden açılsa da kapalı)', () async {
    final kv = InMemoryKeyValueStore();
    await SignatureSoundStore(kv).setEnabled(false);
    expect(await SignatureSoundStore(kv).isEnabled(), isFalse);
  });

  test('tekrar açılabilir', () async {
    final kv = InMemoryKeyValueStore();
    final store = SignatureSoundStore(kv);
    await store.setEnabled(false);
    await store.setEnabled(true);
    expect(await store.isEnabled(), isTrue);
  });
}
