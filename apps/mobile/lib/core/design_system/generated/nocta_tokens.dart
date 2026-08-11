// GENERATED — packages/design-tokens/tokens.json'dan üretildi. Elle düzenleme.
// ignore_for_file: constant_identifier_names
import 'package:flutter/material.dart';

/// NOCTA renk token'ları (dark-first — uygulama gece yaşar).
class NoctaColors {
  NoctaColors._();
  static const Color bgBase = Color(0xFF08080A);
  static const Color bgRaised = Color(0xFF0E0D0C);
  static const Color bgOverlay = Color(0xFF131210);
  static const Color bgPaper = Color(0xFFE9E2D4);
  static const Color bgDanger = Color(0xFF170F0D);
  static const Color bgNight = Color(0xFF050506);
  static const Color nightInk = Color(0xFF6B675E);
  static const Color nightFaint = Color(0xFF413E38);
  static const Color nightLine = Color(0xFF2A2723);
  static const Color inkPrimary = Color(0xFFE9E2D4);
  static const Color inkSecondary = Color(0xFFA49E92);
  static const Color inkFaint = Color(0xFF8E877C);
  static const Color inkMute = Color(0xFF6B655C);
  static const Color inkOnPaper = Color(0xFF14140F);
  static const Color inkOnPaperSoft = Color(0xFF57544A);
  static const Color lineHairline = Color(0xFF1C1A17);
  static const Color lineSoft = Color(0xFF26241F);
  static const Color lineStrong = Color(0xFF3A362F);
  static const Color lineDashed = Color(0xFF33302A);
  static const Color lineDanger = Color(0xFF7A4038);
  static const Color accentAurora = Color(0xFFC1442E);
  static const Color accentAuroraInk = Color(0xFFE0765F);
  static const Color accentDawn = Color(0xFFB98A34);
  static const Color accentDeep = Color(0xFF8A8F7A);
  static const Color danger = Color(0xFFC1442E);
}

/// Archetype gradyanları — yalnızca kimlik kartı, rapor başlığı, archetype vurgusu.
class NoctaArchetypeGradient {
  NoctaArchetypeGradient._();
  static const LinearGradient deepOcean = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF0C1110), Color(0xFF8A8F7A)],
  );
  static const LinearGradient overthinker = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF120D0C), Color(0xFFC1442E)],
  );
  static const LinearGradient deltaDrifter = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF0F0E0D), Color(0xFFB79A90)],
  );
  static const LinearGradient dawnChaser = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF131009), Color(0xFFB98A34)],
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
  static const double chip = 0;
  static const double button = 0;
  static const double card = 0;
  static const double sheet = 28;
  static const double full = 9999;
}

/// Tipografi ölçeği (punto).
class NoctaFontSize {
  NoctaFontSize._();
  static const double micro = 11;
  static const double caption = 13;
  static const double body = 15;
  static const double h2 = 26;
  static const double h1 = 33;
  static const double display = 42;
}

/// Yazı aileleri. Uygulamada üç ses: serif başlık, mono etiket, sans gövde.
class NoctaFont {
  NoctaFont._();
  static const String display = 'Instrument Serif';
  static const String body = 'Inter';
  static const String mono = 'IBM Plex Mono';
}

/// Mono etiketlerin harf aralığı (punto).
class NoctaTrack {
  NoctaTrack._();
  static const double tight = 1;
  static const double label = 2;
  static const double wide = 3;
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
      fontFamily: NoctaFont.body,
    ),
    dividerTheme: const DividerThemeData(
      color: NoctaColors.lineHairline,
      thickness: 1,
      space: 1,
    ),
    // Kolajda AppBar bir yüzey değil, kağıdın üstündeki boşluk: zeminsiz ve gölgesiz.
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      foregroundColor: NoctaColors.inkPrimary,
      titleTextStyle: TextStyle(
        fontFamily: NoctaFont.mono,
        fontSize: NoctaFontSize.micro,
        letterSpacing: NoctaTrack.label,
        color: NoctaColors.inkSecondary,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: NoctaColors.bgRaised,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(NoctaRadius.sheet)),
      ),
    ),
  );
}
