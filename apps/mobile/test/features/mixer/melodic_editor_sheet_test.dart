import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/core/audio_engine/dsp/user_melodic.dart';
import 'package:nocta/core/storage/key_value_store.dart';
import 'package:nocta/features/mixer/domain/melodic_preset_store.dart';
import 'package:nocta/features/mixer/presentation/melodic_editor_sheet.dart';
import 'package:nocta/l10n/app_localizations.dart';
import 'package:nocta/l10n/app_localizations_en.dart';
import 'package:nocta/l10n/app_localizations_tr.dart';

/// Melodik editör — bu dosyadan ÖNCE hiç testi yoktu.
///
/// Kilitlenen şey dil: editör 13 sabit Türkçe metin taşıyordu (i18n kapısı
/// bunları buldu, CI'da önceki adım kırmızı olduğu için kapı hiç koşmamıştı)
/// ve ölçek adları ses motorundan doğrudan ekrana basılıyordu: İngilizce
/// kullanıcı "Majör", "Minör" görüyordu.
void main() {
  Future<void> pump(WidgetTester t, Locale locale, {bool isChords = false}) async {
    t.view.physicalSize = const Size(800, 2000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: Scaffold(
          body: MelodicEditorSheet(
            isChords: isChords,
            presetStore: MelodicPresetStore(InMemoryKeyValueStore()),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets('ÇEKİRDEK: İngilizce cihazda Türkçe metin YOK', (t) async {
    await pump(t, const Locale('en'));

    expect(find.text('Root note'), findsOneWidget);
    expect(find.text('Scale'), findsOneWidget);
    expect(find.text('Instrument'), findsOneWidget);
    expect(find.text('Listen'), findsOneWidget);
    // Ölçek adı motor kimliğinden değil çeviriden geliyor.
    expect(find.text('Major'), findsOneWidget);
    expect(find.text('Majör'), findsNothing);
    expect(find.text('Sine'), findsOneWidget);
    for (final turkish in <String>['Kök nota', 'Ölçek', 'Enstrüman', 'Dinle', 'Sinüs']) {
      expect(find.text(turkish), findsNothing, reason: 'EN ekranda Türkçe: $turkish');
    }
  });

  testWidgets('Türkçe cihazda metinler Türkçe', (t) async {
    await pump(t, const Locale('tr'));

    expect(find.text('Kök nota'), findsOneWidget);
    expect(find.text('Ölçek'), findsOneWidget);
    expect(find.text('Majör'), findsOneWidget);
    expect(find.text('Dinle'), findsOneWidget);
  });

  testWidgets('akor modunda Progresyon başlığı görünür, Ölçek görünmez', (t) async {
    await pump(t, const Locale('en'), isChords: true);

    expect(find.text('Progression'), findsOneWidget);
    expect(find.text('Scale'), findsNothing);
  });

  test('ses motorundaki HER ölçeğin iki dilde çevirisi var', () {
    // Motora yeni ölçek eklenip `melodicScaleLabel`'a eklenmezse ekran motor
    // kimliğini (Türkçe) basar. Bu test o boşluğu yakalar.
    for (final l10n in <AppL10n>[AppL10nEn(), AppL10nTr()]) {
      for (final scale in melodicScales) {
        expect(
          melodicScaleLabel(l10n, scale.name),
          isNotNull,
          reason: '${l10n.localeName}: "${scale.name}" ölçeğinin çevirisi yok',
        );
      }
    }
  });
}
