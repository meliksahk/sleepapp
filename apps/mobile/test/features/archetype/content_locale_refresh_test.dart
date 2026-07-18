import 'dart:ui' show Locale;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/features/archetype/archetype_models.dart';
import 'package:nocta/features/archetype/archetype_providers.dart';
import 'package:nocta/features/archetype/archetype_service.dart';
import 'package:nocta/features/archetype/data/local_archetype_store.dart';
import 'package:nocta/features/settings/locale_store.dart';

import 'archetype_test_support.dart';

/// İçerik çözümünü SAYAN servis — matris artık cihazda, ama dile bağlılığı aynı.
class _CountingService extends ArchetypeService {
  _CountingService()
      : super(matrixSource: testMatrixSource(), store: InMemoryArchetypeStore());

  int contentCalls = 0;
  final List<String> locales = <String>[];

  @override
  Future<Map<String, ArchetypeInfo>> content(String locale) {
    contentCalls++;
    locales.add(locale);
    return super.content(locale);
  }
}

/// REGRESYON KİLİDİ: dil değişince arketip içeriği de tazelenmeli.
///
/// Yaşanan hata: kullanıcı Türkçeye geçtiğinde arketip SORULARI Türkçe geldi (ekran
/// açılırken taze çözülüyor) ama SONUÇ AÇIKLAMASI İngilizce kaldı — çünkü tanıtım
/// içeriği uygulama açılışında bir kez çözülüp önbelleğe alınmıştı ve dil değişimi
/// onu geçersiz kılmıyordu. Ekranın yarısı Türkçe, yarısı İngilizce görünüyordu.
///
/// İçerik SUNUCUDAN değil artık GÖMÜLÜ MATRİSTEN geliyor (backend'siz APK'da da
/// çalışsın diye) — ama kilit aynen geçerli: kaynak değişti, kural değişmedi.
void main() {
  test('dil değişince archetypeContentProvider YENİDEN çözer', () async {
    final service = _CountingService();
    var locale = const Locale('en');
    final container = ProviderContainer(
      overrides: [
        archetypeServiceProvider.overrideWithValue(service),
        appLocaleProvider.overrideWith((ref) async => locale),
      ],
    );
    addTearDown(container.dispose);

    final en = await container.read(archetypeContentProvider.future);
    expect(service.contentCalls, 1);
    expect(en['deep-ocean']?.tagline, contains('stillness'));

    // Aynı dilde tekrar okumak yeniden çözmemeli (önbellek çalışıyor).
    await container.read(archetypeContentProvider.future);
    expect(service.contentCalls, 1);

    // Kullanıcı ayarlardan dili değiştirdi → dil provider'ı geçersiz kılınır.
    locale = const Locale('tr');
    container.invalidate(appLocaleProvider);
    final tr = await container.read(archetypeContentProvider.future);

    expect(
      service.contentCalls,
      2,
      reason: 'dil değişti → içerik yeni dille YENİDEN çözülmeliydi '
          '(archetypeContentProvider appLocaleProvider\'ı watch etmiyor)',
    );
    expect(service.locales, <String>['en', 'tr']);
    // Ve gerçekten TÜRKÇE metin geldi — sayacın artması tek başına yetmez.
    expect(tr['deep-ocean']?.tagline, contains('dibe çökersin'));
  });
}
