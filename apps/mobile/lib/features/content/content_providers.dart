import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/flavor.dart';
import '../auth/auth_providers.dart';
import 'content_controller.dart';
import 'content_models.dart';
import 'content_service.dart';
import 'data/content_library_source.dart';

/// İçerik controller'ı — auth (oturum + refresh) + api client üzerine.
final contentControllerProvider = Provider<ContentController>((ref) {
  return ContentController(ref.read(authControllerProvider), ref.read(apiClientProvider));
});

/// APK'ya gömülü kütüphane (üretilen asset). Uygulama ömrü boyunca tek örnek:
/// ayrıştırma bir kez yapılır (bkz. [ContentLibrarySource] önbellek notu).
final contentLibrarySourceProvider = Provider<ContentLibrarySource>((ref) {
  return ContentLibrarySource();
});

/// Ekranların gördüğü tek içerik kapısı — **yerel-öncelikli**.
///
/// Sunucu istemcisi yalnızca ağ AÇIKKEN bağlanır: API adresi yapılandırılmamış
/// bir flavor'da (bkz. `FlavorConfig.hasApi`) `remote` null'dır ve servis hiç ağ
/// denemesi yapmaz — boşuna timeout beklenmez.
final contentServiceProvider = Provider<ContentService>((ref) {
  return ContentService(
    library: ref.read(contentLibrarySourceProvider),
    remote: FlavorConfig.current.hasApi ? ref.read(contentControllerProvider) : null,
  );
});

/// Soundscape feed'i — kütüphane ekranı bunu izler. Sunucu yanıt verirse onun
/// listesi, vermezse gömülü kütüphane (asla boş ekran).
final soundscapeFeedProvider = FutureProvider<List<Soundscape>>((ref) {
  return ref.read(contentServiceProvider).feed();
});

/// Belirli bir archetype'a uygun soundscape'ler — archetype detay ekranı
/// "sana uygun sesler" bölümü bunu izler. Yalnızca affinity eşleşenler.
final soundscapesForArchetypeProvider = FutureProvider.family<List<Soundscape>, String>((
  ref,
  slug,
) async {
  final list = await ref.read(contentServiceProvider).feed(archetype: slug);
  return list.where((s) => s.archetypeAffinity.contains(slug)).toList();
});

/// Soundscape detayı (slug'a göre); hiçbir kaynakta yoksa null. Detay ekranı izler.
final soundscapeDetailProvider = FutureProvider.family<SoundscapeDetail?, String>((ref, slug) {
  return ref.read(contentServiceProvider).soundscape(slug);
});

/// Kullanıcının kendi ses dosyaları kataloğu — mikserdeki "Ses ekle" sayfası
/// bunu izler.
///
/// **GÖMÜLÜ YEDEĞİ YOK, olamaz da:** bunlar sunucudaki MinIO nesneleridir; APK'ya
/// gömülecek bir karşılıkları yoktur. Ağ kapalıyken liste BOŞ döner (hata değil):
/// ekran kendi "henüz ses dosyası yok" durumunu gösterir. Mikserin jeneratif
/// katmanları bundan etkilenmez.
///
/// **URL TAŞIMAZ** (sunucu listede imza dağıtmaz). Çalmak için seçilen kaydın
/// [audioAssetDetailProvider]'ına gidilir.
final audioAssetCatalogProvider = FutureProvider<List<AudioAsset>>((ref) async {
  if (!FlavorConfig.current.hasApi) return const <AudioAsset>[];
  return ref.read(contentControllerProvider).audioAssets();
});

/// Tek ses dosyası + KISA ÖMÜRLÜ presigned URL.
///
/// **Neden `autoDispose`:** URL dakikalar içinde ölür. Cache'te tutulan bir
/// yanıt, gece yarısı eklenmek istenen katmanın süresi dolmuş bir adresle
/// yüklenmesi (yani çalmayan bir sürgü) demek olurdu. Sayfa kapanınca düşer,
/// bir sonraki ekleme taze URL alır.
final audioAssetDetailProvider =
    FutureProvider.autoDispose.family<AudioAssetDetail?, String>((ref, id) async {
  if (!FlavorConfig.current.hasApi) return null;
  return ref.read(contentControllerProvider).audioAsset(id);
});

/// En güncel haftalık yayın; hiçbir kaynakta yoksa null. Home'daki haftalık kart
/// bunu izler.
final weeklyReleaseProvider = FutureProvider<WeeklyRelease?>((ref) {
  return ref.read(contentServiceProvider).weekly();
});
