import 'package:flutter/services.dart';

/// Paylaşılacak içerik — başlık/metin + link.
class ShareContent {
  const ShareContent({required this.text, required this.url});

  final String text;
  final String url;

  /// Tek satır paylaşım gövdesi.
  String get body => '$text\n$url';
}

/// Paylaşım soyutlaması. Soyutlama sayesinde UI test edilebilir; native OS
/// paylaşım sayfası (share_plus) ileride bu port'un arkasına takılır (docs/04).
abstract class Sharer {
  Future<void> share(ShareContent content);
}

/// Interim üretim adaptörü — link'i panoya kopyalar (bağımlılıksız). Native
/// paylaşım sayfası (share_plus) ertelendi; bu port sayesinde tak-çıkar.
class ClipboardSharer implements Sharer {
  @override
  Future<void> share(ShareContent content) {
    return Clipboard.setData(ClipboardData(text: content.body));
  }
}
