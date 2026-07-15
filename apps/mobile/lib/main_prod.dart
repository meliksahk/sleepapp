import 'app/flavor.dart';
import 'bootstrap.dart';

void main() {
  bootstrap(
    const FlavorConfig(
      flavor: Flavor.prod,
      name: 'PROD',
      apiBaseUrl: 'https://api.nocta.app',
    ),
  );
}
