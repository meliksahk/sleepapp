import 'package:flutter/material.dart';
import '../nocta_theme.dart';

/// NOCTA kart yüzeyi — bg/raised + 1px iç kenarlık (docs/06 elevation).
class NCard extends StatelessWidget {
  const NCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(NoctaSpace.s4),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: NoctaColors.bgRaised,
        borderRadius: BorderRadius.circular(NoctaRadius.card),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: child,
    );
  }
}
