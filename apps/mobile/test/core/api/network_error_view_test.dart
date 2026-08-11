import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/app/flavor.dart';
import 'package:nocta/core/api/network_error_view.dart';
import 'package:nocta/core/design_system/design_system.dart';
import 'package:nocta/l10n/app_localizations.dart';

/// **Ağ kapalıyken "bağlantını kontrol et" YALANDIR** (F0).
///
/// Kurulu APK'da `apiBaseUrl` boş — istemci hiç soket açmıyor. O hâlde
/// kullanıcıya Wi-Fi'ını kontrol ettirmek ve işlemeyecek bir "yeniden dene"
/// düğmesi göstermek, hatanın kendisinden daha kötü.
void main() {
  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      theme: buildNoctaDarkTheme(),
      home: Scaffold(
        body: NetworkErrorView(
          retryKey: const Key('retry'),
          onRetry: () {},
        ),
      ),
    ),
  );

  testWidgets('ağ KAPALI: dürüst metin + yeniden dene düğmesi YOK', (
    tester,
  ) async {
    FlavorConfig.current = const FlavorConfig(
      flavor: Flavor.prod,
      name: 'PROD',
      apiBaseUrl: '',
    );

    await pump(tester);

    expect(find.byKey(const Key('retry')), findsNothing);
    expect(find.textContaining('Check your connection'), findsNothing);
    expect(find.textContaining('needs an account connection'), findsOneWidget);
  });

  testWidgets('ağ AÇIK: eski davranış — gerçek bağlantı hatası + yeniden dene', (
    tester,
  ) async {
    FlavorConfig.current = const FlavorConfig(
      flavor: Flavor.dev,
      name: 'DEV',
      apiBaseUrl: 'http://localhost:3001',
    );

    await pump(tester);

    expect(find.byKey(const Key('retry')), findsOneWidget);
    expect(find.textContaining('Check your connection'), findsOneWidget);
  });
}
