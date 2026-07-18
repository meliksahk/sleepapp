import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/flavor.dart';
import '../../core/design_system/design_system.dart';
import '../../l10n/app_localizations.dart';
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
    final l10n = AppL10n.of(context);
    final hasResult = result.maybeWhen(
      data: (r) => r != null,
      orElse: () => false,
    );
    return Scaffold(
      // KAYDIRILABİLİR: ana ekran her yeni özellikle uzuyor ve sabit `Column` küçük
      // ekranlarda TAŞIYOR — mikser butonu eklenince 27px taştı (widget testi yakaladı,
      // gerçek kullanıcıda kırmızı çizgili hata bandı olurdu).
      //
      // `ConstrainedBox(minHeight: viewport)` + `Center` birlikte: içerik sığdığında
      // ortalanır (bugünkü görünüm bozulmaz), sığmadığında kaydırılır. Yalnızca
      // `SingleChildScrollView` koysaydık içerik yukarı yapışırdı.
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
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
                      l10n.homeTagline,
                      style: TextStyle(
                        fontSize: NoctaFontSize.body,
                        color: NoctaColors.inkSecondary,
                      ),
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
                        return _IdentityCard(
                          slug: r.archetypeSlug,
                          name: info?.name ?? r.archetypeSlug,
                          tagline: info?.tagline,
                        );
                      },
                      orElse: () => const SizedBox.shrink(),
                    ),
                    // Kimlik geçmişi bağlantısı — YALNIZCA birden fazla sonuç varsa.
                    // Tek sonuçta "geçmiş" anlamsız olurdu (yükleme/hata → gizli).
                    ref
                        .watch(archetypeHistoryProvider)
                        .maybeWhen(
                          data: (list) => list.length < 2
                              ? const SizedBox.shrink()
                              : Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: NoctaSpace.s5,
                                  ),
                                  child: GestureDetector(
                                    key: const Key('identity-history-link'),
                                    onTap: () =>
                                        context.push('/identity/history'),
                                    child: Text(
                                      l10n.homeIdentityHistoryLink(list.length),
                                      style: TextStyle(
                                        fontSize: NoctaFontSize.caption,
                                        color: NoctaColors.accentAurora,
                                      ),
                                    ),
                                  ),
                                ),
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
                      data: (w) => w == null
                          ? const SizedBox.shrink()
                          : _WeeklyCard(release: w),
                      orElse: () => const SizedBox.shrink(),
                    ),
                    // Build flavor rozeti YALNIZCA dev/staging'de (test için). Prod
                    // kullanıcısı "flavor: PROD" gibi bir dev artığı görmemeli.
                    if (FlavorConfig.current.flavor != Flavor.prod)
                      NCard(
                        child: Text(
                          'flavor: ${FlavorConfig.current.name}',
                          style: TextStyle(color: NoctaColors.inkSecondary),
                        ),
                      ),
                    const SizedBox(height: NoctaSpace.s5),
                    NButton(
                      key: const Key('archetype-cta'),
                      label: hasResult
                          ? l10n.homeRetakeTest
                          : l10n.homeFindIdentity,
                      onPressed: () => context.push('/archetype'),
                    ),
                    const SizedBox(height: NoctaSpace.s2),
                    NButton(
                      key: const Key('sleep-mode-cta'),
                      label: l10n.homeSleepMode,
                      variant: NButtonVariant.ghost,
                      onPressed: () => context.push('/sleep-mode'),
                    ),
                    const SizedBox(height: NoctaSpace.s2),
                    NButton(
                      key: const Key('mixer-cta'),
                      label: l10n.homeOpenMixer,
                      variant: NButtonVariant.ghost,
                      onPressed: () => context.push('/mixer'),
                    ),
                    const SizedBox(height: NoctaSpace.s2),
                    NButton(
                      label: l10n.homeBrowseSoundscapes,
                      variant: NButtonVariant.ghost,
                      onPressed: () => context.push('/library'),
                    ),
                    const SizedBox(height: NoctaSpace.s2),
                    NButton(
                      label: l10n.sleepHistoryTitle,
                      variant: NButtonVariant.ghost,
                      onPressed: () => context.push('/sleep'),
                    ),
                    const SizedBox(height: NoctaSpace.s2),
                    NButton(
                      label: l10n.settingsTitle,
                      variant: NButtonVariant.ghost,
                      onPressed: () => context.push('/settings'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({
    required this.slug,
    required this.name,
    required this.tagline,
  });

  final String slug;
  final String name;
  final String? tagline;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: NoctaSpace.s5),
      child: GestureDetector(
        key: const Key('identity-card'),
        onTap: () => context.push('/identity/$slug'),
        child: NCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppL10n.of(context).homeIdentityCardLabel,
                style: TextStyle(
                  fontSize: NoctaFontSize.caption,
                  color: NoctaColors.accentAurora,
                ),
              ),
              const SizedBox(height: NoctaSpace.s1),
              Text(
                name,
                key: const Key('identity-name'),
                style: TextStyle(
                  fontSize: NoctaFontSize.h2,
                  color: NoctaColors.inkPrimary,
                ),
              ),
              if (tagline != null && tagline!.isNotEmpty) ...[
                const SizedBox(height: NoctaSpace.s1),
                Text(
                  tagline!,
                  style: TextStyle(
                    fontSize: NoctaFontSize.body,
                    color: NoctaColors.inkSecondary,
                  ),
                ),
              ],
            ],
          ),
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
                AppL10n.of(context).homeWeeklyLabel,
                style: TextStyle(
                  fontSize: NoctaFontSize.body,
                  color: NoctaColors.accentAurora,
                ),
              ),
              const SizedBox(height: NoctaSpace.s2),
              Text(
                release.notes ?? AppL10n.of(context).homeWeeklyCount(count),
                key: const Key('weekly-note'),
                style: TextStyle(
                  fontSize: NoctaFontSize.body,
                  color: NoctaColors.inkPrimary,
                ),
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
              style: TextStyle(
                fontSize: NoctaFontSize.display,
                color: NoctaColors.inkPrimary,
              ),
            ),
            Text(
              AppL10n.of(context).homeStreakLabel(current),
              style: TextStyle(
                fontSize: NoctaFontSize.body,
                color: NoctaColors.inkSecondary,
              ),
            ),
            if (showBest) ...[
              const SizedBox(height: NoctaSpace.s2),
              Text(
                AppL10n.of(context).homeStreakBest(longest),
                key: const Key('streak-best'),
                style: TextStyle(
                  fontSize: NoctaFontSize.caption,
                  color: NoctaColors.inkFaint,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
