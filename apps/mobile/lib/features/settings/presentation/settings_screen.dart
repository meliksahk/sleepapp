import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/design_system/design_system.dart';
import '../../auth/auth_providers.dart';

/// Ayarlar (docs/06 hesap güvenliği). "Diğer cihazlardan çık" akışı.
/// Not: metinler l10n'a M1'de taşınacak.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _busy = false;

  Future<void> _revokeOthers() async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final revoked = await ref.read(authControllerProvider).revokeOtherSessions();
      messenger.showSnackBar(
        SnackBar(content: Text('$revoked other device${revoked == 1 ? '' : 's'} signed out')),
      );
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Could not sign out other devices')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(NoctaSpace.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Account security',
                style: TextStyle(fontSize: NoctaFontSize.body, color: NoctaColors.inkSecondary),
              ),
              const SizedBox(height: NoctaSpace.s3),
              NButton(
                key: const Key('revoke-others'),
                label: _busy ? 'Signing out…' : 'Log out other devices',
                onPressed: _busy ? null : _revokeOthers,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
