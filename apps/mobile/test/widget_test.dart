import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/app/app.dart';
import 'package:nocta/app/flavor.dart';

void main() {
  testWidgets('NoctaApp iskeleti wordmark ve flavor gösterir', (tester) async {
    FlavorConfig.current = const FlavorConfig(
      flavor: Flavor.dev,
      name: 'DEV',
      apiBaseUrl: 'http://localhost:3001',
    );

    await tester.pumpWidget(const ProviderScope(child: NoctaApp()));
    await tester.pumpAndSettle();

    expect(find.text('NOCTA'), findsOneWidget);
    expect(find.textContaining('flavor: DEV'), findsOneWidget);
  });
}
