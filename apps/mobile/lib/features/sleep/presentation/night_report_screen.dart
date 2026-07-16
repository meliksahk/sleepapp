import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/design_system/design_system.dart';
import '../../../core/share/sharer.dart';
import '../../analytics/analytics_providers.dart';
import '../../archetype/archetype_providers.dart' show sharerProvider;
import '../sleep_models.dart';
import '../sleep_providers.dart';

/// Gece Raporu (docs/04, viral kanca #2) — bir gecenin özeti + paylaşım.
/// Paylaşım metni sunucudan gelir (GET /v1/sharing/report) → kart metni tek kaynak.
/// Not: metinler l10n'a M1'de taşınacak.
class NightReportScreen extends ConsumerStatefulWidget {
  const NightReportScreen({super.key, required this.nightDate});

  final String nightDate;

  @override
  ConsumerState<NightReportScreen> createState() => _NightReportScreenState();
}

class _NightReportScreenState extends ConsumerState<NightReportScreen> {
  bool _sharing = false;

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final share = await ref.read(sleepControllerProvider).reportShare(widget.nightDate);
      if (share == null) {
        messenger.showSnackBar(const SnackBar(content: Text('No report for this night')));
        return;
      }
      await ref.read(sharerProvider).share(ShareContent(text: share.title, url: share.webUrl));
      // Viral huni ölçümü (analitik bloklamaz). props YOK: gece tarihi PII'ye yakın
      // ve huni için gereksiz (docs/analytics-events.md).
      ref.read(analyticsProvider).track('report_shared');
      messenger.showSnackBar(const SnackBar(content: Text('Link copied')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Could not share')));
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = ref.watch(nightReportProvider(widget.nightDate));
    return Scaffold(
      appBar: AppBar(title: const Text('Night report')),
      body: SafeArea(
        child: report.when(
          data: (r) => r == null ? _empty() : _report(r),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: IconButton(
              key: const Key('report-retry'),
              icon: const Icon(Icons.refresh),
              iconSize: 40,
              onPressed: () => ref.invalidate(nightReportProvider(widget.nightDate)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _empty() => Center(
    child: Text(
      'No sleep recorded for this night',
      key: const Key('report-empty'),
      style: TextStyle(fontSize: NoctaFontSize.body, color: NoctaColors.inkSecondary),
    ),
  );

  Widget _report(NightReport r) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(NoctaSpace.s5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            r.nightDate,
            style: TextStyle(fontSize: NoctaFontSize.body, color: NoctaColors.inkSecondary),
          ),
          const SizedBox(height: NoctaSpace.s2),
          Text(
            formatMinutes(r.totalDurationMinutes),
            key: const Key('report-duration'),
            style: TextStyle(fontSize: NoctaFontSize.display, color: NoctaColors.inkPrimary),
          ),
          const SizedBox(height: NoctaSpace.s5),
          NCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Calm ${r.calmScore}/100',
                  key: const Key('report-calm'),
                  style: TextStyle(fontSize: NoctaFontSize.h2, color: NoctaColors.accentAurora),
                ),
                const SizedBox(height: NoctaSpace.s1),
                // Sağlık iddiası YOK: uygulama-içi göreli dinginlik ölçüsü.
                Text(
                  'An in-app calm measure for your ritual — not a health score.',
                  style: TextStyle(fontSize: NoctaFontSize.caption, color: NoctaColors.inkFaint),
                ),
              ],
            ),
          ),
          const SizedBox(height: NoctaSpace.s3),
          _Row(label: 'Sessions', value: '${r.sessionCount}'),
          _Row(label: 'Movement events', value: '${r.movementEvents}'),
          _Row(label: 'Sound events', value: '${r.soundEvents}'),
          const SizedBox(height: NoctaSpace.s5),
          NButton(
            key: const Key('report-share'),
            label: _sharing ? 'Sharing…' : 'Share this night',
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
            style: TextStyle(fontSize: NoctaFontSize.body, color: NoctaColors.inkSecondary),
          ),
          Text(
            value,
            style: TextStyle(fontSize: NoctaFontSize.body, color: NoctaColors.inkPrimary),
          ),
        ],
      ),
    );
  }
}
