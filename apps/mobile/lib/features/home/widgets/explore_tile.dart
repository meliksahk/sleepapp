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
    return InkWell(
      borderRadius: BorderRadius.circular(NoctaRadius.card),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 88),
        child: NCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 24, color: NoctaColors.accentAurora),
              const SizedBox(height: NoctaSpace.s2),
              Text(
                label,
                maxLines: 2,
                softWrap: true,
                style: TextStyle(
                  fontSize: NoctaFontSize.body,
                  color: NoctaColors.inkPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
