import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/flavor.dart';
import '../../core/design_system/design_system.dart';
import '../sleep/sleep_providers.dart';

/// Geçici iskelet ekranı (Faz M0). M1'de onboarding + archetype testi gelir.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(streakProvider);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(NoctaSpace.s5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'NOCTA',
                style: TextStyle(
                  fontSize: NoctaFontSize.display,
                  color: NoctaColors.inkPrimary,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: NoctaSpace.s3),
              Text(
                'Your night has an identity',
                style: TextStyle(fontSize: NoctaFontSize.body, color: NoctaColors.inkSecondary),
              ),
              const SizedBox(height: NoctaSpace.s6),
              // Streak yalnızca veri gelince görünür (yükleme/hata → gizli, home bloklanmaz).
              streak.maybeWhen(
                data: (s) => _StreakCard(current: s.current),
                orElse: () => const SizedBox.shrink(),
              ),
              NCard(
                child: Text(
                  'flavor: ${FlavorConfig.current.name}',
                  style: TextStyle(color: NoctaColors.inkSecondary),
                ),
              ),
              const SizedBox(height: NoctaSpace.s5),
              NButton(
                label: 'Find your sleep identity',
                onPressed: () => context.push('/archetype'),
              ),
              const SizedBox(height: NoctaSpace.s2),
              NButton(
                label: 'Browse soundscapes',
                variant: NButtonVariant.ghost,
                onPressed: () => context.push('/library'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.current});

  final int current;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: NoctaSpace.s5),
      child: NCard(
        child: Column(
          children: [
            Text(
              '$current',
              key: const Key('streak-current'),
              style: TextStyle(fontSize: NoctaFontSize.display, color: NoctaColors.inkPrimary),
            ),
            Text(
              current == 1 ? 'night streak' : 'nights streak',
              style: TextStyle(fontSize: NoctaFontSize.body, color: NoctaColors.inkSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
