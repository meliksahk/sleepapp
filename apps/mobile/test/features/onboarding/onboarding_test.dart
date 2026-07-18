import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/core/storage/key_value_store.dart';
import 'package:nocta/features/onboarding/onboarding_store.dart';
import 'package:nocta/features/onboarding/presentation/onboarding_screen.dart';
import 'package:nocta/l10n/app_localizations.dart';

Widget _wrap(Widget child) => MaterialApp(
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      home: child,
    );

void main() {
  group('OnboardingStore', () {
    test('ÇEKİRDEK: ilk açılışta görülmemiş; markSeen sonrası KALICI görülmüş', () async {
      final kv = InMemoryKeyValueStore();
      final store = OnboardingStore(kv);

      expect(await store.hasSeen(), isFalse);
      await store.markSeen();
      expect(await store.hasSeen(), isTrue);

      // Yeni bir store örneği aynı depodan okur → kalıcılık (uygulama yeniden açılsa da).
      expect(await OnboardingStore(kv).hasSeen(), isTrue);
    });
  });

  group('OnboardingScreen', () {
    testWidgets('ilk sayfa görünür; CTA ilerletir; SON sayfada onDone çağrılır', (t) async {
      var done = 0;
      await t.pumpWidget(_wrap(OnboardingScreen(onDone: () async => done++)));
      await t.pumpAndSettle();

      // 1. sayfa
      expect(find.text('Your night has an identity'), findsOneWidget);
      expect(done, 0);

      // 2. sayfaya ilerle
      await t.tap(find.byKey(const Key('onboarding-cta')));
      await t.pumpAndSettle();
      expect(find.text('Build your night ritual'), findsOneWidget);

      // 3. (son) sayfaya ilerle — henüz bitmedi
      await t.tap(find.byKey(const Key('onboarding-cta')));
      await t.pumpAndSettle();
      expect(find.text('Wake up gently'), findsOneWidget);
      expect(done, 0);

      // Son sayfada CTA akışı BİTİRİR
      await t.tap(find.byKey(const Key('onboarding-cta')));
      await t.pumpAndSettle();
      expect(done, 1);
    });

    testWidgets('ÇEKİRDEK: Atla kullanıcıyı akışta hapsetmez — hemen bitirir', (t) async {
      var done = 0;
      await t.pumpWidget(_wrap(OnboardingScreen(onDone: () async => done++)));
      await t.pumpAndSettle();

      await t.tap(find.byKey(const Key('onboarding-skip')));
      await t.pumpAndSettle();
      expect(done, 1);
    });

    testWidgets('izin priming sayfası ham sesin telefonda kaldığını SÖYLER (§6)', (t) async {
      await t.pumpWidget(_wrap(OnboardingScreen(onDone: () async {})));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('onboarding-cta')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('onboarding-cta')));
      await t.pumpAndSettle();

      // Gizlilik vaadi kullanıcıya AÇIKÇA gösterilir — sessizce mikrofon istemek yok.
      expect(find.textContaining('raw audio never leaves'), findsOneWidget);
    });
  });

  group('onboardingSeenProvider (ilk açılış kapısı)', () {
    test('boş depoda false döner → karşılama gösterilir', () async {
      final container = ProviderContainer(
        overrides: [
          keyValueStoreProviderForTest(InMemoryKeyValueStore()),
        ],
      );
      addTearDown(container.dispose);
      expect(await container.read(onboardingSeenProvider.future), isFalse);
    });
  });
}

/// `keyValueStoreProvider` auth_providers'ta; testte override için küçük yardımcı.
Override keyValueStoreProviderForTest(KeyValueStore store) =>
    onboardingStoreProvider.overrideWithValue(OnboardingStore(store));
