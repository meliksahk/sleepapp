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
      appBar: AppBar(title: NMono(AppL10n.of(context).libraryTitle)),
      body: SafeArea(
        child: feed.when(
          data: (list) => _list(context, list),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => NErrorState(
            retryKey: const Key('soundscape-retry'),
            message: AppL10n.of(context).loadFailed,
            retryLabel: AppL10n.of(context).offlineRetry,
            onRetry: () => ref.invalidate(soundscapeFeedProvider),
          ),
        ),
      ),
    );
  }

  Widget _list(BuildContext context, List<Soundscape> list) {
    if (list.isEmpty) {
      // Bos hal OZUR degil YONLENDIRME: kullanici mikseri acip kendi tarifini kursun.
      return Center(
        child: NEmptyState(
          key: const Key('soundscape-empty'),
          title: AppL10n.of(context).libraryEmpty,
          actionLabel: AppL10n.of(context).homeOpenMixer,
          onAction: () => context.push('/mixer'),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(NoctaSpace.s6),
      itemCount: list.length,
      // Elegy: kart yigini degil, sac teli cizgiyle ayrilmis satirlar.
      separatorBuilder: (context, index) =>
          const Divider(color: NoctaColors.lineHairline),
      itemBuilder: (context, i) {
        final s = list[i];
        final affinity = s.affinityLabel();
        return GestureDetector(
          key: Key('soundscape-${s.slug}'),
          onTap: () => context.push('/library/${s.slug}'),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: NoctaSpace.s4),
            child: Row(
              children: [
                // Sesin dokusu: her tarif kendi kucuk dokulu karesiyle anilir.
                Container(
                  width: 40,
                  height: 40,
                  color: NoctaColors.bgOverlay,
                  child: CustomPaint(
                    painter: _TexturePainter(seed: s.slug.hashCode),
                  ),
                ),
                const SizedBox(width: NoctaSpace.s4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      NDisplay(s.title('en'), size: 20),
                      // Uygun uyku kimligi - archetype/ses bagi (varsa).
                      if (affinity.isNotEmpty) ...[
                        const SizedBox(height: NoctaSpace.s1),
                        NMono(
                          AppL10n.of(context).libraryAffinity(affinity),
                          key: Key('soundscape-affinity-${s.slug}'),
                          track: NoctaTrack.tight,
                        ),
                      ],
                    ],
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

/// Tarif karesinin dokusu — her slug kendi deterministik desenini alır.
/// Görsel varlık indirmeden "her sesin bir yüzü var" hissini verir.
class _TexturePainter extends CustomPainter {
  const _TexturePainter({required this.seed});

  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = NoctaColors.inkSecondary
      ..strokeWidth = 1;
    final int step = 3 + (seed.abs() % 4);
    final bool diagonal = seed.isEven;
    for (double i = -size.height; i < size.width; i += step + 2) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(diagonal ? i + size.height : i, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_TexturePainter old) => old.seed != seed;
}
