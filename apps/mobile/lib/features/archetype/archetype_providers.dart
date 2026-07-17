import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/share/sharer.dart';
import '../auth/auth_providers.dart';
import 'archetype_controller.dart';
import 'archetype_models.dart';

/// Archetype test controller'ı — auth (oturum + refresh) + api client üzerine.
final archetypeControllerProvider = Provider<ArchetypeController>((ref) {
  return ArchetypeController(ref.read(authControllerProvider), ref.read(apiClientProvider));
});

/// Paylaşım adaptörü — interim: panoya kopyalar (native share sheet ertelendi).
/// Üretimde native paylaşım sayfası: kart GÖRSEL olarak gider. Pano adaptörü
/// görsel taşıyamaz ve kullanıcıya "git yapıştır" dedirtirdi (bkz. sharer.dart).
final sharerProvider = Provider<Sharer>((ref) => PlatformSharer());

/// Archetype tanıtım içeriği slug→info haritası (sonuç ekranı açıklaması).
final archetypeContentProvider = FutureProvider<Map<String, ArchetypeInfo>>((ref) async {
  final list = await ref.read(archetypeControllerProvider).fetchContent();
  return {for (final info in list) info.slug: info};
});

/// Kullanıcının en son archetype sonucu (henüz test yapılmadıysa null) —
/// home kimlik kartı bunu izler.
final latestArchetypeResultProvider = FutureProvider<ArchetypeResult?>((ref) {
  return ref.read(archetypeControllerProvider).latestResult();
});

/// Sonuç geçmişi (yeniden eskiye) — kimlik geçmişi ekranı + home'daki bağlantı.
final archetypeHistoryProvider = FutureProvider<List<ArchetypeResult>>((ref) {
  return ref.read(archetypeControllerProvider).listResults();
});
