import 'package:flutter/material.dart';

/// Ekran genişliğine göre responsive kararlar.
///
/// **Kırılım noktaları (Material 3 convention):**
/// - `< 600` → mobil (mevcut düzen, DOKUNULMAZ)
/// - `600–840` → dar tablet (içerik tam genişlik, fontlar aynı)
/// - `> 840` → geniş tablet/desktop (çok sütunlu grid, geniş padding)
class Responsive {
  const Responsive(this.width);

  final double width;

  static Responsive of(BuildContext context) =>
      Responsive(MediaQuery.sizeOf(context).width);

  bool get isMobile => width < 600;
  bool get isTablet => width >= 600 && width < 1024;
  bool get isWide => width >= 600;

  /// İçerik alanının yatay padding'i — tablette daha nefesli.
  EdgeInsets get horizontalPadding =>
      EdgeInsets.all(isWide ? 32 : 24);

  /// Kart grid'inde kaç sütun? Mobilde tek sütun; geniş ekranda 2–3.
  int get gridColumns {
    if (width >= 900) return 3;
    if (width >= 600) return 2;
    return 1;
  }
}
