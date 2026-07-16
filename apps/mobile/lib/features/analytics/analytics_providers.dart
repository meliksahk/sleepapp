import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_providers.dart';
import 'product_analytics.dart';

/// Ürün analitiği — oturum boyunca tek instance (tampon paylaşılır).
final productAnalyticsProvider = Provider<ProductAnalytics>((ref) {
  return ProductAnalytics(ref.read(authControllerProvider), ref.read(apiClientProvider));
});
