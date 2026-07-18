import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/core/design_system/widgets/n_selectable_option.dart';

void main() {
  testWidgets('etiketi gösterir ve dokunmayı iletir', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NSelectableOption(
            label: 'Hemen dalıyorum',
            selected: false,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Hemen dalıyorum'), findsOneWidget);
    await tester.tap(find.byType(NSelectableOption));
    expect(tapped, isTrue);
  });

  testWidgets('ÇEKİRDEK: seçili hal renkten BAŞKA bir işaret taşır', (
    tester,
  ) async {
    // Seçimi yalnızca renkle anlatmak düşük kontrastlı ekranda ve renk körlüğünde
    // kaybolur; tik ikonu şekil düzeyinde ayrım sağlar.
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: <Widget>[
              NSelectableOption(label: 'seçili', selected: true),
              NSelectableOption(label: 'boş', selected: false),
            ],
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('dokunma hedefi en az 44px (CLAUDE.md §7)', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: NSelectableOption(label: 'X', selected: false)),
        ),
      ),
    );
    expect(
      tester.getSize(find.byType(NSelectableOption)).height,
      greaterThanOrEqualTo(44),
    );
  });

  testWidgets('uzun etiket sarar, taşmaz (TR metinleri EN\'den uzun)', (
    tester,
  ) async {
    const longLabel =
        'Gece boyunca birkaç kez uyanır, tekrar dalmak için uzun süre beklerim';
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: NSelectableOption(label: longLabel, selected: false),
          ),
        ),
      ),
    );

    expect(find.text(longLabel), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
