import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/design_system/design_system.dart';
import '../../auth/auth_providers.dart';
import '../../profile/profile_providers.dart';

/// Ayarlar (docs/06 hesap güvenliği). "Diğer cihazlardan çık" akışı.
/// Not: metinler l10n'a M1'de taşınacak.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _busy = false;
  bool _savingNotifications = false;

  /// Bildirim toggle'ı: optimistic değil — PATCH sonucunu bekleyip provider'ı
  /// tazeler; hata olursa switch eski değerinde kalır (kullanıcıya snackbar).
  Future<void> _setNotifications(bool enabled) async {
    if (_savingNotifications) return;
    setState(() => _savingNotifications = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(profileControllerProvider).setNotificationsEnabled(enabled);
      ref.invalidate(profileProvider); // switch güncel sunucu değerini yansıtır
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not update notification setting')),
      );
    } finally {
      if (mounted) setState(() => _savingNotifications = false);
    }
  }

  Future<void> _revokeOthers() async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final revoked = await ref.read(authControllerProvider).revokeOtherSessions();
      ref.invalidate(activeSessionsProvider); // liste güncellenir
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
    final sessions = ref.watch(activeSessionsProvider);
    final profile = ref.watch(profileProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(NoctaSpace.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Notifications',
                style: TextStyle(fontSize: NoctaFontSize.body, color: NoctaColors.inkSecondary),
              ),
              // Bildirim tercihi — profil gelince (yükleme/hata → gizli, dayanıklı).
              profile.maybeWhen(
                data: (p) => SwitchListTile(
                  key: const Key('notifications-toggle'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Push notifications',
                    style: TextStyle(fontSize: NoctaFontSize.body, color: NoctaColors.inkPrimary),
                  ),
                  value: p.notificationsEnabled,
                  onChanged: _savingNotifications ? null : _setNotifications,
                ),
                orElse: () => const SizedBox.shrink(),
              ),
              const SizedBox(height: NoctaSpace.s5),
              Text(
                'Account security',
                style: TextStyle(fontSize: NoctaFontSize.body, color: NoctaColors.inkSecondary),
              ),
              // Aktif cihaz sayısı — veri gelince (yükleme/hata → gizli).
              sessions.maybeWhen(
                data: (list) => Padding(
                  padding: const EdgeInsets.only(top: NoctaSpace.s2),
                  child: Text(
                    'Active devices: ${list.length}',
                    key: const Key('active-devices'),
                    style: TextStyle(fontSize: NoctaFontSize.body, color: NoctaColors.inkPrimary),
                  ),
                ),
                orElse: () => const SizedBox.shrink(),
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
