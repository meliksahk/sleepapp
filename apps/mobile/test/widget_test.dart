import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nocta/app/app.dart';
import 'package:nocta/app/flavor.dart';
import 'package:nocta/core/api/nocta_api_client.dart';
import 'package:nocta/core/storage/key_value_store.dart';
import 'package:nocta/core/storage/session_store.dart';
import 'package:nocta/features/auth/auth_providers.dart';
import 'package:nocta/features/onboarding/onboarding_store.dart';

NoctaApiClient _registerClient() {
  final mock = MockClient(
    (req) async => http.Response(
      jsonEncode(<String, dynamic>{
        'accessToken': 'a',
        'refreshToken': 'r',
        'accessTokenExpiresIn': 900,
        'userId': 'u-1',
      }),
      201,
    ),
  );
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

  testWidgets('NoctaApp oturum kurulduktan sonra wordmark ve flavor gösterir', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
          sessionStoreProvider.overrideWithValue(InMemorySessionStore()),
          apiClientProvider.overrideWithValue(_registerClient()),
          // Bu test onboarding'i DEĞİL, oturum sonrası ana ekranı doğruluyor →
          // karşılama akışı görülmüş sayılır (aksi halde ilk açılış kapısı önce gelir).
          onboardingSeenProvider.overrideWith((ref) async => true),
        ],
        child: const NoctaApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('NOCTA'), findsOneWidget);
    expect(find.textContaining('flavor: DEV'), findsOneWidget);
  });
}
