import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_providers.dart';
import 'profile_controller.dart';
import 'profile_models.dart';

/// Profil controller'ı — auth + api client'ı bağlar.
final profileControllerProvider = Provider<ProfileController>((ref) {
  return ProfileController(ref.read(authControllerProvider), ref.read(apiClientProvider));
});

/// Kullanıcı profili — ayarlar ekranı bildirim toggle'ı bunu izler.
final profileProvider = FutureProvider<Profile>((ref) {
  return ref.read(profileControllerProvider).get();
});
