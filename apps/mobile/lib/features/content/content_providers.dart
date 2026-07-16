import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_providers.dart';
import 'content_controller.dart';
import 'content_models.dart';

/// İçerik controller'ı — auth (oturum + refresh) + api client üzerine.
final contentControllerProvider = Provider<ContentController>((ref) {
  return ContentController(ref.read(authControllerProvider), ref.read(apiClientProvider));
});

/// Soundscape feed'i — kütüphane ekranı bunu izler. archetype verilmez →
/// sunucu kullanıcının kendi kimliğine göre sıralar (#88).
final soundscapeFeedProvider = FutureProvider<List<Soundscape>>((ref) {
  return ref.read(contentControllerProvider).feed();
});

/// Belirli bir archetype'a uygun soundscape'ler — archetype detay ekranı
/// "sana uygun sesler" bölümü bunu izler. Yalnızca affinity eşleşenler.
final soundscapesForArchetypeProvider = FutureProvider.family<List<Soundscape>, String>((
  ref,
  slug,
) async {
  final list = await ref.read(contentControllerProvider).feed(archetype: slug);
  return list.where((s) => s.archetypeAffinity.contains(slug)).toList();
});

/// Soundscape detayı (slug'a göre); yayınlanmamış/yok → null. Detay ekranı izler.
final soundscapeDetailProvider = FutureProvider.family<SoundscapeDetail?, String>((ref, slug) {
  return ref.read(contentControllerProvider).soundscape(slug);
});

/// En güncel haftalık yayın; yoksa null. Home'daki haftalık kart bunu izler.
final weeklyReleaseProvider = FutureProvider<WeeklyRelease?>((ref) {
  return ref.read(contentControllerProvider).weekly();
});
