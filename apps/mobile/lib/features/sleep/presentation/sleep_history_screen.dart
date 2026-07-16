import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/design_system/design_system.dart';
import '../sleep_models.dart';
import '../sleep_providers.dart';

/// Uyku geçmişi (docs/04 M1): en yeni oturumları gece + süre ile listeler.
/// Boş/yükleme/hata durumları. Not: metinler l10n'a M1'de taşınacak.
class SleepHistoryScreen extends ConsumerWidget {
  const SleepHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(recentSleepSessionsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Sleep history')),
      body: SafeArea(
        child: sessions.when(
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
        return NCard(
          key: Key('sleep-session-${s.id}'),
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
        );
      },
    );
  }
}
