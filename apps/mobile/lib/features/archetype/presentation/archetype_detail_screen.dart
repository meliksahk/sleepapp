import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';
import '../../content/content_providers.dart';
import '../archetype_providers.dart';

/// Archetype detay ekranı (docs/04) — bir uyku kimliğinin isim/tagline/özetini
/// gösterir. İçerik `archetypeContentProvider` slug→info haritasından çözülür.
/// Home kimlik kartından açılır.
class ArchetypeDetailScreen extends ConsumerWidget {
  const ArchetypeDetailScreen({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final content = ref.watch(archetypeContentProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.archetypeDetailTitle)),
      body: SafeArea(
        child: content.when(
          data: (map) {
            final info = map[slug];
            if (info == null) {
              return Center(
                child: Text(
                  l10n.archetypeUnknown,
                  key: const Key('identity-unknown'),
                  style: TextStyle(
                    fontSize: NoctaFontSize.body,
                    color: NoctaColors.inkSecondary,
                  ),
                ),
              );
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.all(NoctaSpace.s5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    info.name,
                    key: const Key('detail-name'),
                    style: TextStyle(
                      fontSize: NoctaFontSize.h1,
                      color: NoctaColors.inkPrimary,
                    ),
                  ),
                  const SizedBox(height: NoctaSpace.s2),
                  Text(
                    info.tagline,
                    style: TextStyle(
                      fontSize: NoctaFontSize.body,
                      color: NoctaColors.accentAurora,
                    ),
                  ),
                  const SizedBox(height: NoctaSpace.s4),
                  Text(
                    info.summary,
                    style: TextStyle(
                      fontSize: NoctaFontSize.body,
                      color: NoctaColors.inkSecondary,
                    ),
                  ),
                  _SoundsSection(slug: slug),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => NErrorState(
            retryKey: const Key('detail-retry'),
            message: AppL10n.of(context).loadFailed,
            retryLabel: AppL10n.of(context).offlineRetry,
            onRetry: () => ref.invalidate(archetypeContentProvider),
          ),
        ),
      ),
    );
  }
}

/// Bu kimliğe uygun sesler — detay→içerik döngüsü. Boş/yükleme/hata → gizli
/// (bölüm ikincil; detay ekranını bloklamaz).
class _SoundsSection extends ConsumerWidget {
  const _SoundsSection({required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sounds = ref.watch(soundscapesForArchetypeProvider(slug));
    return sounds.maybeWhen(
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: NoctaSpace.s6),
            Text(
              AppL10n.of(context).archetypeSoundsThatSuitYou,
              key: const Key('sounds-heading'),
              style: TextStyle(
                fontSize: NoctaFontSize.h2,
                color: NoctaColors.inkPrimary,
              ),
            ),
            const SizedBox(height: NoctaSpace.s3),
            for (final s in list)
              Padding(
                padding: const EdgeInsets.only(bottom: NoctaSpace.s3),
                child: GestureDetector(
                  key: Key('detail-sound-${s.slug}'),
                  onTap: () => context.push('/library/${s.slug}'),
                  child: NCard(
                    child: Text(
                      s.title('en'),
                      style: TextStyle(
                        fontSize: NoctaFontSize.body,
                        color: NoctaColors.inkPrimary,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}
