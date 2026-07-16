import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';
import '../archetype_models.dart';
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
      appBar: AppBar(title: Text(l10n.identityHistoryTitle)),
      body: SafeArea(
        child: history.when(
          data: (list) => list.isEmpty
              ? _empty(context)
              : _list(context, ref, list, content),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: IconButton(
              key: const Key('history-retry'),
              icon: const Icon(Icons.refresh),
              iconSize: 40,
              onPressed: () => ref.invalidate(archetypeHistoryProvider),
            ),
          ),
        ),
      ),
    );
  }

  Widget _empty(BuildContext context) => Center(
    child: Text(
      AppL10n.of(context).identityHistoryEmpty,
      key: const Key('history-empty'),
      style: TextStyle(
        fontSize: NoctaFontSize.body,
        color: NoctaColors.inkSecondary,
      ),
    ),
  );

  Widget _list(
    BuildContext context,
    WidgetRef ref,
    List<ArchetypeResult> list,
    AsyncValue<Map<String, ArchetypeInfo>> content,
  ) {
    return ListView.separated(
      padding: const EdgeInsets.all(NoctaSpace.s5),
      itemCount: list.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: NoctaSpace.s3),
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
          child: NCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name ?? r.archetypeSlug,
                      style: TextStyle(
                        fontSize: NoctaFontSize.body,
                        color: NoctaColors.inkPrimary,
                      ),
                    ),
                    if (i == 0) ...[
                      const SizedBox(height: NoctaSpace.s1),
                      Text(
                        AppL10n.of(context).identityHistoryCurrent,
                        key: const Key('history-current-badge'),
                        style: TextStyle(
                          fontSize: NoctaFontSize.caption,
                          color: NoctaColors.accentAurora,
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  // ISO tarihin gün kısmı (intl bağımlılığı eklemeden).
                  r.createdAt.length >= 10
                      ? r.createdAt.substring(0, 10)
                      : r.createdAt,
                  style: TextStyle(
                    fontSize: NoctaFontSize.caption,
                    color: NoctaColors.inkSecondary,
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
