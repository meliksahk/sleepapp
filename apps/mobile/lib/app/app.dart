import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/design_system/nocta_theme.dart';
import '../features/analytics/analytics_flusher.dart';
import '../features/analytics/analytics_providers.dart';
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
      data: (_) => _AppRoot(theme: theme),
      loading: () => _SplashApp(theme: theme),
      error: (error, stack) => _SplashApp(
        theme: theme,
        onRetry: () => ref.invalidate(sessionBootstrapProvider),
      ),
    );
  }
}

/// Oturum kurulduktan sonraki kök — router + analitik lifecycle flush observer'ı.
class _AppRoot extends ConsumerStatefulWidget {
  const _AppRoot({required this.theme});

  final ThemeData theme;

  @override
  ConsumerState<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends ConsumerState<_AppRoot> {
  late final AnalyticsFlusher _flusher;

  @override
  void initState() {
    super.initState();
    _flusher = AnalyticsFlusher(ref.read(analyticsProvider));
    WidgetsBinding.instance.addObserver(_flusher);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_flusher);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'NOCTA',
      debugShowCheckedModeBanner: false,
      theme: widget.theme,
      routerConfig: appRouter,
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
