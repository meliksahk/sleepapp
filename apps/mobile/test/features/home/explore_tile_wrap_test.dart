import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/core/design_system/design_system.dart';
import 'package:nocta/l10n/app_localizations.dart';

/// # KELİME ORTASINDAN BÖLÜNME — regresyon kilidi
///
/// Ana ekrandaki keşfet karosunda Türkçe etiket "Soundscape’le / re göz at" diye
/// bölünüyordu: karonun metin alanına SIĞMAYAN tek bir kelime, Flutter'ın satır
/// kırıcısı tarafından ortadan ikiye ayrılır. Sonuç bozuk bir kelime — bir uyku
/// uygulamasında "yarım bitmiş" izlenimi veren türden bir kusur.
///
/// **Kural:** karo etiketindeki HİÇBİR kelime, karonun metin alanından geniş
/// olamaz. Bu sağlanırsa kırıcı yalnızca boşluklarda böler.
///
/// Bu kilit metnin KENDİSİNİ test eder (arb'deki her dil için), widget ağacını
/// değil: kusur çeviriyle gelir, düzenle değil.

/// En dar gerçek durum: 360dp ekran, ana ekranın s5 yatay dolgusu, iki eşit
/// karo arasında s3 boşluk, karo içinde NCard'ın s4 dolgusu.
const double _screenWidth = 360;
const double _tileTextWidth =
    (_screenWidth - NoctaSpace.s5 * 2 - NoctaSpace.s3) / 2 - NoctaSpace.s4 * 2;

double _wordWidth(String word, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: word, style: style),
    textDirection: TextDirection.ltr,
  )..layout();
  return painter.width;
}

void main() {
  // ExploreTile etiket stili (bkz. explore_tile.dart) — uygulamanın GERÇEK yazı
  // tipiyle. `flutter test`in varsayılan yedek fontu her glifi kare sayar
  // (16px → her harf 16px); onunla ölçmek "soundscapes" gibi normal bir İngilizce
  // kelimeyi bile taşmış gösterirdi. Gerçek metrikler için Inter yüklenir.
  const style = TextStyle(fontFamily: 'Inter', fontSize: NoctaFontSize.body);

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final loader = FontLoader('Inter')
      ..addFont(
        File('assets/fonts/Inter-400.ttf')
            .readAsBytes()
            .then((b) => ByteData.view(Uint8List.fromList(b).buffer)),
      );
    await loader.load();
  });

  for (final locale in AppL10n.supportedLocales) {
    testWidgets(
      '${locale.languageCode}: keşfet karosu etiketlerinde kelime ortadan bölünmez',
      (tester) async {
        final l10n = await AppL10n.delegate.load(locale);
        final labels = <String, String>{
          'homeBrowseSoundscapes': l10n.homeBrowseSoundscapes,
          'sleepHistoryTitle': l10n.sleepHistoryTitle,
        };

        for (final entry in labels.entries) {
          for (final word in entry.value.split(RegExp(r'\s+'))) {
            expect(
              _wordWidth(word, style),
              lessThanOrEqualTo(_tileTextWidth),
              reason:
                  '"$word" (${entry.key}, ${locale.languageCode}) karo metin '
                  'alanından (${_tileTextWidth.toStringAsFixed(0)}px) geniş — '
                  'satır kırıcı bu kelimeyi ORTADAN böler. Etiketi kısaltın.',
            );
          }
        }
      },
    );
  }
}
