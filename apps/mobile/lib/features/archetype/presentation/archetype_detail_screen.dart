import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/design_system/design_system.dart';
import '../archetype_providers.dart';

/// Archetype detay ekranı (docs/04) — bir uyku kimliğinin isim/tagline/özetini
/// gösterir. İçerik `archetypeContentProvider` slug→info haritasından çözülür.
/// Home kimlik kartından açılır. Not: metinler l10n'a M1'de taşınacak.
class ArchetypeDetailScreen extends ConsumerWidget {
  const ArchetypeDetailScreen({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(archetypeContentProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Sleep identity')),
      body: SafeArea(
        child: content.when(
          data: (map) {
            final info = map[slug];
            if (info == null) {
              return Center(
                child: Text(
                  'Unknown identity',
                  key: const Key('identity-unknown'),
                  style: TextStyle(fontSize: NoctaFontSize.body, color: NoctaColors.inkSecondary),
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
                    style: TextStyle(fontSize: NoctaFontSize.h1, color: NoctaColors.inkPrimary),
                  ),
                  const SizedBox(height: NoctaSpace.s2),
                  Text(
                    info.tagline,
                    style: TextStyle(fontSize: NoctaFontSize.body, color: NoctaColors.accentAurora),
                  ),
                  const SizedBox(height: NoctaSpace.s4),
                  Text(
                    info.summary,
                    style: TextStyle(fontSize: NoctaFontSize.body, color: NoctaColors.inkSecondary),
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: IconButton(
              key: const Key('detail-retry'),
              icon: const Icon(Icons.refresh),
              iconSize: 40,
              onPressed: () => ref.invalidate(archetypeContentProvider),
            ),
          ),
        ),
      ),
    );
  }
}
