import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/auth_providers.dart';
import '../../entitlement/entitlement_providers.dart';
import '../../profile/profile_providers.dart';
import '../locale_store.dart';
import '../signature_sound_store.dart';

/// Ayarlar (docs/06 hesap güvenliği). "Diğer cihazlardan çık" akışı.
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
    final l10n = AppL10n.of(context); // await'ten ONCE (context async gap)
    try {
      await ref.read(profileControllerProvider).setNotificationsEnabled(enabled);
      ref.invalidate(profileProvider); // switch güncel sunucu değerini yansıtır
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.settingsNotificationsUpdateFailed)),
      );
    } finally {
      if (mounted) setState(() => _savingNotifications = false);
    }
  }

  Future<void> _revokeOthers() async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppL10n.of(context); // await'ten ONCE (context async gap)
    try {
      final revoked = await ref.read(authControllerProvider).revokeOtherSessions();
      ref.invalidate(activeSessionsProvider); // liste güncellenir
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.settingsDevicesSignedOut(revoked))),
      );
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.settingsSignOutOthersFailed)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final sessions = ref.watch(activeSessionsProvider);
    final profile = ref.watch(profileProvider);
    final entitlement = ref.watch(entitlementProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(NoctaSpace.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Üyelik — premium durumu sunucudan (docs/02 §183). Premium özellikler
              // eklendiğinde bu bayrak üzerinden gate edilir; şu an durum göstergesi.
              Text(
                l10n.settingsMembershipSection,
                style: TextStyle(fontSize: NoctaFontSize.body, color: NoctaColors.inkSecondary),
              ),
              entitlement.maybeWhen(
                data: (e) => Padding(
                  padding: const EdgeInsets.only(top: NoctaSpace.s2),
                  child: Text(
                    e.premium ? l10n.membershipPremium : l10n.membershipFree,
                    key: const Key('membership-status'),
                    style: TextStyle(fontSize: NoctaFontSize.body, color: NoctaColors.inkPrimary),
                  ),
                ),
                // Yükleme/hata → gizli (dayanıklı; ayarlar ekranı bloke olmaz).
                orElse: () => const SizedBox.shrink(),
              ),
              const SizedBox(height: NoctaSpace.s5),
              Text(
                l10n.settingsNotificationsSection,
                style: TextStyle(fontSize: NoctaFontSize.body, color: NoctaColors.inkSecondary),
              ),
              // Bildirim tercihi — profil gelince (yükleme/hata → gizli, dayanıklı).
              profile.maybeWhen(
                data: (p) => SwitchListTile(
                  key: const Key('notifications-toggle'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    l10n.settingsPushNotifications,
                    style: TextStyle(fontSize: NoctaFontSize.body, color: NoctaColors.inkPrimary),
                  ),
                  value: p.notificationsEnabled,
                  onChanged: _savingNotifications ? null : _setNotifications,
                ),
                orElse: () => const SizedBox.shrink(),
              ),
              const SizedBox(height: NoctaSpace.s5),
              Text(
                l10n.settingsLanguageSection,
                style: TextStyle(fontSize: NoctaFontSize.body, color: NoctaColors.inkSecondary),
              ),
              // DİL SEÇİCİ: çeviriler baştan beri tamdı ama yalnızca cihaz diline
              // uyuluyordu — yani var olan bir yetenek erişilemezdi. Sistem/EN/TR.
              ref.watch(appLocaleProvider).maybeWhen(
                data: (current) => Column(
                  children: <Widget>[
                    for (final option in <(Locale?, String)>[
                      (null, l10n.settingsLanguageSystem),
                      (const Locale('en'), l10n.settingsLanguageEnglish),
                      (const Locale('tr'), l10n.settingsLanguageTurkish),
                    ])
                      ListTile(
                        key: Key('locale-${option.$1?.languageCode ?? 'system'}'),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(
                          option.$2,
                          style: TextStyle(
                            fontSize: NoctaFontSize.body,
                            color: NoctaColors.inkPrimary,
                          ),
                        ),
                        trailing:
                            (current?.languageCode ?? 'system') ==
                                (option.$1?.languageCode ?? 'system')
                            ? Icon(Icons.check, color: NoctaColors.accentAurora)
                            : null,
                        onTap: () async {
                          await ref.read(localeStoreProvider).write(option.$1);
                          ref.invalidate(appLocaleProvider);
                        },
                      ),
                  ],
                ),
                orElse: () => const SizedBox.shrink(),
              ),
              const SizedBox(height: NoctaSpace.s5),
              Text(
                l10n.settingsSoundSection,
                style: TextStyle(fontSize: NoctaFontSize.body, color: NoctaColors.inkSecondary),
              ),
              // AÇILIŞ SESİ (aura) — kapatılabilir olması ZORUNLU: bu bir uyku
              // uygulaması ve ses gece 23:00'te, yanında biri uyurken çalabilir.
              // KENDİ bölümünde: "Notifications" altında görünmesi yanlıştı (bildirim
              // toggle'ı çevrimdışıyken gizlenince ses ayarı bildirim gibi okunuyordu).
              ref.watch(signatureSoundEnabledProvider).maybeWhen(
                data: (enabled) => SwitchListTile(
                  key: const Key('signature-sound-toggle'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    l10n.settingsSignatureSound,
                    style: TextStyle(fontSize: NoctaFontSize.body, color: NoctaColors.inkPrimary),
                  ),
                  subtitle: Text(
                    l10n.settingsSignatureSoundHint,
                    style: TextStyle(fontSize: NoctaFontSize.caption, color: NoctaColors.inkSecondary),
                  ),
                  value: enabled,
                  onChanged: (v) async {
                    await ref.read(signatureSoundStoreProvider).setEnabled(v);
                    ref.invalidate(signatureSoundEnabledProvider);
                  },
                ),
                orElse: () => const SizedBox.shrink(),
              ),
              const SizedBox(height: NoctaSpace.s5),
              Text(
                l10n.settingsAccountSecuritySection,
                style: TextStyle(fontSize: NoctaFontSize.body, color: NoctaColors.inkSecondary),
              ),
              // Aktif cihaz sayısı — veri gelince (yükleme/hata → gizli).
              sessions.maybeWhen(
                data: (list) => Padding(
                  padding: const EdgeInsets.only(top: NoctaSpace.s2),
                  child: Text(
                    l10n.settingsActiveDevices(list.length),
                    key: const Key('active-devices'),
                    style: TextStyle(fontSize: NoctaFontSize.body, color: NoctaColors.inkPrimary),
                  ),
                ),
                orElse: () => const SizedBox.shrink(),
              ),
              const SizedBox(height: NoctaSpace.s3),
              NButton(
                key: const Key('revoke-others'),
                label: _busy ? l10n.settingsSigningOut : l10n.settingsLogOutOthers,
                onPressed: _busy ? null : _revokeOthers,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
