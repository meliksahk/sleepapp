import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';
import '../content_models.dart';
import '../content_providers.dart';

/// Soundscape detay ekranı (docs/04 M1): başlık + preset sayısı + önizleme durumu.
/// Yok/yayınlanmamış → "not found".
class SoundscapeDetailScreen extends ConsumerWidget {
  const SoundscapeDetailScreen({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(soundscapeDetailProvider(slug));
    return Scaffold(
      appBar: AppBar(title: Text(AppL10n.of(context).soundscapeDetailTitle)),
      body: SafeArea(
        child: detail.when(
          data: (d) => d == null ? _notFound(context) : _detail(context, d),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: IconButton(
              key: const Key('soundscape-detail-retry'),
              icon: const Icon(Icons.refresh),
              iconSize: 40,
              onPressed: () => ref.invalidate(soundscapeDetailProvider(slug)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _notFound(BuildContext context) => Center(
    child: Text(
      AppL10n.of(context).soundscapeNotFound,
      key: const Key('soundscape-detail-notfound'),
      style: TextStyle(
        fontSize: NoctaFontSize.body,
        color: NoctaColors.inkSecondary,
      ),
    ),
  );

  Widget _detail(BuildContext context, SoundscapeDetail d) {
    return Padding(
      padding: const EdgeInsets.all(NoctaSpace.s5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            d.soundscape.title('en'),
            key: const Key('soundscape-detail-title'),
            style: TextStyle(
              fontSize: NoctaFontSize.display,
              color: NoctaColors.inkPrimary,
            ),
          ),
          const SizedBox(height: NoctaSpace.s3),
          Text(
            '${d.presets.length} preset${d.presets.length == 1 ? '' : 's'}',
            style: TextStyle(
              fontSize: NoctaFontSize.body,
              color: NoctaColors.inkSecondary,
            ),
          ),
          if (d.previewUrl != null) ...[
            const SizedBox(height: NoctaSpace.s3),
            Text(
              AppL10n.of(context).soundscapePreviewAvailable,
              key: const Key('soundscape-preview'),
              style: TextStyle(
                fontSize: NoctaFontSize.body,
                color: NoctaColors.accentAurora,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
