import 'package:flutter/material.dart';

import '../generated/nocta_tokens.dart';
import 'n_text.dart';

/// Elegy butonu üç yüzeyden birinde durur:
/// - [primary]  — krem kağıt bloğu, koyu mono etiket (ekranın tek asıl eylemi)
/// - [ghost]    — 1px çerçeve, ikincil
/// - [inverse]  — kağıdın ÜSTÜNDEKİ koyu blok (krem kartın içindeki CTA)
enum NButtonVariant { primary, ghost, inverse }

/// NOCTA temel butonu — token'lı, dokunma hedefi >= 44px (CLAUDE.md §7).
///
/// Elegy'de buton yuvarlatılmaz (`radius.button = 0`) ve etiketi mono/aralıklıdır;
/// bu iki karar token'da yaşar, burada değil.
class NButton extends StatelessWidget {
  const NButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = NButtonVariant.primary,
    this.rule = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final NButtonVariant variant;

  /// Sağ kenardaki kısa çizgi — tasarımdaki tam genişlik CTA imzası.
  final bool rule;

  /// Etiketi sola, çizgiyi sağa iten tam genişlik yerleşimi.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    final (Color bg, Color fg, Color? border) = switch (variant) {
      NButtonVariant.primary => (NoctaColors.bgPaper, NoctaColors.inkOnPaper, null),
      NButtonVariant.inverse => (const Color(0xFF0B0B0B), NoctaColors.inkPrimary, null),
      NButtonVariant.ghost => (
        Colors.transparent,
        NoctaColors.inkSecondary,
        NoctaColors.lineStrong,
      ),
    };

    final Widget label0 = NMono(
      label,
      color: enabled ? fg : fg.withValues(alpha: 0.45),
      height: 1,
    );

    return Semantics(
      button: true,
      enabled: enabled,
      child: Material(
        color: enabled ? bg : bg.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(NoctaRadius.button),
        child: InkWell(
          onTap: onPressed,
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.symmetric(
              horizontal: NoctaSpace.s5,
              vertical: NoctaSpace.s3,
            ),
            decoration: border == null
                ? null
                : BoxDecoration(border: Border.all(color: border)),
            alignment: expand ? null : Alignment.center,
            child: expand
                ? Row(
                    children: <Widget>[
                      Expanded(child: label0),
                      if (rule) _Rule(color: fg),
                    ],
                  )
                : label0,
          ),
        ),
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(width: 24, height: 1, color: color);
}
