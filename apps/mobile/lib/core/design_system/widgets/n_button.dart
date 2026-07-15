import 'package:flutter/material.dart';
import '../nocta_theme.dart';

enum NButtonVariant { primary, ghost }

/// NOCTA temel butonu — token'lı, dokunma hedefi >= 44px (CLAUDE.md §7).
class NButton extends StatelessWidget {
  const NButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = NButtonVariant.primary,
  });

  final String label;
  final VoidCallback? onPressed;
  final NButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    final bool primary = variant == NButtonVariant.primary;
    final Color bg = primary ? NoctaColors.accentAurora : Colors.transparent;
    final Color fg = primary ? NoctaColors.bgBase : NoctaColors.inkPrimary;
    final radius = BorderRadius.circular(NoctaRadius.button);

    return Material(
      color: bg,
      borderRadius: radius,
      child: InkWell(
        onTap: onPressed,
        borderRadius: radius,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(
            horizontal: NoctaSpace.s4,
            vertical: NoctaSpace.s2,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(color: fg, fontSize: NoctaFontSize.body, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
