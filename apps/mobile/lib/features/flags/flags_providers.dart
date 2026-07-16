import 'dart:io' show Platform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_providers.dart';
import 'feature_flags_controller.dart';

/// Uygulama sürümü — flag minAppVersion segmenti için (pubspec ile senkron).
const String kAppVersion = '1.0.0';

String _currentPlatform() {
  if (Platform.isIOS) return 'ios';
  if (Platform.isAndroid) return 'android';
  return 'flutter';
}

/// Feature flag controller'ı — oturum boyunca tek instance (harita paylaşılır).
final featureFlagsControllerProvider = Provider<FeatureFlagsController>((ref) {
  return FeatureFlagsController(
    ref.read(authControllerProvider),
    ref.read(apiClientProvider),
    platform: _currentPlatform(),
    appVersion: kAppVersion,
  );
});
