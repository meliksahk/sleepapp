import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// Paylaşım dosyası: ya bellekte baytlar ya diskte bir yol — **tam olarak biri**.
///
/// **`mimeType` TAŞINIR:** başta bu sınıf `ShareImage`'dı ve adaptör MIME tipini
/// `image/png` diye SABİT yazıyordu. Kimlik kartı için doğruydu; gece zarfı CSV'si
/// eklenince yanlış oldu — bir CSV'yi `image/png` diye paylaşmak, alıcı uygulamada
/// bozuk görsel olarak açılırdı. Tip, veriyle birlikte gelmeli.
///
/// **Neden hem bayt hem yol:** kartlar bellekte üretilir (diske yazmaya gerek yok),
/// mix-to-video ise native kodlayıcıdan **dosya olarak** çıkar (~15 MB). O dosyayı
/// yalnızca OS'a geri vermek için RAM'e okumak boşuna kopya olurdu.
class ShareFile {
  const ShareFile._({
    this.bytes,
    this.path,
    required this.filename,
    required this.mimeType,
  }) : assert((bytes == null) != (path == null), 'ya bayt ya yol, tam olarak biri');

  /// Bellekteki içerik ([path] null ise dolu.)
  final Uint8List? bytes;

  /// Diskteki dosya yolu ([bytes] null ise dolu.)
  final String? path;

  final String filename;
  final String mimeType;

  /// PNG kısayolu (viral kanca kartları).
  factory ShareFile.png({required Uint8List bytes, required String filename}) =>
      ShareFile._(bytes: bytes, filename: filename, mimeType: 'image/png');

  /// CSV kısayolu (gece zarfı fixture'ı, docs/04 §120).
  factory ShareFile.csv({required String text, required String filename}) =>
      ShareFile._(
        bytes: Uint8List.fromList(utf8.encode(text)),
        filename: filename,
        mimeType: 'text/csv',
      );

  /// mp4 kısayolu (mix-to-video, viral kanca #3) — dosya diskten paylaşılır.
  factory ShareFile.mp4({required String path, required String filename}) =>
      ShareFile._(path: path, filename: filename, mimeType: 'video/mp4');
}

/// Paylaşılacak içerik — başlık/metin + link, isteğe bağlı GÖRSEL.
class ShareContent {
  const ShareContent({required this.text, required this.url, this.file});

  final String text;
  final String url;

  /// Eklenen dosya: paylaşım kartı PNG'si (viral kanca #1) veya gece zarfı CSV'si.
  ///
  /// **Neden isteğe bağlı:** kart render edilemezse paylaşım TÜMDEN düşmemeli —
  /// link paylaşımı hâlâ değerlidir. Kartı zorunlu kılmak, tek bir render hatasında
  /// viral yolu tamamen kapatırdı.
  final ShareFile? file;

  /// Tek satır paylaşım gövdesi.
  String get body => '$text\n$url';
}

/// Paylaşım soyutlaması. Soyutlama sayesinde UI test edilebilir.
abstract class Sharer {
  Future<void> share(ShareContent content);
}

/// Native OS paylaşım sayfası (share_plus) — **üretim adaptörü**.
///
/// Port'un kendi yorumu bunu zaten öngörüyordu: *"native paylaşım sayfası ileride
/// bu port'un arkasına takılır"*. Takıldı.
///
/// **Neden `ClipboardSharer` yetmiyordu:** panoya link kopyalamak "paylaştım" değil,
/// "kullanıcıya iş çıkardım" demektir — Instagram'ı kendisi açıp yapıştırması gerekir
/// ve GÖRSEL hiç gitmez. Viral kanca sürtünmesizliğe dayanır (docs/04 §103); kartın
/// tüm anlamı, paylaşılan şeyin bir link değil bir GÖRSEL olması.
class PlatformSharer implements Sharer {
  @override
  Future<void> share(ShareContent content) async {
    final file = content.file;
    if (file == null) {
      await SharePlus.instance.share(ShareParams(text: content.body));
      return;
    }

    final bytes = file.bytes;
    await SharePlus.instance.share(
      ShareParams(
        text: content.body,
        files: [
          // Tip her iki yolda da veriyle GELİR, sabit değil (bkz. ShareFile yorumu).
          if (bytes != null)
            XFile.fromData(bytes, mimeType: file.mimeType, name: file.filename)
          else
            XFile(file.path!, mimeType: file.mimeType, name: file.filename),
        ],
      ),
    );
  }
}

/// Panoya kopyalayan adaptör — paylaşım sayfası olmayan yüzeylerde/testlerde.
///
/// **Görsel taşıyamaz** (pano metin içindir); bu yüzden üretimde [PlatformSharer].
class ClipboardSharer implements Sharer {
  @override
  Future<void> share(ShareContent content) {
    return Clipboard.setData(ClipboardData(text: content.body));
  }
}
