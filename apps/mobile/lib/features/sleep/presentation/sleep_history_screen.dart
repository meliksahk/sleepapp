import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/design_system/design_system.dart';
import '../sleep_models.dart';
import '../sleep_providers.dart';
import 'weekly_trend_chart.dart';

/// Uyku geçmişi (docs/04 M1): en yeni oturumları gece + süre ile listeler.
/// Boş/yükleme/hata durumları. Not: metinler l10n'a M1'de taşınacak.
class SleepHistoryScreen extends ConsumerWidget {
  const SleepHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(recentSleepSessionsProvider);
    final stats = ref.watch(sleepStatsProvider);
    final trend = ref.watch(sleepTrendProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Sleep history')),
      body: SafeArea(
        child: Column(
          children: [
            // İstatistik başlığı — veri gelince (yükleme/hata → gizli).
            stats.maybeWhen(
              data: (s) => s.nights == 0
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(
                        NoctaSpace.s5,
                        NoctaSpace.s5,
                        NoctaSpace.s5,
                        0,
                      ),
                      child: Text(
                        '${s.nights} nights · avg ${formatMinutes(s.averageDurationMinutes)}',
                        key: const Key('sleep-stats'),
                        style: TextStyle(
                          fontSize: NoctaFontSize.body,
                          color: NoctaColors.inkSecondary,
                        ),
                      ),
                    ),
              orElse: () => const SizedBox.shrink(),
            ),
            // Son 7 gece mini grafiği — veri olan gece varsa (yükleme/hata/boş → gizli).
            trend.maybeWhen(
              data: (t) => t.nightsWithData == 0
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(
                        NoctaSpace.s5,
                        NoctaSpace.s4,
                        NoctaSpace.s5,
                        0,
                      ),
                      child: WeeklyTrendChart(trend: t),
                    ),
              orElse: () => const SizedBox.shrink(),
            ),
            Expanded(child: _body(ref, sessions)),
          ],
        ),
      ),
    );
  }

  Widget _body(WidgetRef ref, AsyncValue<List<SleepSession>> sessions) {
    return sessions.when(
      data: (list) => _list(list),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: IconButton(
          key: const Key('sleep-history-retry'),
          icon: const Icon(Icons.refresh),
          iconSize: 40,
          onPressed: () => ref.invalidate(recentSleepSessionsProvider),
        ),
      ),
    );
  }

  Widget _list(List<SleepSession> list) {
    if (list.isEmpty) {
      return Center(
        child: Text(
          'No sleep recorded yet',
          key: const Key('sleep-history-empty'),
          style: TextStyle(fontSize: NoctaFontSize.body, color: NoctaColors.inkSecondary),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(NoctaSpace.s5),
      itemCount: list.length,
      separatorBuilder: (context, index) => const SizedBox(height: NoctaSpace.s3),
      itemBuilder: (context, i) {
        final s = list[i];
        // Tıklama → o gecenin raporu (viral kanca #2).
        return GestureDetector(
          key: Key('sleep-session-${s.id}'),
          onTap: () => context.push('/report/${s.nightDate}'),
          child: NCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  s.nightDate,
                  style: TextStyle(fontSize: NoctaFontSize.body, color: NoctaColors.inkSecondary),
                ),
                Text(
                  s.durationText,
                  style: TextStyle(fontSize: NoctaFontSize.body, color: NoctaColors.inkPrimary),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
