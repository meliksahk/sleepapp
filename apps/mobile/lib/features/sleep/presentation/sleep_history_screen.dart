import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/network_error_view.dart';
import '../../../core/design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';
import '../../entitlement/entitlement_providers.dart';
import '../sleep_models.dart';
import '../sleep_providers.dart';
import 'weekly_trend_chart.dart';

/// Uyku geçmişi (docs/04 M1): en yeni oturumları gece + süre ile listeler.
/// Boş/yükleme/hata durumları.
class SleepHistoryScreen extends ConsumerWidget {
  const SleepHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(recentSleepSessionsProvider);
    final stats = ref.watch(sleepStatsProvider);
    final trend = ref.watch(sleepTrendProvider);
    return Scaffold(
      appBar: AppBar(title: NMono(AppL10n.of(context).sleepHistoryTitle)),
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
                      child: NMono(
                        AppL10n.of(context).sleepHistoryStats(
                          s.nights,
                          formatMinutes(s.averageDurationMinutes),
                        ),
                        key: const Key('sleep-stats'),
                        track: NoctaTrack.wide,
                      ),
                    ),
              orElse: () => const SizedBox.shrink(),
            ),
            // Son 7 gece mini grafiği — veri olan gece varsa (yükleme/hata/boş → gizli).
            // **PREMIUM KAPISI:** haftalık trend premium bir içgörüdür. Free kullanıcı
            // kilit + paywall CTA görür; premium grafiği görür. Viral kancalara (kimlik/
            // gece raporu/mix-to-video) DOKUNMAZ — cömert free tier (§1.1).
            // **fail-open:** entitlement bilinmezse (ağ gecikmesi/hata) grafik gösterilir —
            // premium bir kullanıcıyı yanlışlıkla kilitlemek, tersinden daha kötü.
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
                      child:
                          (ref
                                  .watch(entitlementProvider)
                                  .valueOrNull
                                  ?.premium ??
                              true)
                          ? WeeklyTrendChart(trend: t)
                          : const _TrendPremiumLock(),
                    ),
              orElse: () => const SizedBox.shrink(),
            ),
            Expanded(child: _body(context, ref, sessions)),
          ],
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<SleepSession>> sessions,
  ) {
    return sessions.when(
      data: (list) => _list(context, list),
      loading: () => const Center(child: CircularProgressIndicator()),
      // Ciplak refresh ikonu DEGIL: ne oldu / ne yapabilirim (NErrorState).
      error: (error, stack) => NetworkErrorView(
        retryKey: const Key('sleep-history-retry'),
        onRetry: () => ref.invalidate(recentSleepSessionsProvider),
      ),
    );
  }

  Widget _list(BuildContext context, List<SleepSession> list) {
    if (list.isEmpty) {
      return Center(
        child: NEmptyState(
          key: const Key('sleep-history-empty'),
          title: AppL10n.of(context).sleepHistoryEmpty,
          actionLabel: AppL10n.of(context).homeStartRitual,
          onAction: () => context.push('/sleep-mode'),
        ),
      );
    }
    // En uzun gece olcek referansi: cubuklar birbirine gore okunur.
    final int longest = list.fold<int>(
      1,
      (m, e) => e.durationMinutes > m ? e.durationMinutes : m,
    );
    return ListView.separated(
      padding: const EdgeInsets.all(NoctaSpace.s6),
      itemCount: list.length,
      separatorBuilder: (context, index) =>
          const Divider(color: NoctaColors.lineHairline),
      itemBuilder: (context, i) {
        final s = list[i];
        // Tıklama → o gecenin raporu (viral kanca #2).
        return GestureDetector(
          key: Key('sleep-session-${s.id}'),
          onTap: () => context.push('/report/${s.nightDate}'),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: NoctaSpace.s3),
            child: Row(
              children: [
                SizedBox(
                  width: 58,
                  child: NMono(s.nightDate, track: 0, maxLines: 1),
                ),
                const SizedBox(width: NoctaSpace.s3),
                // Gecenin uzunlugu CUBUKLA da anlatilir: liste tek bakista okunur.
                Expanded(
                  child: Container(
                    height: 22,
                    color: NoctaColors.bgOverlay,
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: (s.durationMinutes / longest).clamp(
                        0.02,
                        1.0,
                      ),
                      child: Container(color: NoctaColors.inkFaint),
                    ),
                  ),
                ),
                const SizedBox(width: NoctaSpace.s3),
                SizedBox(
                  width: 56,
                  child: NMono(
                    s.durationText,
                    color: NoctaColors.inkSecondary,
                    track: 0,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Haftalık trend yerine free kullanıcıya gösterilen premium kilidi. Gerçek bir
/// kullanıcı aksiyonu (butona basma) paywall'ı açar — ölü kod değil (sabıka #6).
class _TrendPremiumLock extends StatelessWidget {
  const _TrendPremiumLock();

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border.fromBorderSide(BorderSide(color: NoctaColors.lineSoft)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(NoctaSpace.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 18,
                  color: NoctaColors.inkSecondary,
                ),
                const SizedBox(width: NoctaSpace.s2),
                Expanded(
                  child: Text(
                    l10n.trendLockText,
                    key: const Key('trend-premium-lock'),
                    style: TextStyle(
                      fontSize: NoctaFontSize.body,
                      color: NoctaColors.inkSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: NoctaSpace.s3),
            NButton(
              key: const Key('trend-unlock-cta'),
              label: l10n.trendLockCta,
              variant: NButtonVariant.ghost,
              onPressed: () => context.push('/paywall'),
            ),
          ],
        ),
      ),
    );
  }
}
