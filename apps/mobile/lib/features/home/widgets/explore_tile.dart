import 'package:flutter/material.dart';

import '../../../core/design_system/design_system.dart';

/// Keşif rafı karosu — ikincil navigasyon.
///
/// **Neden karo, neden ghost buton dizisi değil:** ana ekranda alt alta 5-6 özdeş
/// ghost buton "dev menüsü" hissi veriyordu (denetim bulgusu). İkonlu karo, ikincil
/// gezinmeyi birincil eylemden GÖRSEL OLARAK ayırır — aynı ağırlıkta iki buton
/// yan yana durduğunda kullanıcı neyin önemli olduğunu okuyamaz.
///
/// Sabit yükseklik YOK: TR etiketleri daha uzun ("Ses manzaraları"); `minHeight` +
/// `maxLines: 2` ile karo büyür, taşma yerine sarar.
class ExploreTile extends StatelessWidget {
  const ExploreTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Elegy: dolu kart degil, yalnizca 1px cerceve. Ikon kucuk ve sonuk;
    // agirligi etiket tasiyor (mono, iki satira sarabilir).
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 96),
        padding: const EdgeInsets.all(NoctaSpace.s4),
        decoration: const BoxDecoration(
          border: Border.fromBorderSide(
            BorderSide(color: NoctaColors.lineSoft),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 20, color: NoctaColors.inkFaint),
            const SizedBox(height: NoctaSpace.s5),
            NMono(
              label,
              color: NoctaColors.inkSecondary,
              track: NoctaTrack.tight,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}
