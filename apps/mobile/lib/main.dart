// Varsayılan giriş noktası → dev flavor (kolay `flutter run`).
// Belirli flavor için: flutter run -t lib/main_staging.dart
import 'main_dev.dart' as dev;

void main() => dev.main();
