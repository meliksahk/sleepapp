import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';
import 'app/flavor.dart';

/// Ortak açılış — flavor'ı bağlar ve ProviderScope ile uygulamayı başlatır.
/// (Sentry init M0'da buraya eklenecek.)
void bootstrap(FlavorConfig config) {
  WidgetsFlutterBinding.ensureInitialized();
  FlavorConfig.current = config;
  runApp(const ProviderScope(child: NoctaApp()));
}
