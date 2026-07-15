import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_providers.dart';
import 'sleep_controller.dart';

/// Uyku controller'ı — auth (oturum + refresh) + api client üzerine.
final sleepControllerProvider = Provider<SleepController>((ref) {
  return SleepController(ref.read(authControllerProvider), ref.read(apiClientProvider));
});
