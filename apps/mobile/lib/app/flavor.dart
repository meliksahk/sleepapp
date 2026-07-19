/// Build flavor'ları (docs/04 M0). Native flavor wiring (android productFlavors /
/// ios schemes) M0'da tamamlanır; şimdilik Dart tarafı entrypoint'lerle ayrışır.
enum Flavor { dev, staging, prod }

class FlavorConfig {
  const FlavorConfig({
    required this.flavor,
    required this.name,
    required this.apiBaseUrl,
  });

  final Flavor flavor;
  final String name;

  /// API kökü. **BOŞ olabilir — bu bir hata değil, bir kapalı devre anahtarıdır.**
  ///
  /// Boşken uygulamanın ağ katmanı tamamen devre dışıdır: `NoctaApiClient` hiçbir
  /// soket açmaz, hiçbir DNS çözümlemesi yapmaz (bkz. `NoctaApiClient.isEnabled`).
  /// Uygulama gömülü içerikle çalışmaya devam eder.
  ///
  /// **NEDEN (CLAUDE.md §6) — GERÇEK BİR SIZINTI:** prod/staging girişleri
  /// `api.nocta.app` / `api-staging.nocta.app` adreslerine bakıyordu. Bu alan
  /// BİZİM DEĞİL: DNS doğrulandı, `nocta.app` A kaydı Vercel'e, `api.nocta.app`
  /// ise SAHİPSİZ bir herokudns CNAME'ine gidiyor. Yani kurulan prod APK, cihaz
  /// parmak izini ve oturum token'larını her an başkası tarafından DEVRALINABİLİR
  /// bir hosta gönderiyordu. Alan adı seçmek kullanıcının kararı; sızıntıyı
  /// durdurmak bizim işimiz.
  final String apiBaseUrl;

  /// Ağ katmanı açık mı? Adres yapılandırılmadıysa hayır.
  ///
  /// **AÇMAK İÇİN:** ilgili girişte (`lib/main_prod.dart` / `lib/main_staging.dart`)
  /// `apiBaseUrl` alanına GERÇEKTEN SAHİP OLDUĞUMUZ adresi yazmak yeterli —
  /// tek satır, başka hiçbir değişiklik gerekmez.
  bool get hasApi => apiBaseUrl.isNotEmpty;

  static FlavorConfig? _current;

  static FlavorConfig get current {
    final value = _current;
    if (value == null) {
      throw StateError('FlavorConfig kullanılmadan önce bootstrap edilmeli.');
    }
    return value;
  }

  static set current(FlavorConfig config) => _current = config;
}
