import 'app/flavor.dart';
import 'bootstrap.dart';

/// STAGING girişi.
///
/// **AĞ KATMANI KAPALI (`apiBaseUrl: ''`)** — `main_prod.dart`'taki gerekçenin
/// aynısı: `api-staging.nocta.app` da sahip olmadığımız `nocta.app` alanının
/// altında. Staging, prod'un provası olduğu için aynı sızıntıyı aynı şekilde
/// taşıyordu.
///
/// **AÇMAK İÇİN:** aşağıdaki `apiBaseUrl` alanına gerçekten sahip olduğumuz
/// staging adresini yaz. Tek satır.
///
/// **DEV ETKİLENMEZ:** `main_dev.dart` lokal API'ye (`localhost:3001` ya da
/// `--dart-define=API_BASE_URL=...`) bağlanmaya devam eder.
void main() {
  bootstrap(
    const FlavorConfig(
      flavor: Flavor.staging,
      name: 'STAGING',
      apiBaseUrl: '',
    ),
  );
}
