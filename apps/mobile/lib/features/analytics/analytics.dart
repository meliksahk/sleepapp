/// Ürün analitiği arayüzü — UI bu soyutlamaya bağlanır (test'te spy ile override).
/// Üretimde ProductAnalytics (tamponlu batch ingest) uygular.
abstract class Analytics {
  /// Olayı tampona ekler (PII gönderilmez — yalnızca olay adı + props).
  void track(String name, {Map<String, dynamic>? props});

  /// Tamponu gönderir; gönderilen olay sayısını döner.
  Future<int> flush();
}
