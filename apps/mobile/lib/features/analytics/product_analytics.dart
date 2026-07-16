import '../../core/api/nocta_api_client.dart';
import '../auth/auth_controller.dart';
import 'analytics.dart';

/// Ürün analitiği (docs/02 analytics-ingest). Olayları tamponlar ve batch olarak
/// `/v1/analytics/events`'e gönderir (AuthController.authorizedRequest → 401 refresh).
/// PII gönderilmez — yalnızca olay adı + zaman + props. Gönderim başarısızsa tampon
/// korunur (sonra tekrar denenir); analitik uygulamayı bloklamaz/çökertmez.
class ProductAnalytics implements Analytics {
  ProductAnalytics(this._auth, this._client, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final AuthController _auth;
  final NoctaApiClient _client;
  final DateTime Function() _now;

  static const int maxBuffer = 100;
  final List<Map<String, dynamic>> _buffer = <Map<String, dynamic>>[];

  int get pending => _buffer.length;

  /// Olayı tampona ekler. Tampon dolduysa en eskiyi düşürür (sınırlı bellek).
  @override
  void track(String name, {Map<String, dynamic>? props}) {
    _buffer.add(<String, dynamic>{
      'name': name,
      'occurredAt': _now().toUtc().toIso8601String(),
      'props': ?props,
    });
    while (_buffer.length > maxBuffer) {
      _buffer.removeAt(0);
    }
  }

  /// Tamponu batch gönderir. 202 → gönderilenler temizlenir; aksi halde tampon
  /// korunur (0 döner). Gönderilen olay sayısını döner.
  @override
  Future<int> flush() async {
    if (_buffer.isEmpty) return 0;
    final batch = List<Map<String, dynamic>>.from(_buffer);
    final res = await _auth.authorizedRequest(
      (token) => _client.postAuthed('/v1/analytics/events', token, {'events': batch}),
    );
    if (res.statusCode != 202) return 0; // tampon korunur, sonra tekrar denenir
    _buffer.removeRange(0, batch.length);
    return batch.length;
  }
}
