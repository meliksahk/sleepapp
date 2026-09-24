import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/core/design_system/design_system.dart';

/// Bu dosyanın tek işi **sessiz düşüşü** yakalamak.
///
/// Flutter bildirilmeyen bir aileyi hata vermeden yutar: `fontFamily: 'X'` yazar,
/// X bundle edilmemişse Roboto çizer ve hiçbir yerde uyarı çıkmaz. Tasarım
/// "uygulandı" görünür ama uygulanmamıştır — bu repoda bir kez yaşandı
/// (bkz. pubspec.yaml'daki Inter notu).
void main() {
  test('ÇEKİRDEK: NoctaFont ailelerinin ÜÇÜ de pubspec içinde bundle edilmiş', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final families = RegExp(r'-\s*family:\s*(.+)')
        .allMatches(pubspec)
        .map((m) => m.group(1)!.trim())
        .toSet();

    for (final family in <String>[NoctaFont.display, NoctaFont.body, NoctaFont.mono]) {
      expect(
        families,
        contains(family),
        reason:
            '"$family" pubspec fonts bölümünde yok — uygulama bu ailede sessizce '
            'Roboto çizer. Ya font dosyasını ekle ya token\'ı düzelt.',
      );
    }
  });

  test('bildirilen her font dosyası GERÇEKTEN diskte', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final assets = RegExp(r'-\s*asset:\s*(assets/fonts/\S+)')
        .allMatches(pubspec)
        .map((m) => m.group(1)!)
        .toList();

    expect(assets, isNotEmpty);
    for (final path in assets) {
      expect(File(path).existsSync(), isTrue, reason: '$path bildirildi ama yok');
    }
  });
}
