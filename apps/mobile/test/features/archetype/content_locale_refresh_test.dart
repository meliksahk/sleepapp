import 'dart:ui' show Locale;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/features/archetype/archetype_controller.dart';
import 'package:nocta/features/archetype/archetype_models.dart';
import 'package:nocta/features/archetype/archetype_providers.dart';
import 'package:nocta/features/settings/locale_store.dart';

/// Yalnızca [fetchContent] çağrı sayısını sayar — diğer uçlar bu testte kullanılmaz.
class _CountingController implements ArchetypeController {
  int fetchContentCalls = 0;

  @override
  Future<List<ArchetypeInfo>> fetchContent() async {
    fetchContentCalls++;
    return const <ArchetypeInfo>[];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('bu test yalnızca fetchContent kullanır');
}

/// REGRESYON KİLİDİ: dil değişince SUNUCU İÇERİĞİ de tazelenmeli.
///
/// Yaşanan hata: kullanıcı Türkçeye geçtiğinde arketip SORULARI Türkçe geldi (ekran
/// açılırken taze çekiliyor) ama SONUÇ AÇIKLAMASI İngilizce kaldı — çünkü tanıtım
/// içeriği uygulama açılışında bir kez çekilip önbelleğe alınmıştı ve dil değişimi
/// onu geçersiz kılmıyordu. Ekranın yarısı Türkçe, yarısı İngilizce görünüyordu.
void main() {
  test('dil değişince archetypeContentProvider YENİDEN çeker', () async {
    final controller = _CountingController();
    final container = ProviderContainer(
      overrides: [
        archetypeControllerProvider.overrideWithValue(controller),
        appLocaleProvider.overrideWith((ref) async => const Locale('en')),
      ],
    );
    addTearDown(container.dispose);

    await container.read(archetypeContentProvider.future);
    expect(controller.fetchContentCalls, 1);

    // Aynı dilde tekrar okumak yeniden çekmemeli (önbellek çalışıyor).
    await container.read(archetypeContentProvider.future);
    expect(controller.fetchContentCalls, 1);

    // Kullanıcı ayarlardan dili değiştirdi → dil provider'ı geçersiz kılınır.
    container.invalidate(appLocaleProvider);
    await container.read(archetypeContentProvider.future);

    expect(
      controller.fetchContentCalls,
      2,
      reason: 'dil değişti → içerik yeni dille YENİDEN çekilmeliydi '
          '(archetypeContentProvider appLocaleProvider\'ı watch etmiyor)',
    );
  });
}
