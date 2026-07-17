import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// Bellekteki paylaşım görseli (dosyaya yazılmaz).
class ShareImage {
  const ShareImage({required this.bytes, required this.filename});

  final Uint8List bytes;
  final String filename;
}

/// Paylaşılacak içerik — başlık/metin + link, isteğe bağlı GÖRSEL.
class ShareContent {
  const ShareContent({required this.text, required this.url, this.image});

  final String text;
  final String url;

  /// Paylaşım kartı PNG'si (viral kanca #1, docs/04 §103).
  ///
  /// **Neden isteğe bağlı:** kart render edilemezse paylaşım TÜMDEN düşmemeli —
  /// link paylaşımı hâlâ değerlidir. Kartı zorunlu kılmak, tek bir render hatasında
  /// viral yolu tamamen kapatırdı.
  final ShareImage? image;

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
    final image = content.image;
    await SharePlus.instance.share(
      image == null
          ? ShareParams(text: content.body)
          : ShareParams(
              text: content.body,
              files: [
                XFile.fromData(
                  image.bytes,
                  mimeType: 'image/png',
                  name: image.filename,
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
