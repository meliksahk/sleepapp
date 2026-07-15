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
  final String apiBaseUrl;

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
