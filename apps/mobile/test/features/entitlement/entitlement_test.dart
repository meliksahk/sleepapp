import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nocta/core/api/nocta_api_client.dart';
import 'package:nocta/core/design_system/design_system.dart';
import 'package:nocta/core/storage/session_store.dart';
import 'package:nocta/features/auth/auth_controller.dart';
import 'package:nocta/features/auth/auth_providers.dart';
import 'package:nocta/features/entitlement/entitlement_controller.dart';
import 'package:nocta/features/entitlement/entitlement_models.dart';
import 'package:nocta/features/entitlement/entitlement_providers.dart';
import 'package:nocta/features/settings/presentation/settings_screen.dart';
import 'package:nocta/l10n/app_localizations.dart';

/// Entitlement mobil tüketimi (backend #153'ü uygulamaya bağlar). Cihaz kaydı +
/// `/v1/me/entitlement` yönlendiren MockClient; diğer yollar 404 (ilgisiz bölümler
/// `orElse` ile gizli).
NoctaApiClient _client({required String tier, required bool premium}) {
  final client = MockClient((req) async {
    if (req.url.path == '/v1/auth/device') {
      return http.Response(
        jsonEncode({
          'accessToken': 'a',
          'refreshToken': 'r',
          'accessTokenExpiresIn': 900,
          'userId': 'u-1',
        }),
        201,
      );
    }
    if (req.url.path == '/v1/me/entitlement') {
      return http.Response(jsonEncode({'tier': tier, 'premium': premium}), 200);
    }
    return http.Response('not found', 404);
  });
  return NoctaApiClient(baseUrl: 'http://x', client: client);
}

Future<AuthController> _auth(NoctaApiClient api) async {
  final auth = AuthController(api, InMemorySessionStore());
  await auth.registerAnonymously('fp');
  return auth;
}

void main() {
  group('EntitlementController', () {
    test('ÇEKİRDEK: /v1/me/entitlement çağırır ve yanıtı parse eder (premium)', () async {
      final api = _client(tier: 'plus', premium: true);
      final e = await EntitlementController(await _auth(api), api).get();
      expect(e.tier, 'plus');
      expect(e.premium, isTrue);
    });

    test('free katman parse edilir (premium bayrağı SUNUCUDAN gelir, istemci türetmez)', () async {
      final api = _client(tier: 'free', premium: false);
      final e = await EntitlementController(await _auth(api), api).get();
      expect(e.tier, 'free');
      expect(e.premium, isFalse);
    });
  });

  group('Ayarlar — üyelik durumu', () {
    Future<void> pump(WidgetTester t, Entitlement e) async {
      final api = _client(tier: e.tier, premium: e.premium);
      final auth = await _auth(api);
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWithValue(auth),
            apiClientProvider.overrideWithValue(api),
            entitlementProvider.overrideWith((ref) => e),
          ],
          child: MaterialApp(
            localizationsDelegates: AppL10n.localizationsDelegates,
            supportedLocales: AppL10n.supportedLocales,
            theme: buildNoctaDarkTheme(),
            home: const SettingsScreen(),
          ),
        ),
      );
      await t.pumpAndSettle();
    }

    testWidgets('ÇEKİRDEK: premium kullanıcı "tüm özellikler açık" görür', (t) async {
      await pump(t, const Entitlement(tier: 'plus', premium: true));
      expect(find.byKey(const Key('membership-status')), findsOneWidget);
      expect(find.text('Premium — all features unlocked'), findsOneWidget);
    });

    testWidgets('ÇEKİRDEK: free kullanıcı "Free plan" görür', (t) async {
      await pump(t, const Entitlement(tier: 'free', premium: false));
      expect(find.text('Free plan'), findsOneWidget);
      expect(find.text('Premium — all features unlocked'), findsNothing);
    });
  });
}
