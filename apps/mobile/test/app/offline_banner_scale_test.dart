import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nocta/app/app.dart';
import 'package:nocta/app/flavor.dart';
import 'package:nocta/features/auth/auth_providers.dart';
import 'package:nocta/features/onboarding/onboarding_store.dart';
import 'package:nocta/features/settings/locale_store.dart';

/// §7 REGRESYON KİLİDİ — çevrimdışı bandı YAZI ÖLÇEĞİNDE taşmamalı.
///
/// C görevinin denetiminde ölçülerek bulundu: bant `Row` kullanıyordu ve
/// "Yeniden dene" düğmesi ESNEK DEĞİLDİ. Büyük ölçekte düğme tek başına ekranı
/// aşıyor, metne yer kalmıyordu. Ölçülen (320×568, TR, ana ekran): ölçek 1.3 →
/// 903 px, 2.0 → 1376 px taşma. Bant HER ekranda olduğu için mikserdeki §7
/// düzeltmesi bu kombinasyonda kullanıcıya hiç ulaşmıyordu.
void main() {
  setUp(() {
    FlavorConfig.current = const FlavorConfig(
      flavor: Flavor.dev,
      name: 'DEV',
      apiBaseUrl: 'http://localhost:3001',
    );
  });

  for (final locale in <String>['tr', 'en']) {
    for (final scale in <double>[1.0, 1.3, 1.6, 2.0]) {
      testWidgets('§7 · çevrimdışı bandı · $locale · ölçek $scale', (tester) async {
        tester.view.physicalSize = const Size(320 * 2, 568 * 2);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              onboardingSeenProvider.overrideWith((ref) async => true),
              appLocaleProvider.overrideWith((ref) async => Locale(locale)),
              sessionBootstrapProvider.overrideWith(
                (ref) async => throw Exception('offline'),
              ),
            ],
            child: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: const NoctaApp(),
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 3));

        expect(
          tester.takeException(),
          isNull,
          reason: '$locale ölçek $scale: bant taşmamalı',
        );
      });
    }
  }
}
