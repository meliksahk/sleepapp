import 'package:go_router/go_router.dart';
import '../features/home/home_screen.dart';

/// Uygulama route'ları — tek dosyada tip güvenli (docs/04). M1'de büyür.
final GoRouter appRouter = GoRouter(
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
  ],
);
