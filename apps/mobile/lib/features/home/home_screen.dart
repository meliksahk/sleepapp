import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/flavor.dart';
import '../../core/design_system/design_system.dart';
import '../archetype/archetype_providers.dart';
import '../content/content_models.dart';
import '../content/content_providers.dart';
import '../sleep/sleep_providers.dart';

/// Geçici iskelet ekranı (Faz M0). M1'de onboarding + archetype testi gelir.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(streakProvider);
    final weekly = ref.watch(weeklyReleaseProvider);
    final result = ref.watch(latestArchetypeResultProvider);
    final content = ref.watch(archetypeContentProvider);
    // Kullanıcının test sonucu var mı → buton "Retake" olur, kimlik kartı görünür.
    final hasResult = result.maybeWhen(data: (r) => r != null, orElse: () => false);
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
              // Kullanıcının uyku kimliği — sonuç varsa (yükleme/hata/yok → gizli).
              result.maybeWhen(
                data: (r) {
                  if (r == null) return const SizedBox.shrink();
                  final info = content.maybeWhen(
                    data: (m) => m[r.archetypeSlug],
                    orElse: () => null,
                  );
                  return _IdentityCard(name: info?.name ?? r.archetypeSlug, tagline: info?.tagline);
                },
                orElse: () => const SizedBox.shrink(),
              ),
              // Streak: yalnızca en az bir gece kaydı varken görünür (yeni kullanıcıda
              // "0 nights streak" göstermek yerine gizli). Yükleme/hata → gizli, home bloklanmaz.
              streak.maybeWhen(
                data: (s) => s.totalNights == 0
                    ? const SizedBox.shrink()
                    : _StreakCard(current: s.current, longest: s.longest),
                orElse: () => const SizedBox.shrink(),
              ),
              // Haftalık yayın kartı — yalnızca yayın varken (yükleme/hata/null → gizli).
              weekly.maybeWhen(
                data: (w) => w == null ? const SizedBox.shrink() : _WeeklyCard(release: w),
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
                key: const Key('archetype-cta'),
                label: hasResult ? 'Retake the test' : 'Find your sleep identity',
                onPressed: () => context.push('/archetype'),
              ),
              const SizedBox(height: NoctaSpace.s2),
              NButton(
                label: 'Browse soundscapes',
                variant: NButtonVariant.ghost,
                onPressed: () => context.push('/library'),
              ),
              const SizedBox(height: NoctaSpace.s2),
              NButton(
                label: 'Sleep history',
                variant: NButtonVariant.ghost,
                onPressed: () => context.push('/sleep'),
              ),
              const SizedBox(height: NoctaSpace.s2),
              NButton(
                label: 'Settings',
                variant: NButtonVariant.ghost,
                onPressed: () => context.push('/settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.name, required this.tagline});

  final String name;
  final String? tagline;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: NoctaSpace.s5),
      child: NCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your sleep identity',
              style: TextStyle(fontSize: NoctaFontSize.caption, color: NoctaColors.accentAurora),
            ),
            const SizedBox(height: NoctaSpace.s1),
            Text(
              name,
              key: const Key('identity-name'),
              style: TextStyle(fontSize: NoctaFontSize.h2, color: NoctaColors.inkPrimary),
            ),
            if (tagline != null && tagline!.isNotEmpty) ...[
              const SizedBox(height: NoctaSpace.s1),
              Text(
                tagline!,
                style: TextStyle(fontSize: NoctaFontSize.body, color: NoctaColors.inkSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WeeklyCard extends StatelessWidget {
  const _WeeklyCard({required this.release});

  final WeeklyRelease release;

  @override
  Widget build(BuildContext context) {
    final count = release.soundscapes.length;
    return Padding(
      padding: const EdgeInsets.only(bottom: NoctaSpace.s5),
      child: GestureDetector(
        key: const Key('weekly-card'),
        onTap: () => context.push('/library'),
        child: NCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This week',
                style: TextStyle(fontSize: NoctaFontSize.body, color: NoctaColors.accentAurora),
              ),
              const SizedBox(height: NoctaSpace.s2),
              Text(
                release.notes ?? '$count soundscape${count == 1 ? '' : 's'} this week',
                key: const Key('weekly-note'),
                style: TextStyle(fontSize: NoctaFontSize.body, color: NoctaColors.inkPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.current, required this.longest});

  final int current;
  final int longest;

  @override
  Widget build(BuildContext context) {
    // Kişisel rekor yalnızca güncel seriden büyükse anlamlı (aksi halde tekrar bilgi).
    final showBest = longest > current;
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
            if (showBest) ...[
              const SizedBox(height: NoctaSpace.s2),
              Text(
                'Best $longest',
                key: const Key('streak-best'),
                style: TextStyle(fontSize: NoctaFontSize.caption, color: NoctaColors.inkFaint),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
