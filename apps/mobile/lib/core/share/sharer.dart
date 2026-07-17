import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// Bellekteki paylaşım dosyası (diske yazılmaz).
///
/// **`mimeType` TAŞINIR:** başta bu sınıf `ShareImage`'dı ve adaptör MIME tipini
/// `image/png` diye SABİT yazıyordu. Kimlik kartı için doğruydu; gece zarfı CSV'si
/// eklenince yanlış oldu — bir CSV'yi `image/png` diye paylaşmak, alıcı uygulamada
/// bozuk görsel olarak açılırdı. Tip, veriyle birlikte gelmeli.
class ShareFile {
  const ShareFile({
    required this.bytes,
    required this.filename,
    required this.mimeType,
  });

  final Uint8List bytes;
  final String filename;
  final String mimeType;

  /// PNG kısayolu (viral kanca kartları).
  factory ShareFile.png({required Uint8List bytes, required String filename}) =>
      ShareFile(bytes: bytes, filename: filename, mimeType: 'image/png');

  /// CSV kısayolu (gece zarfı fixture'ı, docs/04 §120).
  factory ShareFile.csv({required String text, required String filename}) =>
      ShareFile(
        bytes: Uint8List.fromList(utf8.encode(text)),
        filename: filename,
        mimeType: 'text/csv',
      );
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
    await SharePlus.instance.share(
      file == null
          ? ShareParams(text: content.body)
          : ShareParams(
              text: content.body,
              files: [
                XFile.fromData(
                  file.bytes,
                  // Tip veriyle GELİR, sabit değil (bkz. ShareFile yorumu).
                  mimeType: file.mimeType,
                  name: file.filename,
                ),
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
