import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/core/design_system/widgets/n_card.dart';

void main() {
  testWidgets('NCard verilen child\'ı gösterir', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: NCard(child: Text('içerik'))),
      ),
    );
    expect(find.text('içerik'), findsOneWidget);
  });
}
