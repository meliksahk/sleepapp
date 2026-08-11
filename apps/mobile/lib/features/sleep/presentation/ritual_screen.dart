import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/network_error_view.dart';
import '../../../core/design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';
import '../sleep_models.dart';
import '../sleep_providers.dart';

/// **Ritüelim / seri** (Elegy §18).
///
/// **Neden ayrı ekran:** seri, ana ekranda tek satırlık bir şeritti — bir sayı,
/// bağlamsız. Alışkanlık döngüsünün çalışması için kullanıcının GEÇMİŞİNİ
/// görmesi gerekiyor: kaç gece üst üste, en uzunu neydi, bu ay hangi geceler
/// dolu. Ay ızgarası boşlukları da gösterir — kaçırılan gece de bilgidir.
///
/// **Sahte veri YOK:** ızgara yalnızca sunucudan gelen gecelerle dolar. Veri
/// gelmediyse ızgara boş kalır; "muhtemelen uyudun" diye kutu boyamayız.
class RitualScreen extends ConsumerWidget {
  const RitualScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final streak = ref.watch(streakProvider);
    final stats = ref.watch(sleepStatsProvider);
    final sessions = ref.watch(recentSleepSessionsProvider);

    return Scaffold(
      appBar: AppBar(title: NMono(l10n.ritualTitle)),
      body: SafeArea(
        child: streak.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => NetworkErrorView(
            retryKey: const Key('ritual-retry'),
            onRetry: () => ref.invalidate(streakProvider),
          ),
          data: (s) => s.totalNights == 0
              ? Center(
                  child: NEmptyState(
                    key: const Key('ritual-empty'),
                    title: l10n.ritualEmpty,
                    actionLabel: l10n.homeStartRitual,
                    onAction: () => context.push('/sleep-mode'),
                  ),
                )
              : _Body(
                  streak: s,
                  nights: sessions.maybeWhen(
                    data: (list) => list,
                    orElse: () => const <SleepSession>[],
                  ),
                  averageMinutes: stats.maybeWhen(
                    data: (v) => v.averageDurationMinutes,
                    orElse: () => null,
                  ),
                ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.streak,
    required this.nights,
    required this.averageMinutes,
  });

  final StreakStats streak;
  final List<SleepSession> nights;

  /// Null → istatistik henüz gelmedi; kutu ÇİZİLMEZ (sahte 0 göstermeyiz).
  final int? averageMinutes;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final int? avg = averageMinutes;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(NoctaSpace.s6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          NDisplay(
            '${streak.current}',
            key: const Key('ritual-current'),
            size: 88,
            height: 1,
          ),
          const SizedBox(height: NoctaSpace.s2),
          NMono(l10n.ritualNightsInRow, track: NoctaTrack.wide),
          const SizedBox(height: NoctaSpace.s8),
          NMono(l10n.ritualMonthLabel, track: NoctaTrack.wide),
          const SizedBox(height: NoctaSpace.s3),
          _MonthGrid(nights: nights),
          const SizedBox(height: NoctaSpace.s8),
          const Divider(color: NoctaColors.lineHairline),
          const SizedBox(height: NoctaSpace.s5),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _Stat(value: '${streak.longest}', label: l10n.ritualLongest),
              const SizedBox(width: NoctaSpace.s8),
              _Stat(
                value: '${streak.totalNights}',
                label: l10n.ritualTotalNights,
              ),
              if (avg != null) ...<Widget>[
                const SizedBox(width: NoctaSpace.s8),
                _Stat(
                  value: formatMinutes(avg),
                  label: l10n.ritualAverage,
                  valueKey: const Key('ritual-average'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Ayın günleri — dolu geceler yırtık krem kare, boşlar sönük çerçeve.
///
/// **Ay, TAKVİM ayı:** "son 30 gün" kayan bir pencere olurdu ve kullanıcı
/// kendini geçen haftayla karşılaştıramazdı. Alışkanlık takvimle yaşanır.
class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.nights});

  final List<SleepSession> nights;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final int days = DateTime(now.year, now.month + 1, 0).day;
    final String prefix =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-';
    final Set<String> filled = nights
        .map((n) => n.nightDate)
        .where((d) => d.startsWith(prefix))
        .toSet();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: <Widget>[
        for (var day = 1; day <= days; day++)
          _DayCell(
            filled: filled.contains('$prefix${day.toString().padLeft(2, '0')}'),
            seed: day,
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.filled, required this.seed});

  final bool filled;
  final int seed;

  @override
  Widget build(BuildContext context) {
    final Widget box = Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: filled ? NoctaColors.bgPaper : Colors.transparent,
        border: filled ? null : Border.all(color: NoctaColors.lineSoft),
      ),
    );
    // Dolu geceler YIRTIK, boşlar düz: ayrım yalnız renkte değil şekilde de.
    return filled
        ? ClipPath(
            clipper: NTornClipper(seed: seed, teeth: 3, depth: 0.14),
            child: box,
          )
        : box;
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.valueKey});

  final String value;
  final String label;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        NDisplay(value, key: valueKey, size: NoctaFontSize.h2),
        const SizedBox(height: NoctaSpace.s2),
        NMono(label, track: NoctaTrack.tight),
      ],
    );
  }
}
