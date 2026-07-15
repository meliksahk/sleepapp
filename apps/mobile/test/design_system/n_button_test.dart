import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/core/design_system/widgets/n_button.dart';

void main() {
  testWidgets('NButton label gösterir ve tıklamayı iletir', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NButton(label: 'Başla', onPressed: () => tapped = true),
        ),
      ),
    );

    expect(find.text('Başla'), findsOneWidget);
    await tester.tap(find.text('Başla'));
    expect(tapped, isTrue);
  });

  testWidgets('dokunma hedefi en az 44px (erişilebilirlik)', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: NButton(label: 'X'))),
      ),
    );
    final Size size = tester.getSize(find.byType(NButton));
    expect(size.height, greaterThanOrEqualTo(44));
  });
}
