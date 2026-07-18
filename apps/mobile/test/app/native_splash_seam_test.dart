import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/core/design_system/design_system.dart';

/// **NATIVE SPLASH → FLUTTER SPLASH DİKİŞİ.**
///
/// Android açılışta önce `flutter_native_splash`ın ürettiği pencereyi gösterir
/// (Flutter motoru ilk kareyi çizene kadar), sonra bizim `LaunchMoment`
/// ekranımız devralır. İki zemin rengi farklı olursa kullanıcı her açılışta
/// GÖRÜNÜR bir renk sıçraması yaşar — "ucuz uygulama" hissinin klasik kaynağı.
///
/// İki değer iki ayrı yerde yaşıyor: `pubspec.yaml` (native, hex string) ve
/// `NoctaColors.bgBase` (Dart token). Aynı olduklarını hiçbir derleyici
/// zorlamıyor; bu test zorluyor.
///
/// **Dürüst sınır:** bu test KAYNAK yapılandırmayı okur. `flutter_native_splash`
/// çıktısı (drawable/background.png) yeniden üretilmediyse eski renkte kalır.
/// Yakaladığı şey ayrışmanın KAYNAĞI: birinin token'ı değiştirip pubspec'i
/// unutması (veya tersi).
void main() {
  String hexOf(int argb) =>
      '#${(argb & 0xFFFFFF).toRadixString(16).toUpperCase().padLeft(6, '0')}';

  test('ÇEKİRDEK: native splash rengi = NoctaColors.bgBase (açılışta sıçrama yok)', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final section = pubspec.substring(pubspec.indexOf('flutter_native_splash:'));

    final colors = RegExp(r'color:\s*"?(#[0-9A-Fa-f]{6})"?')
        .allMatches(section)
        .map((m) => m.group(1)!.toUpperCase())
        .toList();

    // Hem klasik splash hem android_12 bloğu — ikisi de eşleşmeli.
    expect(colors.length, greaterThanOrEqualTo(2),
        reason: 'pubspec içinde splash rengi bulunamadı');

    final expected = hexOf(NoctaColors.bgBase.toARGB32());
    for (final c in colors) {
      expect(c, expected, reason: 'native splash zemini token ile ayrışmış');
    }
  });

  test('token gerçekten opak (yarı saydam zemin native tarafta anlamsız)', () {
    expect(NoctaColors.bgBase.a, 1.0);
  });
}
