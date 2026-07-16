import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nocta/core/api/nocta_api_client.dart';
import 'package:nocta/core/design_system/design_system.dart';
import 'package:nocta/l10n/app_localizations.dart';
import 'package:nocta/core/storage/session_store.dart';
import 'package:nocta/features/auth/auth_controller.dart';
import 'package:nocta/features/auth/auth_providers.dart';
import 'package:nocta/features/auth/session_info.dart';
import 'package:nocta/features/settings/presentation/settings_screen.dart';

/// Cihaz + profil + revoke uçlarını yönlendiren MockClient. Profil bildirim
/// durumu değiştirilebilir tutulur; PATCH onu günceller (kalıcılık simülasyonu).
NoctaApiClient _mockClient({int revoked = 0, bool notificationsEnabled = true}) {
  var notifications = notificationsEnabled;
  final client = MockClient((req) async {
    if (req.url.path == '/v1/auth/device') {
      return http.Response(
        jsonEncode(<String, dynamic>{
          'accessToken': 'a',
          'refreshToken': 'r',
          'accessTokenExpiresIn': 900,
          'userId': 'u-1',
        }),
        201,
      );
    }
    if (req.url.path == '/v1/auth/sessions/revoke-others') {
      return http.Response(jsonEncode(<String, dynamic>{'revoked': revoked}), 200);
    }
    if (req.url.path == '/v1/profile') {
      if (req.method == 'PATCH') {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        if (body['notificationsEnabled'] is bool) {
          notifications = body['notificationsEnabled'] as bool;
        }
      }
      return http.Response(
        jsonEncode(<String, dynamic>{
          'userId': 'u-1',
          'displayName': null,
          'chronotype': null,
          'locale': 'en',
          'timezone': 'UTC',
          'notificationsEnabled': notifications,
        }),
        200,
      );
    }
    return http.Response('not found', 404);
  });
  return NoctaApiClient(baseUrl: 'http://x', client: client);
}

Future<AuthController> _authWith(NoctaApiClient api) async {
  final auth = AuthController(api, InMemorySessionStore());
  await auth.registerAnonymously('fp');
  return auth;
}

Future<void> _pump(WidgetTester tester, NoctaApiClient api, AuthController auth) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        authControllerProvider.overrideWithValue(auth),
        apiClientProvider.overrideWithValue(api),
      ],
      child: MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        theme: buildNoctaDarkTheme(),
        home: const SettingsScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('diğer cihazlardan çık → sayı SnackBar\'da (çoğul)', (tester) async {
    final api = _mockClient(revoked: 2);
    await _pump(tester, api, await _authWith(api));
    await tester.tap(find.byKey(const Key('revoke-others')));
    await tester.pumpAndSettle();
    expect(find.text('2 other devices signed out'), findsOneWidget);
  });

  testWidgets('tek cihaz → tekil metin', (tester) async {
    final api = _mockClient(revoked: 1);
    await _pump(tester, api, await _authWith(api));
    await tester.tap(find.byKey(const Key('revoke-others')));
    await tester.pumpAndSettle();
    expect(find.text('1 other device signed out'), findsOneWidget);
  });

  testWidgets('aktif cihaz sayısı gösterilir', (tester) async {
    final api = _mockClient();
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authControllerProvider.overrideWithValue(await _authWith(api)),
          apiClientProvider.overrideWithValue(api),
          activeSessionsProvider.overrideWith(
            (ref) async => const [
              SessionInfo(familyId: 'a', createdAt: '2026-01-01', expiresAt: '2026-02-01'),
              SessionInfo(familyId: 'b', createdAt: '2026-01-02', expiresAt: '2026-02-02'),
            ],
          ),
        ],
        child: MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        theme: buildNoctaDarkTheme(),
        home: const SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('active-devices')), findsOneWidget);
    expect(find.text('Active devices: 2'), findsOneWidget);
  });

  testWidgets('bildirim toggle profil değerini yansıtır (açık)', (tester) async {
    final api = _mockClient(notificationsEnabled: true);
    await _pump(tester, api, await _authWith(api));
    final toggle = tester.widget<SwitchListTile>(find.byKey(const Key('notifications-toggle')));
    expect(toggle.value, isTrue);
  });

  testWidgets('toggle kapatınca PATCH edilir ve switch kapanır', (tester) async {
    final api = _mockClient(notificationsEnabled: true);
    await _pump(tester, api, await _authWith(api));
    expect(
      tester.widget<SwitchListTile>(find.byKey(const Key('notifications-toggle'))).value,
      isTrue,
    );

    await tester.tap(find.byKey(const Key('notifications-toggle')));
    await tester.pumpAndSettle();

    // invalidate sonrası GET güncel (kapalı) değeri döner.
    expect(
      tester.widget<SwitchListTile>(find.byKey(const Key('notifications-toggle'))).value,
      isFalse,
    );
  });
}
