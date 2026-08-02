import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';
import '../../content/content_providers.dart';
import '../archetype_gradient.dart';
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
      appBar: AppBar(title: NMono(l10n.archetypeDetailTitle)),
      body: SafeArea(
        child: content.when(
          data: (map) {
            final info = map[slug];
            if (info == null) {
              return Center(
                child: NEmptyState(
                  key: const Key('identity-unknown'),
                  title: l10n.archetypeUnknown,
                ),
              );
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.all(NoctaSpace.s6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Kimliğin lekesi: arketibin kendi tenti, daire değil elips.
                  Container(
                    width: 150,
                    height: 196,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(NoctaRadius.full),
                      gradient: archetypeGradientForSlug(slug),
                    ),
                  ),
                  const SizedBox(height: NoctaSpace.s8),
                  NMono(l10n.archetypeDetailTitle, track: NoctaTrack.wide),
                  const SizedBox(height: NoctaSpace.s3),
                  NDisplay(
                    info.name,
                    key: const Key('detail-name'),
                    size: NoctaFontSize.display,
                    height: 1.05,
                  ),
                  const SizedBox(height: NoctaSpace.s3),
                  // Vurgu METNİ accentAuroraInk: ham kızıl (#C1442E) koyu zeminde
                  // 3.4:1 ile AA'yı geçmiyor.
                  Text(
                    info.tagline,
                    style: const TextStyle(
                      fontSize: NoctaFontSize.body,
                      color: NoctaColors.accentAuroraInk,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: NoctaSpace.s5),
                  Text(
                    info.summary,
                    style: const TextStyle(
                      fontSize: NoctaFontSize.body,
                      color: NoctaColors.inkSecondary,
                      height: 1.7,
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
            NDisplay(
              AppL10n.of(context).archetypeSoundsThatSuitYou,
              key: const Key('sounds-heading'),
              size: NoctaFontSize.h2,
            ),
            const SizedBox(height: NoctaSpace.s4),
            for (final s in list)
              Padding(
                padding: const EdgeInsets.only(bottom: NoctaSpace.s3),
                child: GestureDetector(
                  key: Key('detail-sound-${s.slug}'),
                  onTap: () => context.push('/library/${s.slug}'),
                  child: NCard(
                    child: NDisplay(s.title('en'), size: NoctaFontSize.h2 - 6),
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
