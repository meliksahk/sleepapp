// GENERATED — packages/design-tokens/tokens.json'dan üretildi. Elle düzenleme.
// ignore_for_file: constant_identifier_names
import 'package:flutter/material.dart';

/// NOCTA renk token'ları (dark-first — uygulama gece yaşar).
class NoctaColors {
  NoctaColors._();
  static const Color bgBase = Color(0xFF0A0E1A);
  static const Color bgRaised = Color(0xFF111629);
  static const Color bgOverlay = Color(0xFF1A2138);
  static const Color inkPrimary = Color(0xFFF2F4FF);
  static const Color inkSecondary = Color(0xFF9AA3C7);
  static const Color inkFaint = Color(0xFF5A6284);
  static const Color accentAurora = Color(0xFF7C6CFF);
  static const Color accentDawn = Color(0xFFFFB489);
  static const Color accentDeep = Color(0xFF2EC5B6);
  static const Color danger = Color(0xFFFF6B7A);
}

/// Archetype gradyanları — yalnızca kimlik kartı, rapor başlığı, archetype vurgusu.
class NoctaArchetypeGradient {
  NoctaArchetypeGradient._();
  static const LinearGradient deepOcean = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF1B3B6F), Color(0xFF0FA3B1)],
  );
  static const LinearGradient overthinker = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF4A2C6F), Color(0xFF7C6CFF)],
  );
  static const LinearGradient deltaDrifter = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF0F2E2A), Color(0xFF2EC5B6)],
  );
  static const LinearGradient dawnChaser = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF6F3A2C), Color(0xFFFFB489)],
  );
}

/// Boşluk ölçeği (4px birim).
class NoctaSpace {
  NoctaSpace._();
  static const double s0 = 0;
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 20;
  static const double s6 = 24;
  static const double s8 = 32;
}

/// Köşe yarıçapları.
class NoctaRadius {
  NoctaRadius._();
  static const double chip = 12;
  static const double button = 16;
  static const double card = 20;
  static const double sheet = 28;
  static const double full = 9999;
}

/// Tipografi ölçeği (punto).
class NoctaFontSize {
  NoctaFontSize._();
  static const double micro = 11;
  static const double caption = 13;
  static const double body = 16;
  static const double h2 = 22;
  static const double h1 = 28;
  static const double display = 34;
}

/// Uygulamanın dark tema ThemeData'sı — token'lardan üretilir.
ThemeData buildNoctaDarkTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: NoctaColors.bgBase,
    colorScheme: base.colorScheme.copyWith(
      brightness: Brightness.dark,
      primary: NoctaColors.accentAurora,
      secondary: NoctaColors.accentDeep,
      surface: NoctaColors.bgRaised,
      error: NoctaColors.danger,
      onSurface: NoctaColors.inkPrimary,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: NoctaColors.inkPrimary,
      displayColor: NoctaColors.inkPrimary,
      fontFamily: 'Inter',
    ),
  );
}
