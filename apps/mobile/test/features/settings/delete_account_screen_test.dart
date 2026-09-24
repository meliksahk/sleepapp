import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';
import 'package:http/testing.dart';
import 'package:nocta/core/api/nocta_api_client.dart';
import 'package:nocta/core/design_system/design_system.dart';
import 'package:nocta/core/storage/session_store.dart';
import 'package:nocta/features/auth/auth_controller.dart';
import 'package:nocta/features/auth/auth_providers.dart';
import 'package:nocta/features/settings/presentation/delete_account_screen.dart';
import 'package:nocta/l10n/app_localizations.dart';

/// Hesap silme — **App Store'un uygulama-içi silme zorunluluğu**.
///
/// Sunucu ucu (`DELETE /v1/auth/me`) aylardır hazırdı ve kullanıcı ona hiç
/// ulaşamıyordu. Bu testler kapının gerçekten açıldığını ve YANLIŞLIKLA
/// açılmadığını sabitler.
void main() {
  late List<String> calls;

  NoctaApiClient mockClient({int deleteStatus = 204}) {
    calls = <String>[];
    final client = MockClient((req) async {
      calls.add('${req.method} ${req.url.path}');
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
      if (req.url.path == '/v1/auth/me' && req.method == 'DELETE') {
        return http.Response('', deleteStatus);
      }
      return http.Response('not found', 404);
    });
    return NoctaApiClient(baseUrl: 'http://x', client: client);
  }

  Future<(AuthController, InMemorySessionStore)> authWith(
    NoctaApiClient api,
  ) async {
    final store = InMemorySessionStore();
    final auth = AuthController(api, store);
    await auth.registerAnonymously('fp');
    return (auth, store);
  }

  /// GERÇEK `GoRouter` ile kurulur: ekran silme sonrası `router.go('/')`
  /// çağırıyor ve bunu `GoRouter.of(context)` ile alıyor. Router'sız bir
  /// `MaterialApp`'te o satır daha ilk anda patlıyor — yani router'sız test
  /// "silme çalışmıyor" derdi ve sebebi ürün değil kurulum olurdu.
  Future<void> pump(WidgetTester t, AuthController auth) async {
    final router = GoRouter(
      initialLocation: '/settings/delete-account',
      routes: <RouteBase>[
        GoRoute(path: '/', builder: (c, s) => const Scaffold(body: Text('kök'))),
        GoRoute(
          path: '/settings/delete-account',
          builder: (c, s) => const DeleteAccountScreen(),
        ),
      ],
    );
    await t.pumpWidget(
      ProviderScope(
        overrides: <Override>[authControllerProvider.overrideWithValue(auth)],
        child: MaterialApp.router(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          theme: buildNoctaDarkTheme(),
          routerConfig: router,
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets('ÇEKİRDEK: onay kutusu işaretlenmeden silme İSTEĞİ GİTMEZ', (
    t,
  ) async {
    final api = mockClient();
    final (auth, _) = await authWith(api);
    await pump(t, auth);

    // Buton görünür ama pasif — kullanıcı basar, hiçbir şey olmaz.
    await t.tap(find.byKey(const Key('delete-account-cta')));
    await t.pumpAndSettle();

    expect(
      calls.where((c) => c.startsWith('DELETE')),
      isEmpty,
      reason: 'onaysız silme isteği gitti — tek dokunuşluk veri kaybı',
    );
  });

  testWidgets('ÇEKİRDEK: onay + sil → sunucuya DELETE gider, oturum temizlenir', (
    t,
  ) async {
    final api = mockClient();
    final (auth, store) = await authWith(api);
    await pump(t, auth);

    // Onay kutusu 600px'lik test penceresinde katlamanın altında (gerçek
    // telefonda görünür) — önce görünür alana getir.
    await t.ensureVisible(find.byKey(const Key('delete-account-confirm')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('delete-account-confirm')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('delete-account-cta')));
    await t.pumpAndSettle();

    expect(calls, contains('DELETE /v1/auth/me'));
    expect(
      await store.read(),
      isNull,
      reason: 'sunucu sildi ama yerel oturum duruyor',
    );
  });

  testWidgets('sunucu reddederse OTURUM DURUR (hesap yarı silinmiş kalmaz)', (
    t,
  ) async {
    final api = mockClient(deleteStatus: 500);
    final (auth, store) = await authWith(api);
    await pump(t, auth);

    // Onay kutusu 600px'lik test penceresinde katlamanın altında (gerçek
    // telefonda görünür) — önce görünür alana getir.
    await t.ensureVisible(find.byKey(const Key('delete-account-confirm')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('delete-account-confirm')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('delete-account-cta')));
    await t.pumpAndSettle();

    // Hata mesajı çıkar VE kullanıcı hâlâ giriş yapmış durumda: sunucu hesabı
    // silmediyse istemci de kullanıcıyı dışarı atmamalı.
    expect(find.text('We couldn\'t delete your account. Nothing was removed.'),
        findsOneWidget);
    expect(await store.read(), isNotNull);
  });
}
