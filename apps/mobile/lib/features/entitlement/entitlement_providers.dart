import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import 'entitlement_controller.dart';
import 'entitlement_models.dart';

/// Entitlement controller'ı — auth + api client'ı bağlar (profil deseniyle aynı).
final entitlementControllerProvider = Provider<EntitlementController>((ref) {
  return EntitlementController(ref.read(authControllerProvider), ref.read(apiClientProvider));
});

/// Kullanıcının premium durumu — ayarlar/paywall bunu izler. Premium özellikler
/// eklendiğinde `entitlement.premium` üzerinden gate edilir; mekanizma burada.
final entitlementProvider = FutureProvider<Entitlement>((ref) {
  return ref.read(entitlementControllerProvider).get();
});
