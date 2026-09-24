import 'package:flutter/material.dart';

import '../generated/nocta_tokens.dart';

/// NOCTA kart yüzeyi — Elegy'de **keskin kenarlı koyu panel**.
///
/// Kolajın iki yüzeyi var: koyu panel (bu) ve krem kağıt (`NPaper`).
/// Yuvarlatma ve gölge yok; ayrım 1px çizgiyle yapılır.
class NCard extends StatelessWidget {
  const NCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(NoctaSpace.s4),
    this.color = NoctaColors.bgRaised,
    this.border = NoctaColors.lineSoft,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    final Color? edge = border;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(NoctaRadius.card),
        border: edge == null ? null : Border.all(color: edge),
      ),
      child: child,
    );
  }
}
