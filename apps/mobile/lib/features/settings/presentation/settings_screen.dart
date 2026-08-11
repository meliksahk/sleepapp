import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/design_system/design_system.dart';
import '../../../core/share/sharer.dart';
import '../../../l10n/app_localizations.dart';
import '../../archetype/archetype_providers.dart' show sharerProvider;
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
  bool _exporting = false;

  /// Verilerimi indir — `GET /v1/me/export` (GDPR taşınabilirliği).
  ///
  /// Dosya SUNUCUYA geri gönderilmez, cihazın paylaşım sayfasına verilir:
  /// kullanıcı nereye kaydedeceğine kendi karar verir. Otomatik hiçbir yere
  /// yazmıyoruz — kişisel verinin varış yerini seçmek kullanıcının hakkı.
  Future<void> _exportData() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppL10n.of(context); // await'ten ÖNCE (context async gap)
    try {
      final json = await ref.read(authControllerProvider).exportData();
      await ref
          .read(sharerProvider)
          .share(
            ShareContent(
              text: l10n.privacyExportHint,
              url: '',
              file: ShareFile.json(
                text: json,
                filename: 'nocta-data-export.json',
              ),
            ),
          );
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.privacyExportFailed)));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  /// Bildirim toggle'ı: optimistic değil — PATCH sonucunu bekleyip provider'ı
  /// tazeler; hata olursa switch eski değerinde kalır (kullanıcıya snackbar).
  Future<void> _setNotifications(bool enabled) async {
    if (_savingNotifications) return;
    setState(() => _savingNotifications = true);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppL10n.of(context); // await'ten ONCE (context async gap)
    try {
      await ref
          .read(profileControllerProvider)
          .setNotificationsEnabled(enabled);
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
      final revoked = await ref
          .read(authControllerProvider)
          .revokeOtherSessions();
      ref.invalidate(activeSessionsProvider); // liste güncellenir
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.settingsDevicesSignedOut(revoked))),
      );
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.settingsSignOutOthersFailed)),
      );
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
      appBar: AppBar(title: NMono(l10n.settingsTitle)),
      body: SafeArea(
        // KAYDIRILABILIR: bes bolum kucuk ekranda sabit Column'a sigmiyor.
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(NoctaSpace.s6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              NDisplay(l10n.settingsTitle, size: NoctaFontSize.h1),
              const SizedBox(height: NoctaSpace.s6),
              // Üyelik — premium durumu sunucudan (docs/02 §183). Premium özellikler
              // eklendiğinde bu bayrak üzerinden gate edilir; şu an durum göstergesi.
              const Divider(color: NoctaColors.lineHairline),
              const SizedBox(height: NoctaSpace.s3),
              NMono(l10n.settingsMembershipSection, track: NoctaTrack.wide),
              entitlement.maybeWhen(
                data: (e) => Padding(
                  padding: const EdgeInsets.only(top: NoctaSpace.s2),
                  child: NDisplay(
                    e.premium ? l10n.membershipPremium : l10n.membershipFree,
                    key: const Key('membership-status'),
                    size: NoctaFontSize.h2,
                  ),
                ),
                // Yükleme/hata → gizli (dayanıklı; ayarlar ekranı bloke olmaz).
                orElse: () => const SizedBox.shrink(),
              ),
              const SizedBox(height: NoctaSpace.s5),
              const Divider(color: NoctaColors.lineHairline),
              const SizedBox(height: NoctaSpace.s3),
              NMono(l10n.settingsNotificationsSection, track: NoctaTrack.wide),
              // Bildirim tercihi — profil gelince (yükleme/hata → gizli, dayanıklı).
              profile.maybeWhen(
                data: (p) => SwitchListTile(
                  key: const Key('notifications-toggle'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    l10n.settingsPushNotifications,
                    style: const TextStyle(
                      fontSize: NoctaFontSize.body,
                      color: NoctaColors.inkPrimary,
                    ),
                  ),
                  activeThumbColor: NoctaColors.bgPaper,
                  activeTrackColor: NoctaColors.accentAurora,
                  value: p.notificationsEnabled,
                  onChanged: _savingNotifications ? null : _setNotifications,
                ),
                orElse: () => const SizedBox.shrink(),
              ),
              // Hatırlatıcı saati ve sessiz saatler KENDİ ekranında (F3):
              // buradaki anahtar yalnızca "bildirim var/yok" diyor.
              const SizedBox(height: NoctaSpace.s3),
              NButton(
                key: const Key('notif-settings-open'),
                // Bolum basligi zaten "Bildirimler" — dugme de oyle olunca
                // ekranda "Bildirimler / Bildirimler" tekrari cikiyordu.
                // Dugme ARDINDAKI seyi soyler.
                label: l10n.settingsNotificationsOpen,
                variant: NButtonVariant.ghost,
                onPressed: () => context.push('/settings/notifications'),
              ),

              const SizedBox(height: NoctaSpace.s5),
              const Divider(color: NoctaColors.lineHairline),
              const SizedBox(height: NoctaSpace.s3),
              NMono(l10n.settingsLanguageSection, track: NoctaTrack.wide),
              // DİL SEÇİCİ: çeviriler baştan beri tamdı ama yalnızca cihaz diline
              // uyuluyordu — yani var olan bir yetenek erişilemezdi. Sistem/EN/TR.
              ref
                  .watch(appLocaleProvider)
                  .maybeWhen(
                    data: (current) => Column(
                      children: <Widget>[
                        for (final option in <(Locale?, String)>[
                          (null, l10n.settingsLanguageSystem),
                          (const Locale('en'), l10n.settingsLanguageEnglish),
                          (const Locale('tr'), l10n.settingsLanguageTurkish),
                        ])
                          ListTile(
                            key: Key(
                              'locale-${option.$1?.languageCode ?? 'system'}',
                            ),
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text(
                              option.$2,
                              style: const TextStyle(
                                fontSize: NoctaFontSize.body,
                                color: NoctaColors.inkPrimary,
                              ),
                            ),
                            // Elegy'de tik ikonu yok: secili dil KIZIL BLOKla isaretlenir.
                            // Renk tek basina tasiyici degil, sekil de degisiyor
                            // (yok -> var), CLAUDE.md §7.
                            trailing:
                                (current?.languageCode ?? 'system') ==
                                    (option.$1?.languageCode ?? 'system')
                                ? Container(
                                    width: 18,
                                    height: 8,
                                    color: NoctaColors.accentAurora,
                                  )
                                : null,
                            onTap: () async {
                              await ref
                                  .read(localeStoreProvider)
                                  .write(option.$1);
                              ref.invalidate(appLocaleProvider);
                            },
                          ),
                      ],
                    ),
                    orElse: () => const SizedBox.shrink(),
                  ),
              const SizedBox(height: NoctaSpace.s5),
              const Divider(color: NoctaColors.lineHairline),
              const SizedBox(height: NoctaSpace.s3),
              NMono(l10n.settingsSoundSection, track: NoctaTrack.wide),
              // AÇILIŞ SESİ (aura) — kapatılabilir olması ZORUNLU: bu bir uyku
              // uygulaması ve ses gece 23:00'te, yanında biri uyurken çalabilir.
              // KENDİ bölümünde: "Notifications" altında görünmesi yanlıştı (bildirim
              // toggle'ı çevrimdışıyken gizlenince ses ayarı bildirim gibi okunuyordu).
              ref
                  .watch(signatureSoundEnabledProvider)
                  .maybeWhen(
                    data: (enabled) => SwitchListTile(
                      key: const Key('signature-sound-toggle'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        l10n.settingsSignatureSound,
                        style: const TextStyle(
                          fontSize: NoctaFontSize.body,
                          color: NoctaColors.inkPrimary,
                        ),
                      ),
                      subtitle: Text(
                        l10n.settingsSignatureSoundHint,
                        style: const TextStyle(
                          fontSize: NoctaFontSize.caption,
                          height: 1.5,
                          color: NoctaColors.inkSecondary,
                        ),
                      ),
                      activeThumbColor: NoctaColors.bgPaper,
                      activeTrackColor: NoctaColors.accentAurora,
                      value: enabled,
                      onChanged: (v) async {
                        await ref
                            .read(signatureSoundStoreProvider)
                            .setEnabled(v);
                        ref.invalidate(signatureSoundEnabledProvider);
                      },
                    ),
                    orElse: () => const SizedBox.shrink(),
                  ),
              const SizedBox(height: NoctaSpace.s5),
              const Divider(color: NoctaColors.lineHairline),
              const SizedBox(height: NoctaSpace.s3),
              NMono(
                l10n.settingsAccountSecuritySection,
                track: NoctaTrack.wide,
              ),
              // Aktif cihaz sayısı — veri gelince (yükleme/hata → gizli).
              sessions.maybeWhen(
                data: (list) => Padding(
                  padding: const EdgeInsets.only(top: NoctaSpace.s2),
                  child: Text(
                    l10n.settingsActiveDevices(list.length),
                    key: const Key('active-devices'),
                    style: const TextStyle(
                      fontSize: NoctaFontSize.body,
                      color: NoctaColors.inkPrimary,
                    ),
                  ),
                ),
                orElse: () => const SizedBox.shrink(),
              ),
              const SizedBox(height: NoctaSpace.s3),
              NButton(
                key: const Key('revoke-others'),
                label: _busy
                    ? l10n.settingsSigningOut
                    : l10n.settingsLogOutOthers,
                variant: NButtonVariant.ghost,
                onPressed: _busy ? null : _revokeOthers,
              ),

              // ── GİZLİLİK ──────────────────────────────────────────────────
              // İki uç da sunucuda AYLARDIR hazırdı (`GET /v1/me/export`,
              // `DELETE /v1/auth/me`) ve uygulamada düğmesi yoktu. App Store,
              // hesap açan her uygulamada uygulama-içi silmeyi şart koşuyor;
              // yani bu bölüm bir cila değil, gönderim önkoşuluydu.
              const SizedBox(height: NoctaSpace.s5),
              const Divider(color: NoctaColors.lineHairline),
              const SizedBox(height: NoctaSpace.s3),
              NMono(l10n.privacySection, track: NoctaTrack.wide),
              const SizedBox(height: NoctaSpace.s3),
              Text(
                l10n.privacyExportHint,
                style: const TextStyle(
                  fontSize: NoctaFontSize.caption,
                  height: 1.6,
                  color: NoctaColors.inkSecondary,
                ),
              ),
              const SizedBox(height: NoctaSpace.s3),
              NButton(
                key: const Key('privacy-export'),
                label: _exporting ? l10n.privacyExporting : l10n.privacyExport,
                variant: NButtonVariant.ghost,
                onPressed: _exporting ? null : _exportData,
              ),
              const SizedBox(height: NoctaSpace.s3),
              NButton(
                key: const Key('privacy-delete-account'),
                label: l10n.privacyDeleteEntry,
                variant: NButtonVariant.ghost,
                onPressed: () => context.push('/settings/delete-account'),
              ),
              const SizedBox(height: NoctaSpace.s8),
            ],
          ),
        ),
      ),
    );
  }
}
