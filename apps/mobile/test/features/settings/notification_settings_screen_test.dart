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
import 'package:nocta/features/settings/presentation/notification_settings_screen.dart';
import 'package:nocta/l10n/app_localizations.dart';

/// Bildirim ayarları (F3).
///
/// **Neden test:** "alan göndermemek" (dokunma) ile "null göndermek" (temizle)
/// aynı görünür ama sunucuda zıt anlamlıdır. Bu ayrım kaybolursa kullanıcı
/// hatırlatıcısını KAPATAMAZ — kapatma isteği sunucuya hiç ulaşmaz.
void main() {
  late List<Map<String, dynamic>> patches;

  NoctaApiClient mockClient({int? reminderHour}) {
    patches = <Map<String, dynamic>>[];
    var hour = reminderHour;
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
      if (req.url.path == '/v1/profile') {
        if (req.method == 'PATCH') {
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          patches.add(body);
          if (body.containsKey('reminderHour')) {
            hour = body['reminderHour'] as int?;
          }
        }
        return http.Response(
          jsonEncode(<String, dynamic>{
            'userId': 'u-1',
            'displayName': null,
            'chronotype': null,
            'locale': 'en',
            'timezone': 'UTC',
            'notificationsEnabled': true,
            'reminderHour': hour,
            'quietHoursStart': null,
            'quietHoursEnd': null,
          }),
          200,
        );
      }
      return http.Response('not found', 404);
    });
    return NoctaApiClient(baseUrl: 'http://x', client: client);
  }

  Future<void> pump(WidgetTester t, NoctaApiClient api) async {
    final auth = AuthController(api, InMemorySessionStore());
    await auth.registerAnonymously('fp');
    await t.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authControllerProvider.overrideWithValue(auth),
          apiClientProvider.overrideWithValue(api),
        ],
        child: MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          theme: buildNoctaDarkTheme(),
          home: const NotificationSettingsScreen(),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets('hatırlatıcı yokken "kapat" düğmesi HİÇ çıkmaz', (t) async {
    await pump(t, mockClient());
    expect(find.byKey(const Key('notif-reminder-clear')), findsNothing);
    expect(find.text('No reminder'), findsOneWidget);
  });

  testWidgets('ÇEKİRDEK: kapat → sunucuya reminderHour: null GİDER', (t) async {
    final api = mockClient(reminderHour: 22);
    await pump(t, api);

    await t.tap(find.byKey(const Key('notif-reminder-clear')));
    await t.pumpAndSettle();

    expect(patches, isNotEmpty);
    expect(
      patches.first.containsKey('reminderHour'),
      isTrue,
      reason: 'alan hiç gönderilmedi — sunucu "dokunma" diye yorumlar, '
          'hatırlatıcı kapanmaz',
    );
    expect(patches.first['reminderHour'], isNull);
  });

  testWidgets('kurulu hatırlatıcı ekranda saatiyle görünür', (t) async {
    await pump(t, mockClient(reminderHour: 22));
    final label = t
        .widget<Text>(find.byKey(const Key('notif-reminder-value')))
        .data!;
    expect(label.contains('10:00 PM') || label.contains('22:00'), isTrue);
  });
}
