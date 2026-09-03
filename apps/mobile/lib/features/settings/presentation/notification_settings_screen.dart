import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';
import '../../profile/profile_models.dart';
import '../../profile/profile_providers.dart';

/// **Bildirim ayarları** (Elegy §22) — akşam hatırlatıcısı + sessiz saatler.
///
/// **Neden ayrı ekran:** ayarlardaki tek anahtar yalnızca "bildirim var/yok"
/// diyordu. Alışkanlık döngüsünün çalışması için hatırlatıcının NE ZAMAN
/// geleceği kullanıcının kararı olmalı — 23:00'te uyuyan biriyle 01:00'de
/// uyuyan birine aynı saatte dürtme göndermek, ikisinden birini rahatsız eder.
///
/// **Saat KULLANICININ YEREL saati** (sunucu da öyle saklıyor): "23:00'te
/// hatırlat" duvar saatidir; UTC'de saklansaydı seyahatte ve yaz saatinde
/// kayardı.
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  bool _busy = false;

  Future<void> _save(Future<Profile> Function() write) async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppL10n.of(context); // await'ten ÖNCE (context async gap)
    try {
      await write();
      ref.invalidate(profileProvider);
    } catch (_) {
      // "Ayarların değişmedi" bilinçli: PATCH patladıysa sunucuda hiçbir şey
      // değişmedi. Belirsiz bir hata, kullanıcıyı ayarı tekrar tekrar
      // değiştirmeye iterdi.
      messenger.showSnackBar(SnackBar(content: Text(l10n.notifSaveFailed)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<int?> _pickHour(BuildContext context, int? current) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ?? 22, minute: 0),
      // Dakika sormuyoruz: hatırlatıcı SAAT hassasiyetinde (sunucu da öyle
      // saklıyor). Dakika sorup yok saymak, tutmayacağımız bir söz olurdu.
      helpText: '',
    );
    return picked?.hour;
  }

  String _hourLabel(BuildContext context, int hour) =>
      TimeOfDay(hour: hour, minute: 0).format(context);

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final profile = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(title: NMono(l10n.notifSettingsTitle)),
      body: SafeArea(
        child: profile.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => NErrorState(
            retryKey: const Key('notif-retry'),
            message: l10n.loadFailed,
            retryLabel: l10n.offlineRetry,
            onRetry: () => ref.invalidate(profileProvider),
          ),
          data: (p) => SingleChildScrollView(
            padding: const EdgeInsets.all(NoctaSpace.s6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                NDisplay(l10n.notifSettingsTitle, size: NoctaFontSize.h1),
                const SizedBox(height: NoctaSpace.s8),

                // ── AKŞAM HATIRLATICISI ──
                NMono(l10n.notifReminderSection, track: NoctaTrack.wide),
                const SizedBox(height: NoctaSpace.s3),
                NDisplay(
                  p.reminderHour == null
                      ? l10n.notifReminderOff
                      : l10n.notifReminderAt(
                          _hourLabel(context, p.reminderHour!),
                        ),
                  key: const Key('notif-reminder-value'),
                  size: NoctaFontSize.h2,
                ),
                const SizedBox(height: NoctaSpace.s2),
                Text(
                  l10n.notifReminderHint,
                  style: const TextStyle(
                    fontSize: NoctaFontSize.caption,
                    height: 1.6,
                    color: NoctaColors.inkSecondary,
                  ),
                ),
                const SizedBox(height: NoctaSpace.s4),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: NButton(
                        key: const Key('notif-reminder-pick'),
                        label: l10n.notifPick,
                        variant: NButtonVariant.ghost,
                        onPressed: _busy
                            ? null
                            : () async {
                                final hour = await _pickHour(
                                  context,
                                  p.reminderHour,
                                );
                                if (hour == null) return;
                                await _save(
                                  () => ref
                                      .read(profileControllerProvider)
                                      .setReminder(hour: hour),
                                );
                              },
                      ),
                    ),
                    if (p.reminderHour != null) ...<Widget>[
                      const SizedBox(width: NoctaSpace.s3),
                      Expanded(
                        child: NButton(
                          key: const Key('notif-reminder-clear'),
                          label: l10n.notifClear,
                          variant: NButtonVariant.ghost,
                          onPressed: _busy
                              ? null
                              : () => _save(
                                  () => ref
                                      .read(profileControllerProvider)
                                      .setReminder(clearReminder: true),
                                ),
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: NoctaSpace.s8),
                const Divider(color: NoctaColors.lineHairline),
                const SizedBox(height: NoctaSpace.s5),

                // ── SESSİZ SAATLER ──
                NMono(l10n.notifQuietSection, track: NoctaTrack.wide),
                const SizedBox(height: NoctaSpace.s3),
                NDisplay(
                  p.quietHoursStart == null || p.quietHoursEnd == null
                      ? l10n.notifQuietOff
                      : l10n.notifQuietRange(
                          _hourLabel(context, p.quietHoursStart!),
                          _hourLabel(context, p.quietHoursEnd!),
                        ),
                  key: const Key('notif-quiet-value'),
                  size: NoctaFontSize.h2,
                ),
                const SizedBox(height: NoctaSpace.s2),
                Text(
                  l10n.notifQuietHint,
                  style: const TextStyle(
                    fontSize: NoctaFontSize.caption,
                    height: 1.6,
                    color: NoctaColors.inkSecondary,
                  ),
                ),
                const SizedBox(height: NoctaSpace.s4),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: NButton(
                        key: const Key('notif-quiet-pick'),
                        label: l10n.notifPick,
                        variant: NButtonVariant.ghost,
                        onPressed: _busy
                            ? null
                            : () async {
                                // İKİ saat de alınmadan HİÇBİR ŞEY yazılmaz:
                                // yarım bir aralık (başlangıç var, bitiş yok)
                                // sunucuda anlamsız bir sessizlik penceresi
                                // olurdu.
                                final start = await _pickHour(
                                  context,
                                  p.quietHoursStart,
                                );
                                if (start == null || !context.mounted) return;
                                final end = await _pickHour(
                                  context,
                                  p.quietHoursEnd,
                                );
                                if (end == null) return;
                                await _save(
                                  () => ref
                                      .read(profileControllerProvider)
                                      .setReminder(
                                        quietStart: start,
                                        quietEnd: end,
                                      ),
                                );
                              },
                      ),
                    ),
                    if (p.quietHoursStart != null) ...<Widget>[
                      const SizedBox(width: NoctaSpace.s3),
                      Expanded(
                        child: NButton(
                          key: const Key('notif-quiet-clear'),
                          label: l10n.notifClear,
                          variant: NButtonVariant.ghost,
                          onPressed: _busy
                              ? null
                              : () => _save(
                                  () => ref
                                      .read(profileControllerProvider)
                                      .setReminder(clearQuietHours: true),
                                ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: NoctaSpace.s8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
