import 'app/flavor.dart';
import 'bootstrap.dart';

void main() {
  bootstrap(
    const FlavorConfig(
      flavor: Flavor.dev,
      name: 'DEV',
      apiBaseUrl: 'http://localhost:3001',
    ),
  );
}
