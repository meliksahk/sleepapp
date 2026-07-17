import 'app/flavor.dart';
import 'bootstrap.dart';

/// API adresi derleme zamanında verilebilir:
/// `flutter run --dart-define=API_BASE_URL=http://192.168.1.42:3099`
///
/// **NEDEN GEREKLİ:** `localhost` telefonun KENDİSİDİR. Emülatörde `adb reverse`
/// ile idare ediliyordu ama **gerçek bir telefon komodinde** geliştirme
/// makinesindeki API'ye ulaşamaz — gerçek gece testi için makinenin LAN IP'si
/// gerekiyor. Sabit kodlanmış adres, testi imkânsız kılıyordu.
///
/// Varsayılan `localhost`: emülatör akışı (adb reverse) bozulmasın.
const _apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:3001',
);

void main() {
  bootstrap(
    const FlavorConfig(flavor: Flavor.dev, name: 'DEV', apiBaseUrl: _apiBaseUrl),
  );
}
