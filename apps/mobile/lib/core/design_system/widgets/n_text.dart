// ignore_for_file: prefer_initializing_formals
// Gerekçe: parametre DIŞARIDA `key` olarak görünmeli (çağıranlar `key:`
// yazıyor), alan ise özel. `this._key` yazılamaz: adlandırılmış parametre
// adı `_` ile başlayamaz.
import 'package:flutter/material.dart';

import '../generated/nocta_tokens.dart';

/// Elegy'nin üç sesinden ikisi: **mono mikro etiket** ve **serif başlık**.
/// (Üçüncüsü gövde metni — o tema varsayılanı, ayrı bileşen gerekmiyor.)
///
/// **Neden bileşen:** tasarımda bu iki stil ~150 yerde geçiyor. Her çağrı yerinde
/// elle `TextStyle` kurmak, aile/aralık/renk üçlüsünün er ya da geç sapması demek.

/// Büyük harf, geniş aralıklı mono etiket — sistemin imzası.
///
/// **Büyük harfe ÇEVİRMEZ.** `String.toUpperCase()` Türkçe'de `i → I` üretir
/// (`İ` olmalı); dizgeyi doğru yazmak i18n dosyasının işidir (`app_tr.arb`).
class NMono extends StatelessWidget {
  /// [key] BİLEREK `super.key` DEĞİL: anahtar sarmalayıcıya değil içteki
  /// `Text`e takılır. Testler `t.widget<Text>(find.byKey(...))` diye okuyor;
  /// anahtar dışarıda kalsaydı her çağrı yeri "NDisplay is not a subtype of
  /// Text" ile kırılırdı ve bileşen kullanılamaz olurdu.
  const NMono(
    this.text, {
    Key? key,
    this.color,
    this.size,
    this.track,
    this.height = 1.4,
    this.maxLines,
    this.textAlign,
  }) : _key = key,
       super(key: null);

  /// Sarmalayıcı ANAHTARSIZ kalır (`super(key: null)`), anahtar aşağıdaki
  /// `Text`e iner. İkisine birden verilirse `find.byKey` İKİ eşleşme döndürür
  /// ("Bad state: Too many elements") — ilk denemede tam olarak bu oldu.
  final Key? _key;

  final String text;
  final Color? color;
  final double? size;

  /// Harf aralığı — varsayılan [NoctaTrack.label].
  final double? track;
  final double height;
  final int? maxLines;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      key: _key,
      maxLines: maxLines,
      textAlign: textAlign,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: NoctaFont.mono,
        fontSize: size ?? NoctaFontSize.micro,
        letterSpacing: track ?? NoctaTrack.label,
        height: height,
        color: color ?? NoctaColors.inkFaint,
      ),
    );
  }
}

/// Serif başlık (Instrument Serif). Kolajın "el yazısı" tarafı.
class NDisplay extends StatelessWidget {
  /// [key] içteki `Text`e takılır — gerekçe [NMono]'daki notta.
  const NDisplay(
    this.text, {
    Key? key,
    this.size,
    this.color,
    this.height = 1.08,
    this.maxLines,
    this.textAlign,
  }) : _key = key,
       super(key: null);

  /// Anahtar içteki `Text`e iner — gerekçe [NMono]'daki notta.
  final Key? _key;

  final String text;
  final double? size;
  final Color? color;
  final double height;
  final int? maxLines;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      key: _key,
      maxLines: maxLines,
      textAlign: textAlign,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: NoctaFont.display,
        fontSize: size ?? NoctaFontSize.h1,
        height: height,
        fontWeight: FontWeight.w400,
        color: color ?? NoctaColors.inkPrimary,
      ),
    );
  }
}
