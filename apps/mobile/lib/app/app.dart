import 'package:flutter/material.dart';
import '../core/design_system/nocta_theme.dart';
import 'router.dart';

/// Kök uygulama widget'ı — dark-first (uygulama gece yaşar, docs/06).
class NoctaApp extends StatelessWidget {
  const NoctaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'NOCTA',
      debugShowCheckedModeBanner: false,
      theme: buildNoctaDarkTheme(),
      routerConfig: appRouter,
    );
  }
}
