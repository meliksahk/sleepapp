import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/share/sharer.dart';
import '../auth/auth_providers.dart';
import 'archetype_controller.dart';

/// Archetype test controller'ı — auth (oturum + refresh) + api client üzerine.
final archetypeControllerProvider = Provider<ArchetypeController>((ref) {
  return ArchetypeController(ref.read(authControllerProvider), ref.read(apiClientProvider));
});

/// Paylaşım adaptörü — interim: panoya kopyalar (native share sheet ertelendi).
final sharerProvider = Provider<Sharer>((ref) => ClipboardSharer());
