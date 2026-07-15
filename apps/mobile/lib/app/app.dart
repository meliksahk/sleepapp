import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/design_system/nocta_theme.dart';
import '../features/auth/auth_providers.dart';
import 'router.dart';

/// Kök uygulama widget'ı — dark-first (uygulama gece yaşar, docs/06).
/// Açılışta anonim oturumu garantiler (restore-or-register); çözülene dek
/// splash, hata durumunda yeniden dene gösterir (docs/04 M0).
class NoctaApp extends ConsumerWidget {
  const NoctaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrap = ref.watch(sessionBootstrapProvider);
    final theme = buildNoctaDarkTheme();

    return bootstrap.when(
      data: (_) => MaterialApp.router(
        title: 'NOCTA',
        debugShowCheckedModeBanner: false,
        theme: theme,
        routerConfig: appRouter,
      ),
      loading: () => _SplashApp(theme: theme),
      error: (error, stack) => _SplashApp(
        theme: theme,
        onRetry: () => ref.invalidate(sessionBootstrapProvider),
      ),
    );
  }
}

/// Metinsiz açılış ekranı (l10n M1'de gelene dek prose yok). Yükleme → spinner;
/// hata → yeniden dene ikonu.
class _SplashApp extends StatelessWidget {
  const _SplashApp({required this.theme, this.onRetry});

  final ThemeData theme;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NOCTA',
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: Scaffold(
        body: Center(
          child: onRetry == null
              ? const CircularProgressIndicator()
              : IconButton(
                  key: const Key('session-retry'),
                  icon: const Icon(Icons.refresh),
                  iconSize: 40,
                  onPressed: onRetry,
                ),
        ),
      ),
    );
  }
}
