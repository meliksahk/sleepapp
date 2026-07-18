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

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    // Yükleme sırasında çevrimdışı DEMEK yanlış olurdu — henüz bilmiyoruz.
    expect(find.byKey(const Key('offline-banner')), findsNothing);
  });
}
