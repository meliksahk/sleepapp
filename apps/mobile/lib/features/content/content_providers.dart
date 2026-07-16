import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_providers.dart';
import 'content_controller.dart';
import 'content_models.dart';

/// İçerik controller'ı — auth (oturum + refresh) + api client üzerine.
final contentControllerProvider = Provider<ContentController>((ref) {
  return ContentController(ref.read(authControllerProvider), ref.read(apiClientProvider));
});

/// Soundscape feed'i — kütüphane ekranı bunu izler.
final soundscapeFeedProvider = FutureProvider<List<Soundscape>>((ref) {
  return ref.read(contentControllerProvider).feed();
});
