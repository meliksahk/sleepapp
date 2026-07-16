import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';
import '../content_models.dart';
import '../content_providers.dart';

/// Soundscape kütüphanesi (docs/04 M1). Feed'i tüketip listeler. Boş/yükleme/hata
/// durumları.
class SoundscapeLibraryScreen extends ConsumerWidget {
  const SoundscapeLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(soundscapeFeedProvider);
    return Scaffold(
      appBar: AppBar(title: Text(AppL10n.of(context).libraryTitle)),
      body: SafeArea(
        child: feed.when(
          data: (list) => _list(context, list),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: IconButton(
              key: const Key('soundscape-retry'),
              icon: const Icon(Icons.refresh),
              iconSize: 40,
              onPressed: () => ref.invalidate(soundscapeFeedProvider),
            ),
          ),
        ),
      ),
    );
  }

  Widget _list(BuildContext context, List<Soundscape> list) {
    if (list.isEmpty) {
      return Center(
        child: Text(
          AppL10n.of(context).libraryEmpty,
          key: const Key('soundscape-empty'),
          style: TextStyle(
            fontSize: NoctaFontSize.body,
            color: NoctaColors.inkSecondary,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(NoctaSpace.s5),
      itemCount: list.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: NoctaSpace.s3),
      itemBuilder: (context, i) {
        final s = list[i];
        final affinity = s.affinityLabel();
        return GestureDetector(
          key: Key('soundscape-${s.slug}'),
          onTap: () => context.push('/library/${s.slug}'),
          child: NCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.title('en'),
                  style: TextStyle(
                    fontSize: NoctaFontSize.body,
                    color: NoctaColors.inkPrimary,
                  ),
                ),
                // Uygun uyku kimliği — archetype↔ses bağı (yalnızca affinity varsa).
                if (affinity.isNotEmpty) ...[
                  const SizedBox(height: NoctaSpace.s1),
                  Text(
                    AppL10n.of(context).libraryAffinity(affinity),
                    key: Key('soundscape-affinity-${s.slug}'),
                    style: TextStyle(
                      fontSize: NoctaFontSize.caption,
                      color: NoctaColors.inkSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
