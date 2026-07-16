import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_providers.dart';
import 'analytics.dart';
import 'product_analytics.dart';

/// Ürün analitiği — oturum boyunca tek instance (tampon paylaşılır). UI `Analytics`
/// arayüzüne bağlanır; test'te spy ile override edilir.
final analyticsProvider = Provider<Analytics>((ref) {
  return ProductAnalytics(ref.read(authControllerProvider), ref.read(apiClientProvider));
});
