import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/app/app.dart';
import 'package:nocta/app/flavor.dart';
import 'package:nocta/features/onboarding/onboarding_store.dart';
import 'package:nocta/app/router.dart';
import 'package:nocta/features/auth/auth_providers.dart';

/// Offline-first sözleşmesi — CLAUDE.md §3.1:
/// *"Uygulama offline-first: ses üretimi ve mikser internetsiz TAM çalışır."*
///
/// **NEDEN BU TEST VAR:** kural yazılıydı ama ZORLANMIYORDU ve ihlal ediliyordu.
/// Oturum kurulamadığında (uçak modu, kırsal, sunucu çökmesi) uygulamanın TAMAMI
/// bir "yeniden dene" ikonuna düşüyordu — tamamen yerel olan mikser'e bile
/// ulaşılamıyordu. Ses cihazda üretiliyor; internetle hiçbir ilgisi yok.
///
/// Bu, canlı emülatör koşusunda bulundu (#138): testler yeşilken uygulama açılmadı.
void main() {
  setUp(() {
    FlavorConfig.current = const FlavorConfig(
      flavor: Flavor.dev,
      name: 'DEV',
      apiBaseUrl: 'http://localhost:3001',
    );
    // `appRouter` GLOBAL bir singleton: bir test /mixer'a gidince sonraki test de
    // orada başlar ve "ana ekranda buton yok" diye YANLIŞ patlar. Testler arası
    // sızıntıyı burada kesiyoruz.
    appRouter.go('/');
  });

  Widget appWith(AsyncValue<void> bootstrap) {
    return ProviderScope(
      overrides: [
        // Bu dosya ÇEVRİMDIŞI davranışını doğruluyor, onboarding'i değil →
        // karşılama akışı görülmüş sayılır (ilk açılış kapısı öne geçmesin).
        onboardingSeenProvider.overrideWith((ref) async => true),
        sessionBootstrapProvider.overrideWith((ref) {
          return bootstrap.when(
            data: (_) => Future<void>.value(),
            // Asla tamamlanmayan Completer — `Future.delayed` bekleyen bir TIMER
            // bırakır ve test çerçevesi teardown'da onu hata sayar.
            loading: () => Completer<void>().future,
            error: (e, s) => Future<void>.error(e),
          );
        }),
      ],
      child: const NoctaApp(),
    );
  }

  testWidgets('ÇEKİRDEK: oturum kurulamazsa uygulama KİLİTLENMEZ, açılır', (t) async {
    await t.pumpWidget(appWith(AsyncValue.error(Exception('ağ yok'), StackTrace.empty)));
    await t.pumpAndSettle();

    // Eskiden burada yalnızca bir yeniden-dene ikonu vardı ve mikser erişilemezdi.
    expect(find.byKey(const Key('mixer-cta')), findsOneWidget);
  });

  testWidgets('çevrimdışıyken kullanıcı NEDEN\'ini görür (sessiz boşluk değil)', (t) async {
    await t.pumpWidget(appWith(AsyncValue.error(Exception('ağ yok'), StackTrace.empty)));
    await t.pumpAndSettle();

    expect(find.byKey(const Key('offline-banner')), findsOneWidget);
    expect(find.byKey(const Key('offline-retry')), findsOneWidget);
  });

  testWidgets('ÇEKİRDEK: çevrimdışıyken MİKSER AÇILIR ve ses üretilebilir', (t) async {
    await t.pumpWidget(appWith(AsyncValue.error(Exception('ağ yok'), StackTrace.empty)));
    await t.pumpAndSettle();

    await t.tap(find.byKey(const Key('mixer-cta')));
    await t.pumpAndSettle();

    // Mikser gerçekten açıldı: slider'lar ve çal butonu orada.
    expect(find.byKey(const Key('mixer-toggle')), findsOneWidget);
    expect(find.byKey(const Key('gain-brown')), findsOneWidget);
    expect(find.byKey(const Key('gain-pink')), findsOneWidget);
    expect(find.byKey(const Key('gain-white')), findsOneWidget);
  });

  testWidgets('oturum kurulduğunda çevrimdışı çubuğu GÖRÜNMEZ', (t) async {
    await t.pumpWidget(appWith(const AsyncValue.data(null)));
    await t.pumpAndSettle();

    expect(find.byKey(const Key('offline-banner')), findsNothing);
    expect(find.byKey(const Key('mixer-cta')), findsOneWidget);
  });

  testWidgets('oturum ÇÖZÜLENE KADAR splash (hangi durumdayız bilinmiyor)', (t) async {
    await t.pumpWidget(appWith(const AsyncValue.loading()));
    await t.pump();

    // Splash artık spinner değil, açılış anı (`LaunchMoment`) — sözleşme aynı.
    expect(find.byKey(const Key('launch-moon')), findsOneWidget);
    // Yükleme sırasında çevrimdışı DEMEK yanlış olurdu — henüz bilmiyoruz.
    expect(find.byKey(const Key('offline-banner')), findsNothing);
  });

  testWidgets('ÇEKİRDEK: oturum HİÇ çözülmezse bile üst sınırda uygulama açılır', (t) async {
    // Sonsuz splash regresyonunun kapısı: bootstrap asla tamamlanmasa da
    // kullanıcı çalışan bir uygulamaya (yerel mikser + yeniden dene) girer.
    await t.pumpWidget(appWith(const AsyncValue.loading()));
    await t.pump(const Duration(seconds: 3));
    await t.pumpAndSettle();

    expect(find.byKey(const Key('launch-moon')), findsNothing);
    expect(find.byKey(const Key('mixer-cta')), findsOneWidget);
    expect(find.byKey(const Key('offline-retry')), findsOneWidget);
  });
  // ─────────── Bandı kapatma (ac4852e ile geldi, testi yoktu) ───────────
  //
  // Kapat düğmesi eklendiğinde bir `tooltip` taşıyordu. Bant Navigator'ın
  // (yani Overlay'in) ÜSTÜNDE çizildiği için tooltip "No Overlay" hatası verip
  // bandı ~99.000 px taşırıyordu: bant HER göründüğünde ekran bozuluyordu.
  // Aşağıdaki testler hem çökmeyi hem de yeni davranışı kilitler.
  group('çevrimdışı bandı kapatma', () {
    Future<void> pumpOffline(WidgetTester t) async {
      await t.pumpWidget(
        appWith(AsyncValue.error(Exception('ağ yok'), StackTrace.empty)),
      );
      await t.pumpAndSettle();
    }

    testWidgets('ÇEKİRDEK: kapat düğmesi bandı kaldırır ve hata ÜRETMEZ', (
      t,
    ) async {
      await pumpOffline(t);
      expect(find.byKey(const Key('offline-banner')), findsOneWidget);
      expect(t.takeException(), isNull, reason: 'bant çizilirken hata oluştu');

      await t.tap(find.byKey(const Key('offline-dismiss')));
      await t.pump();

      expect(find.byKey(const Key('offline-banner')), findsNothing);
      // Bant gitti ama uygulama hâlâ kullanılabilir.
      expect(find.byKey(const Key('mixer-cta')), findsOneWidget);
    });

    testWidgets('bant birkaç saniye sonra KENDİLİĞİNDEN kaybolur', (t) async {
      await pumpOffline(t);
      expect(find.byKey(const Key('offline-banner')), findsOneWidget);

      await t.pump(const Duration(seconds: 9));

      expect(find.byKey(const Key('offline-banner')), findsNothing);
    });

    testWidgets('ÇEKİRDEK: bant EKRAN OKUYUCUYA görünür, kapat hedefi ≥44 px', (
      t,
    ) async {
      final semantics = t.ensureSemantics();
      await pumpOffline(t);

      // ÖLÇÜLMÜŞ HATA: bu üç düğüm semantik ağaçta YOKTU. Rotanın
      // `ModalBarrier`'ı (BlockSemantics) aynı kapsayıcıda kendinden önce
      // çizilen bantları siliyordu; ağaçta ana ekranın 20 düğümü vardı, bandın
      // hiçbiri yoktu. Navigator artık ayrı semantik kapsayıcı (app.dart).
      expect(find.semantics.byLabel(RegExp('Offline')), findsOne);
      expect(find.semantics.byLabel('Retry'), findsOne);
      // Kapat düğmesinin adı tooltip'ten değil `semanticLabel`'dan gelir.
      expect(find.semantics.byLabel('Dismiss'), findsOne);

      final size = t.getSize(find.byKey(const Key('offline-dismiss')));
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
      semantics.dispose();
    });
  });
}
