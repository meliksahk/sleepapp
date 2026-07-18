import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nocta/app/app.dart';
import 'package:nocta/app/flavor.dart';
import 'package:nocta/core/api/nocta_api_client.dart';
import 'package:nocta/core/api/session.dart';
import 'package:nocta/core/storage/key_value_store.dart';
import 'package:nocta/core/storage/session_store.dart';
import 'package:nocta/features/auth/auth_providers.dart';
import 'package:nocta/features/onboarding/onboarding_store.dart';

NoctaApiClient _registerClient({Duration delay = Duration.zero}) {
  final mock = MockClient((req) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    return http.Response(
      jsonEncode(<String, dynamic>{
        'accessToken': 'a',
        'refreshToken': 'r',
        'accessTokenExpiresIn': 900,
        'userId': 'u-1',
      }),
      201,
    );
  });
  return NoctaApiClient(baseUrl: 'http://x', client: mock);
}

void main() {
  setUp(() {
    FlavorConfig.current = const FlavorConfig(
      flavor: Flavor.dev,
      name: 'DEV',
      apiBaseUrl: 'http://localhost:3001',
    );
  });

  testWidgets('açılışta önce splash (spinner), oturum kurulunca home gelir', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
          // Oturum kapısını doğruluyoruz, onboarding'i değil.
          onboardingSeenProvider.overrideWith((ref) async => true),
          sessionStoreProvider.overrideWithValue(InMemorySessionStore()),
          apiClientProvider.overrideWithValue(
            _registerClient(delay: const Duration(milliseconds: 50)),
          ),
        ],
        child: const NoctaApp(),
      ),
    );

    // İlk kare: FutureProvider henüz çözülmedi (register gecikmeli) → spinner.
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('NOCTA'), findsNothing);

    // Çözülünce home.
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('NOCTA'), findsOneWidget);
  });

  testWidgets('kayıtlı oturum varsa register çağrılmaz (restore → home)', (tester) async {
    final store = InMemorySessionStore();
    await store.save(
      const Session(accessToken: 'a', refreshToken: 'r', accessTokenExpiresIn: 900, userId: 'u-1'),
    );
    // Çağrılırsa test fail eder → restore'un ağ yapmadığını kanıtlar.
    final failClient = NoctaApiClient(
      baseUrl: 'http://x',
      client: MockClient((req) async => fail('restore varken registerDevice çağrılmamalı')),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
          // Oturum kapısını doğruluyoruz, onboarding'i değil.
          onboardingSeenProvider.overrideWith((ref) async => true),
          sessionStoreProvider.overrideWithValue(store),
          apiClientProvider.overrideWithValue(failClient),
        ],
        child: const NoctaApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('NOCTA'), findsOneWidget);
  });
}
