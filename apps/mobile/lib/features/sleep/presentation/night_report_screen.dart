import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/media/card_renderer.dart';
import '../../../core/share/sharer.dart';
import 'night_report_card.dart';
import '../../analytics/analytics_providers.dart';
import '../../archetype/archetype_providers.dart'
    show
        archetypeContentProvider,
        latestArchetypeResultProvider,
        sharerProvider;
import '../sleep_models.dart';
import '../sleep_providers.dart';

/// Gece Raporu (docs/04, viral kanca #2) — bir gecenin özeti + paylaşım.
/// Paylaşım metni sunucudan gelir (GET /v1/sharing/report) → kart metni tek kaynak.
class NightReportScreen extends ConsumerStatefulWidget {
  const NightReportScreen({super.key, required this.nightDate});

  final String nightDate;

  @override
  ConsumerState<NightReportScreen> createState() => _NightReportScreenState();
}

class _NightReportScreenState extends ConsumerState<NightReportScreen> {
  bool _sharing = false;

  /// Raporu provider'dan OKUR: `_share` build'in yerel `r`'sini göremez ve o veriyi
  /// widget'a parametre olarak taşımak, kartı ekranın çizim döngüsüne bağlardı.
  NightReport? get _report0 => ref
      .read(nightReportProvider(widget.nightDate))
      .maybeWhen(data: (r) => r, orElse: () => null);

  /// Seri — kartta gösterilir; gelmezse 0 (kart yine çizilir).
  int get _streak => ref
      .read(streakProvider)
      .maybeWhen(data: (s) => s.current, orElse: () => 0);

