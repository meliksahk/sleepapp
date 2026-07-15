import 'package:flutter/material.dart';
import '../../app/flavor.dart';
import '../../core/design_system/nocta_theme.dart';

/// Geçici iskelet ekranı (Faz M0). M1'de onboarding + archetype testi gelir.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'NOCTA',
              style: TextStyle(
                fontSize: NoctaFontSize.display,
                color: NoctaColors.inkPrimary,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: NoctaSpace.s3),
            Text(
              'Your night has an identity',
              style: TextStyle(
                fontSize: NoctaFontSize.body,
                color: NoctaColors.inkSecondary,
              ),
            ),
            const SizedBox(height: NoctaSpace.s6),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: NoctaSpace.s4,
                vertical: NoctaSpace.s2,
              ),
              decoration: BoxDecoration(
                color: NoctaColors.accentAurora,
                borderRadius: BorderRadius.circular(NoctaRadius.chip),
              ),
              child: Text(
                'flavor: ${FlavorConfig.current.name}',
                style: TextStyle(color: NoctaColors.bgBase),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
