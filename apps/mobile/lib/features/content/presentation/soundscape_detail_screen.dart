import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/network_error_view.dart';
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
      appBar: AppBar(title: NMono(AppL10n.of(context).soundscapeDetailTitle)),
      body: SafeArea(
        child: detail.when(
          data: (d) => d == null ? _notFound(context) : _detail(context, d),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => NetworkErrorView(
            retryKey: const Key('soundscape-detail-retry'),
            onRetry: () => ref.invalidate(soundscapeDetailProvider(slug)),
          ),
        ),
      ),
    );
  }

  Widget _notFound(BuildContext context) => Center(
    child: NEmptyState(
      key: const Key('soundscape-detail-notfound'),
      title: AppL10n.of(context).soundscapeNotFound,
    ),
  );

  Widget _detail(BuildContext context, SoundscapeDetail d) {
    return Padding(
      padding: const EdgeInsets.all(NoctaSpace.s6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          NDisplay(
            d.soundscape.title('en'),
            key: const Key('soundscape-detail-title'),
            size: 44,
            height: 1.02,
          ),
          const SizedBox(height: NoctaSpace.s3),
          NMono(
            '${d.presets.length} preset${d.presets.length == 1 ? '' : 's'}',
            track: NoctaTrack.wide,
          ),
          if (d.previewUrl != null) ...[
            const SizedBox(height: NoctaSpace.s3),
            NMono(
              AppL10n.of(context).soundscapePreviewAvailable,
              key: const Key('soundscape-preview'),
              // Vurgu METNI acilmis kizil: ham #C1442E koyu zeminde 3.4:1.
              color: NoctaColors.accentAuroraInk,
              track: NoctaTrack.tight,
            ),
          ],
          const Spacer(),
          // Ekranın birincil eylemi: sesi DUYMAK. Mikseri bu tarifle açar —
          // ayrı bir mini oynatıcı değil, çünkü kullanıcı orada sesi kendi
          // mix'ine çevirip video olarak paylaşabilir (viral kanca #3).
          //
          // **Otomatik çalma YOK** (uyku uygulaması): ekran açılınca ses başlamaz,
          // mikserde de kullanıcı ayrıca çal'a basar.
          NButton(
            key: const Key('soundscape-play'),
            label: AppL10n.of(context).soundscapePlay,
            expand: true,
            rule: true,
            onPressed: () => context.push(
              '/mixer?soundscape=${Uri.encodeQueryComponent(d.soundscape.slug)}',
            ),
          ),
        ],
      ),
    );
  }
}