  /// Uyku kimliği — gelmezse kartta o satır hiç çizilmez.
  String? get _archetypeName {
    final slug = ref
        .read(latestArchetypeResultProvider)
        .maybeWhen(data: (r) => r?.archetypeSlug, orElse: () => null);
    if (slug == null) return null;
    return ref
        .read(archetypeContentProvider)
        .maybeWhen(data: (m) => m[slug]?.name ?? slug, orElse: () => slug);
  }

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    final messenger = ScaffoldMessenger.of(context);
    // l10n await'ten ÖNCE yakalanır (context async gap'te kullanılmaz — analyzer kuralı).
    final l10n = AppL10n.of(context);
    try {
      final share = await ref
          .read(sleepControllerProvider)
          .reportShare(widget.nightDate);
      if (share == null) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.nightReportNoShareCard)),
        );
        return;
      }
      // Viral kanca #2: link DEĞİL, GÖRSEL paylaşılır (docs/04 §119).
      // Kart render edilemezse paylaşım TÜMDEN düşmez — link'le devam eder.
      ShareFile? card;
      final r = _report0;
      try {
        if (r == null) throw StateError('rapor yok');
        final rendered = await renderWidgetToPng(
          NightReportCard(
            nightDate: widget.nightDate,
            durationMinutes: r.totalDurationMinutes,
            soundEvents: r.soundEvents,
            calmScore: r.calmScore,
            streak: _streak,
            archetypeName: _archetypeName,
            gradient: NoctaArchetypeGradient.overthinker,
            labels: NightReportCardLabels(
              header: l10n.reportCardHeader,
              duration: l10n.reportCardDuration(
                r.totalDurationMinutes ~/ 60,
                r.totalDurationMinutes % 60,
              ),
              calmLabel: l10n.reportCardCalm,
              loudLabel: l10n.reportCardLoud,
              streakLabel: l10n.reportCardStreak,
              identityLabel: l10n.reportCardIdentity,
              disclaimer: l10n.reportCardDisclaimer,
            ),
          ),
        );
        debugPrint(
          'Gece raporu kartı render: ${rendered.elapsed.inMilliseconds}ms '
          '(bütçe ${shareCardRenderBudget.inMilliseconds}ms) '
          '${rendered.withinBudget ? "İÇİNDE" : "AŞILDI"}',
        );
        card = ShareFile.png(
          bytes: rendered.pngBytes,
          filename: 'nocta-night-${widget.nightDate}.png',
        );
      } catch (e) {
        // Sessiz yutma DEĞİL: kart gitmedi ama kullanıcı yine paylaşabilsin.
        debugPrint('Gece raporu kartı render edilemedi, link ile: $e');
      }

      await ref
          .read(sharerProvider)
          .share(ShareContent(text: share.title, url: share.webUrl, file: card));
      // Viral huni ölçümü (analitik bloklamaz). props YOK: gece tarihi PII'ye yakın
      // ve huni için gereksiz (docs/analytics-events.md).
      ref.read(analyticsProvider).track('report_shared');
      messenger.showSnackBar(SnackBar(content: Text(l10n.shareLinkCopied)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.shareFailed)));
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = ref.watch(nightReportProvider(widget.nightDate));
    return Scaffold(
      appBar: AppBar(title: Text(AppL10n.of(context).nightReportTitle)),
      body: SafeArea(
        child: report.when(
          data: (r) => r == null ? _empty(context) : _report(context, r),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: IconButton(
              key: const Key('report-retry'),
              icon: const Icon(Icons.refresh),
              iconSize: 40,
              onPressed: () =>
                  ref.invalidate(nightReportProvider(widget.nightDate)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _empty(BuildContext context) => Center(
    child: Text(
      AppL10n.of(context).nightReportEmpty,
      key: const Key('report-empty'),
      style: TextStyle(
        fontSize: NoctaFontSize.body,
        color: NoctaColors.inkSecondary,
      ),
    ),
  );

  Widget _report(BuildContext context, NightReport r) {
    final l10n = AppL10n.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(NoctaSpace.s5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            r.nightDate,
            style: TextStyle(
              fontSize: NoctaFontSize.body,
              color: NoctaColors.inkSecondary,
            ),
          ),
          const SizedBox(height: NoctaSpace.s2),
          Text(
            formatMinutes(r.totalDurationMinutes),
            key: const Key('report-duration'),
            style: TextStyle(
              fontSize: NoctaFontSize.display,
              color: NoctaColors.inkPrimary,
            ),
          ),
          const SizedBox(height: NoctaSpace.s5),
          NCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.nightReportCalm(r.calmScore),
                  key: const Key('report-calm'),
                  style: TextStyle(
                    fontSize: NoctaFontSize.h2,
                    color: NoctaColors.accentAurora,
                  ),
                ),
                const SizedBox(height: NoctaSpace.s1),
                // Sağlık iddiası YOK: uygulama-içi göreli dinginlik ölçüsü.
                Text(
                  l10n.nightReportCalmDisclaimer,
                  style: TextStyle(
                    fontSize: NoctaFontSize.caption,
                    color: NoctaColors.inkFaint,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: NoctaSpace.s3),
          _Row(label: l10n.nightReportSessions, value: '${r.sessionCount}'),
          // **`movementEvents` GÖSTERİLMİYOR (D-10):** ölçmüyoruz. Dedektör "hareket"
          // ile "ses"i ayıramıyor (docs/04 §120 fixture'ları yok) ve alan her zaman 0
          // dönüyor. "Movement events: 0" göstermek, ölçmediğimiz bir şeyi ölçmüş
          // gibi sunmaktır — sıfır bile bir iddiadır.
          _Row(label: l10n.nightReportSoundEvents, value: '${r.soundEvents}'),
          Padding(
            padding: const EdgeInsets.only(top: NoctaSpace.s1),
            child: Text(
              l10n.nightReportLoudHint,
              key: const Key('report-loud-hint'),
              style: TextStyle(
                fontSize: NoctaFontSize.caption,
                color: NoctaColors.inkFaint,
              ),
            ),
          ),
          const SizedBox(height: NoctaSpace.s5),
          NButton(
            key: const Key('report-share'),
            label: _sharing ? l10n.nightReportSharing : l10n.nightReportShare,
            onPressed: _sharing ? null : _share,
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: NoctaSpace.s1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: NoctaFontSize.body,
              color: NoctaColors.inkSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: NoctaFontSize.body,
              color: NoctaColors.inkPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
