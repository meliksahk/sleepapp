import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/flavor.dart';
import '../../core/design_system/design_system.dart';

/// Geçici iskelet ekranı (Faz M0). M1'de onboarding + archetype testi gelir.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(NoctaSpace.s5),
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
                style: TextStyle(fontSize: NoctaFontSize.body, color: NoctaColors.inkSecondary),
              ),
              const SizedBox(height: NoctaSpace.s6),
              NCard(
                child: Text(
                  'flavor: ${FlavorConfig.current.name}',
                  style: TextStyle(color: NoctaColors.inkSecondary),
                ),
              ),
              const SizedBox(height: NoctaSpace.s5),
              NButton(
                label: 'Find your sleep identity',
                onPressed: () => context.push('/archetype'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
