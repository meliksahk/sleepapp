import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/core/design_system/generated/nocta_tokens.dart';

/// WCAG AA kontrast nöbetçisi (CLAUDE.md §7).
///
/// `inkFaint` bir kez AA'yı ihlal etti (bg üzerinde 3.22:1, eşik 4.5). Bu test o
/// regresyonu kalıcı olarak kapatır: token yeniden soluklaştırılırsa build kırılır.
double _lum(Color c) {
  double ch(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double _ratio(Color a, Color b) {
  final la = _lum(a), lb = _lum(b);
  final hi = math.max(la, lb), lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  test('ÇEKİRDEK: metin renkleri bg-base üzerinde WCAG AA (>=4.5:1)', () {
    final bg = NoctaColors.bgBase;
    expect(_ratio(NoctaColors.inkPrimary, bg), greaterThanOrEqualTo(4.5));
    expect(_ratio(NoctaColors.inkSecondary, bg), greaterThanOrEqualTo(4.5));
    // Bu satır bir zamanlar 3.22:1 ile KIRMIZIYDI.
    expect(_ratio(NoctaColors.inkFaint, bg), greaterThanOrEqualTo(4.5));
  });
}
