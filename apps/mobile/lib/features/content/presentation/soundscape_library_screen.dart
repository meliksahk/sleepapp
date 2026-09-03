import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/design_system/design_system.dart';
import '../../../core/design_system/responsive.dart';
import '../../../l10n/app_localizations.dart';
import '../content_models.dart';
import '../content_providers.dart';

/// Soundscape kütüphanesi (docs/04 M1). Feed'i tüketip listeler.
/// Tablet: GridView ile çok sütunlu; mobil: tek sütun liste.
/// Kategori filtresi: gürültü / doğa / rahatlatıcı — noise'dan ayrı malzeme sesleri için.
class SoundscapeLibraryScreen extends ConsumerStatefulWidget {
  const SoundscapeLibraryScreen({super.key});

  @override
  ConsumerState<SoundscapeLibraryScreen> createState() => _SoundscapeLibraryScreenState();
}

class _SoundscapeLibraryScreenState extends ConsumerState<SoundscapeLibraryScreen> {
  String _category = 'all';

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(soundscapeFeedProvider);
    return Scaffold(
      appBar: AppBar(title: NMono(AppL10n.of(context).libraryTitle)),
      body: SafeArea(
        child: feed.when(
          data: (list) => _filteredList(context, list),
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

  Widget _filteredList(BuildContext context, List<Soundscape> list) {
    if (list.isEmpty) {
      return Center(
        child: NEmptyState(
          key: const Key('soundscape-empty'),
          title: AppL10n.of(context).libraryEmpty,
          actionLabel: AppL10n.of(context).homeOpenMixer,
          onAction: () => context.push('/mixer'),
        ),
      );
    }
    final filtered = _category == 'all' ? list : list.where((s) => s.category == _category).toList();
    return Column(
      children: [
        _categoryFilter(),
        Expanded(child: _listContent(context, filtered)),
      ],
    );
  }

  Widget _categoryFilter() {
    const cats = ['all', 'noise', 'nature', 'relaxing'];
    String label(String c) {
      switch (c) {
        case 'noise':
          return 'Gürültüler';
        case 'nature':
          return 'Doğadan';
        case 'relaxing':
          return 'Rahatlatıcı';
        default:
          return 'Tümü';
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(NoctaSpace.s4, NoctaSpace.s3, NoctaSpace.s4, NoctaSpace.s2),
      child: Wrap(
        spacing: NoctaSpace.s2,
        children: [
          for (final c in cats)
            ChoiceChip(
              label: Text(label(c)),
              selected: _category == c,
              onSelected: (_) => setState(() => _category = c),
            ),
        ],
      ),
    );
  }

  Widget _listContent(BuildContext context, List<Soundscape> list) {
    if (list.isEmpty) {
      return Center(
        child: Text('Bu kategoride ses yok', style: TextStyle(color: NoctaColors.inkSecondary)),
      );
    }
    final r = Responsive.of(context);
    final padding = r.horizontalPadding;

    if (!r.isWide) {
      return ListView.separated(
        padding: padding,
        itemCount: list.length,
        separatorBuilder: (context, index) =>
            const Divider(color: NoctaColors.lineHairline),
        itemBuilder: (context, i) => _SoundscapeRow(s: list[i]),
      );
    }

    return GridView.builder(
      padding: padding,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: r.gridColumns,
        childAspectRatio: 2.4,
        crossAxisSpacing: NoctaSpace.s4,
        mainAxisSpacing: NoctaSpace.s4,
      ),
      itemCount: list.length,
      itemBuilder: (context, i) => _SoundscapeCard(s: list[i]),
    );
  }
}

/// Mobil satır — mevcut tasarım.
class _SoundscapeRow extends StatelessWidget {
  const _SoundscapeRow({required this.s});
  final Soundscape s;

  @override
  Widget build(BuildContext context) {
    final affinity = s.affinityLabel();
    return GestureDetector(
      key: Key('soundscape-${s.slug}'),
      onTap: () => context.push('/library/${s.slug}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: NoctaSpace.s4),
        child: _SoundscapeContent(s: s, affinity: affinity),
      ),
    );
  }
}

/// Tablet kartı — daha geniş, dokulu kare daha büyük.
class _SoundscapeCard extends StatelessWidget {
  const _SoundscapeCard({required this.s});
  final Soundscape s;

  @override
  Widget build(BuildContext context) {
    final affinity = s.affinityLabel();
    return GestureDetector(
      key: Key('soundscape-${s.slug}'),
      onTap: () => context.push('/library/${s.slug}'),
      child: Container(
        decoration: BoxDecoration(
          color: NoctaColors.bgOverlay,
          border: Border.all(color: NoctaColors.lineHairline),
        ),
        padding: const EdgeInsets.all(NoctaSpace.s4),
        child: Row(
          children: [
            ClipRect(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: NoctaColors.bgBase,
                  border: Border.all(color: NoctaColors.lineHairline),
                ),
                child: CustomPaint(painter: _TexturePainter(seed: s.slug.hashCode)),
              ),
            ),
            const SizedBox(width: NoctaSpace.s4),
            Expanded(child: _SoundscapeText(s: s, affinity: affinity)),
          ],
        ),
      ),
    );
  }
}

class _SoundscapeContent extends StatelessWidget {
  const _SoundscapeContent({required this.s, required this.affinity});
  final Soundscape s;
  final String affinity;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Dokulu kare — ClipRect ile ÇERÇEVE İÇİNDE kilitli, yazıya TAŞMAZ.
        ClipRect(
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: NoctaColors.bgBase,
              border: Border.all(color: NoctaColors.lineHairline),
            ),
            child: CustomPaint(painter: _TexturePainter(seed: s.slug.hashCode)),
          ),
        ),
        const SizedBox(width: NoctaSpace.s4),
        Expanded(child: _SoundscapeText(s: s, affinity: affinity)),
      ],
    );
  }
}

String _catLabel(String c) {
  switch (c) {
    case 'noise':
      return 'Gürültü';
    case 'nature':
      return 'Doğa';
    case 'relaxing':
      return 'Rahatlatıcı';
    default:
      return c;
  }
}

class _SoundscapeText extends StatelessWidget {
  const _SoundscapeText({required this.s, required this.affinity});
  final Soundscape s;
  final String affinity;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Kategori rozeti — noise'dan ayrı malzeme sesleri için ayırt edici.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: NoctaColors.bgOverlay,
            border: Border.all(color: NoctaColors.lineHairline),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            _catLabel(s.category),
            style: TextStyle(fontSize: 9, letterSpacing: 0.8, color: NoctaColors.inkFaint),
          ),
        ),
        const SizedBox(height: NoctaSpace.s1),
        NDisplay(s.title('en'), size: 20),
        if (affinity.isNotEmpty) ...[
          const SizedBox(height: NoctaSpace.s1),
          NMono(
            AppL10n.of(context).libraryAffinity(affinity),
            key: Key('soundscape-affinity-${s.slug}'),
            track: NoctaTrack.tight,
          ),
        ],
      ],
    );
  }
}
/// Tarif karesinin dokusu — her slug kendi deterministik desenini alır.
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