import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/design_system/design_system.dart';
import '../content_models.dart';
import '../content_providers.dart';

/// Soundscape kütüphanesi (docs/04 M1). Feed'i tüketip listeler. Boş/yükleme/hata
/// durumları. Not: kullanıcı metinleri l10n'a M1'de taşınacak (M0 hard-coded deseni).
class SoundscapeLibraryScreen extends ConsumerWidget {
  const SoundscapeLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(soundscapeFeedProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Soundscapes')),
      body: SafeArea(
        child: feed.when(
          data: (list) => _list(list),
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

  Widget _list(List<Soundscape> list) {
    if (list.isEmpty) {
      return Center(
        child: Text(
          'No soundscapes yet',
          key: const Key('soundscape-empty'),
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
          key: Key('soundscape-${s.slug}'),
          child: Text(
            s.title('en'),
            style: TextStyle(fontSize: NoctaFontSize.body, color: NoctaColors.inkPrimary),
          ),
        );
      },
    );
  }
}
