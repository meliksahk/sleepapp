import 'app/flavor.dart';
import 'bootstrap.dart';

void main() {
  bootstrap(
    const FlavorConfig(
      flavor: Flavor.staging,
      name: 'STAGING',
      apiBaseUrl: 'https://api-staging.nocta.app',
    ),
  );
}
