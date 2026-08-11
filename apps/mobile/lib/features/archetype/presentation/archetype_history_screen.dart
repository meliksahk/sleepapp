import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/network_error_view.dart';
import '../../../core/design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';
import '../archetype_models.dart';
import '../archetype_gradient.dart';
import '../archetype_providers.dart';

/// Kimlik geçmişi — kullanıcının archetype sonuçları (yeniden eskiye).
/// #103'te eklenen `GET /v1/archetype/results` ucunu tüketir: testi tekrar
/// edince kimlik değişebilir ("Overthinker → Deep Ocean") ve bu anlatı
/// kullanıcının kendi verisi. Not: metinler l10n'a M1'de taşınacak.
class ArchetypeHistoryScreen extends ConsumerWidget {
  const ArchetypeHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final history = ref.watch(archetypeHistoryProvider);
    final content = ref.watch(archetypeContentProvider);

    return Scaffold(
      appBar: AppBar(title: NMono(l10n.identityHistoryTitle)),
      body: SafeArea(
        child: history.when(
          data: (list) => list.isEmpty
              ? _empty(context)
              : _list(context, ref, list, content),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => NetworkErrorView(
            retryKey: const Key('history-retry'),
            onRetry: () => ref.invalidate(archetypeHistoryProvider),
          ),
        ),
      ),
    );
  }

  Widget _empty(BuildContext context) => Center(
    child: NEmptyState(
      key: const Key('history-empty'),
      title: AppL10n.of(context).identityHistoryEmpty,
    ),
  );

  Widget _list(
    BuildContext context,
    WidgetRef ref,
    List<ArchetypeResult> list,
    AsyncValue<Map<String, ArchetypeInfo>> content,
  ) {
    return ListView.separated(
      padding: const EdgeInsets.all(NoctaSpace.s6),
      itemCount: list.length,
      // Elegy: kart yığını değil, saç teli çizgiyle ayrılmış satırlar.
      separatorBuilder: (context, index) =>
          const Divider(color: NoctaColors.lineHairline),
      itemBuilder: (context, i) {
        final r = list[i];
        // İsim içerikten çözülür; içerik yoksa slug (dayanıklı — detay ekranıyla aynı).
        final name = content.maybeWhen(
          data: (m) => m[r.archetypeSlug]?.name,
          orElse: () => null,
        );
        return GestureDetector(
          key: Key('history-item-${r.createdAt}'),
          onTap: () => context.push('/identity/${r.archetypeSlug}'),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: NoctaSpace.s4),
            child: Row(
              children: [
                // Her kimliğin kendi lekesi — güncel olan daha iri.
                Container(
                  width: i == 0 ? 26 : 18,
                  height: i == 0 ? 34 : 24,
                  margin: const EdgeInsets.only(top: NoctaSpace.s1),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(NoctaRadius.full),
                    gradient: archetypeGradientForSlug(r.archetypeSlug),
                  ),
                ),
                const SizedBox(width: NoctaSpace.s4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      NDisplay(name ?? r.archetypeSlug, size: 20),
                      const SizedBox(height: NoctaSpace.s1),
                      NMono(
                        // ISO tarihin gün kısmı (intl bağımlılığı eklemeden).
                        r.createdAt.length >= 10
                            ? r.createdAt.substring(0, 10)
                            : r.createdAt,
                        track: NoctaTrack.tight,
                      ),
                    ],
                  ),
                ),
                if (i == 0)
                  NMono(
                    AppL10n.of(context).identityHistoryCurrent,
                    key: const Key('history-current-badge'),
                    color: NoctaColors.accentAuroraInk,
                    track: NoctaTrack.tight,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
