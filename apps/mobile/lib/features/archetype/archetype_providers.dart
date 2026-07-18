import 'dart:ui' show PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../settings/locale_store.dart';
import '../../core/share/sharer.dart';
import '../auth/auth_providers.dart';
import 'archetype_controller.dart';
import 'archetype_models.dart';
import 'archetype_service.dart';
import 'data/archetype_matrix_source.dart';
import 'data/local_archetype_store.dart';
import 'domain/archetype_matrix.dart';

/// Archetype SUNUCU istemcisi — auth (oturum + refresh) + api client üzerine.
/// Artık doğrudan ekranlar tarafından kullanılmaz; [archetypeServiceProvider]'ın
/// (yerel-öncelikli) opsiyonel yedeğidir.
final archetypeControllerProvider = Provider<ArchetypeController>((ref) {
  return ArchetypeController(ref.read(authControllerProvider), ref.read(apiClientProvider));
});

/// Gömülü matris kaynağı — uygulama ömrü boyunca tek (kendi içinde önbellekli).
final archetypeMatrixSourceProvider = Provider<ArchetypeMatrixSource>(
  (ref) => ArchetypeMatrixSource(),
);

/// Sonuçların cihazdaki kalıcı kaydı (shared_preferences).
final localArchetypeStoreProvider = Provider<LocalArchetypeStore>(
  (ref) => PrefsArchetypeStore(),
);

/// **Ekranların kullandığı tek giriş noktası.** Yerel-öncelikli: sorular,
/// puanlama ve tanıtım metni cihazda; sunucu yalnızca best-effort yedek.
final archetypeServiceProvider = Provider<ArchetypeService>((ref) {
  return ArchetypeService(
    matrixSource: ref.read(archetypeMatrixSourceProvider),
    store: ref.read(localArchetypeStoreProvider),
    remote: ref.read(archetypeControllerProvider),
  );
});

/// Aktif dil kodu ('en'/'tr'). Seçim yoksa cihaz dili; o da çözülemezse 'en'.
/// Matris hem EN hem TR metni taşır — bu yüzden ağa ihtiyaç YOK.
Future<String> _resolveLanguage(Ref ref) async {
  final selected = await ref.watch(appLocaleProvider.future);
  final code = selected?.languageCode ??
      PlatformDispatcher.instance.locale.languageCode;
  return code.isEmpty ? ArchetypeMatrix.fallbackLocale : code;
}

/// Paylaşım adaptörü — interim: panoya kopyalar (native share sheet ertelendi).
/// Üretimde native paylaşım sayfası: kart GÖRSEL olarak gider. Pano adaptörü
/// görsel taşıyamaz ve kullanıcıya "git yapıştır" dedirtirdi (bkz. sharer.dart).
final sharerProvider = Provider<Sharer>((ref) => PlatformSharer());

/// Archetype tanıtım içeriği slug→info haritası (sonuç ekranı açıklaması).
///
/// **DİLİ İZLER.** İçerik artık CİHAZDAN gelir ama dile bağlılığı aynen sürer:
/// dil değişince önbellekteki kopya YANLIŞ dilde kalırdı. Gerçekten yaşandı:
/// kullanıcı Türkçeye geçtiğinde sorular Türkçe geldi (ekran açılırken taze
/// çözülüyor) ama sonuç açıklaması İngilizce kaldı — çünkü içerik açılışta bir
/// kez çözülüp önbelleğe alınmıştı. `watch` sayesinde dil değişimi bu provider'ı
/// geçersiz kılar ve içerik yeni dille yeniden çözülür.
///
/// **`watch(...)` değil `watch(....future)`:** dil provider'ı önce `loading`
/// sonra `data` yayınlar. Sadece `watch` etmek içeriği İKİ KEZ çözdürürdü.
final archetypeContentProvider = FutureProvider<Map<String, ArchetypeInfo>>((ref) async {
  final locale = await _resolveLanguage(ref);
  return ref.read(archetypeServiceProvider).content(locale);
});

/// Sihirbazın soruları, aktif dilde. Ağ isteği YOK.
final archetypeQuestionsProvider = FutureProvider<ArchetypeQuestions>((ref) async {
  final locale = await _resolveLanguage(ref);
  return ref.read(archetypeServiceProvider).questions(locale);
});

/// Kullanıcının en son archetype sonucu (henüz test yapılmadıysa null) —
/// home kimlik kartı bunu izler. Yerelden okur.
final latestArchetypeResultProvider = FutureProvider<ArchetypeResult?>((ref) {
  return ref.read(archetypeServiceProvider).latest();
});

/// Sonuç geçmişi (yeniden eskiye) — kimlik geçmişi ekranı + home'daki bağlantı.
final archetypeHistoryProvider = FutureProvider<List<ArchetypeResult>>((ref) {
  return ref.read(archetypeServiceProvider).history();
});
