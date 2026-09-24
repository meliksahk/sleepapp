import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nocta/core/design_system/design_system.dart';
import 'package:nocta/features/sleep/presentation/mic_permission_screen.dart';
import 'package:nocta/l10n/app_localizations.dart';

/// Mikrofon izin gerekçesi (F2) — sistemin izin kutusundan ÖNCE.
///
/// **Neden test:** bir kez reddedilen mikrofon izni geri alınmak için sistem
/// ayarlarına gitmeyi gerektirir. İlk kutu tek şansımız; bu ekran o kutuya
/// gerekçesiz gidilmesini engelliyor.
void main() {
  /// Dönüş değeri SONRA okunsun diye kutuya yazılır: `pump` tap'ten hemen
  /// sonra dönüyor, pop henüz olmadı. İlk hâlinde doğrudan `result` döndürüp
  /// `isNull` iddia ediyordum — test GEÇİYORDU ama hiçbir şey kanıtlamıyordu.
  Future<List<bool?>> pump(WidgetTester t, {bool denied = false}) async {
    final box = <bool?>[null];
    final router = GoRouter(
      initialLocation: '/',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (c, s) => Scaffold(
            body: Center(
              child: TextButton(
                key: const Key('open'),
                onPressed: () async {
                  box[0] = await c.push<bool>(
                    '/mic${denied ? '?denied=1' : ''}',
                  );
                },
                child: const Text('aç'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/mic',
          builder: (c, s) => MicPermissionScreen(
            denied: s.uri.queryParameters['denied'] == '1',
          ),
        ),
      ],
    );
    await t.pumpWidget(
      MaterialApp.router(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        theme: buildNoctaDarkTheme(),
        routerConfig: router,
      ),
    );
    await t.tap(find.byKey(const Key('open')));
    await t.pumpAndSettle();
    return box;
  }

  testWidgets('ÇEKİRDEK: gerekçe ekranı üç maddeyi de söyler', (t) async {
    await pump(t);
    expect(find.byKey(const Key('mic-permission-title')), findsOneWidget);
    // "Hayır dersen ritüel yine çalışır" cümlesi PAZARLIKSIZ: kullanıcıya
    // izin vermezse uygulamanın işe yaramayacağı izlenimi vermek baskıdır.
    expect(
      find.textContaining('the ritual still works'),
      findsOneWidget,
      reason: 'izin vermemenin bedelsiz olduğu söylenmiyor',
    );
  });

  testWidgets('ÇEKİRDEK: "devam" TRUE döndürür (çağıran kaydı başlatır)', (
    t,
  ) async {
    final box = await pump(t);
    await t.tap(find.byKey(const Key('mic-permission-allow')));
    await t.pumpAndSettle();
    expect(box[0], isTrue);
  });

  testWidgets('ÇEKİRDEK: "şimdi değil" FALSE döndürür (kayıt BAŞLAMAZ)', (
    t,
  ) async {
    final box = await pump(t);
    await t.tap(find.byKey(const Key('mic-permission-skip')));
    await t.pumpAndSettle();
    expect(
      box[0],
      isFalse,
      reason: 'reddi true dönerse kullanıcı istemediği hâlde kaydedilir',
    );
  });

  testWidgets('reddedilmişse NE KAYBETTİĞİNİ söyleyen blok çıkar', (t) async {
    await pump(t, denied: true);
    expect(find.byKey(const Key('mic-permission-denied')), findsOneWidget);
  });

  testWidgets('reddedilmemişse o blok YOK (gereksiz korku üretme)', (t) async {
    await pump(t);
    expect(find.byKey(const Key('mic-permission-denied')), findsNothing);
  });
}
