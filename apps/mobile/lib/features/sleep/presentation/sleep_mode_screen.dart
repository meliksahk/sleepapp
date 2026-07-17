import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/design_system/design_system.dart';
import '../../../core/sleep_tracking/smart_alarm.dart';
import '../../../l10n/app_localizations.dart';
import '../sleep_mode_controller.dart';

/// Uyku modu (docs/04 M3) — **mikrofonun gerçekten dinlediği ekran**.
///
/// #128–#132'de uyku takibi mantığı yazıldı ve test edildi ama kullanıcı ona hiç
/// ulaşamıyordu. Burası o kapı.
class SleepModeScreen extends StatefulWidget {
  const SleepModeScreen({super.key, required this.controller});

  final SleepModeController controller;

  @override
  State<SleepModeScreen> createState() => _SleepModeScreenState();
}

class _SleepModeScreenState extends State<SleepModeScreen> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    widget.controller.onChanged = () {
      if (mounted) setState(() {});
    };
    // Geçen süre saniyede bir tazelenir; olay sayacı zaten controller'dan gelir.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && widget.controller.state.isRecording) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    widget.controller.onChanged = null;
    super.dispose();
  }

  /// Alarm kurma bölümü — **opt-in**, varsayılan kapalı.
  Widget _alarmSection(BuildContext context, AppL10n l10n, SleepModeState s) {
    final at = s.alarmAt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.alarmSectionTitle, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          at == null ? l10n.alarmOff : l10n.alarmSet(_formatTime(context, at)),
          key: const Key('alarm-status'),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 4),
        // Alarmın ne YAPTIĞINI söyler: sezgisel + son tarih garantisi. Kullanıcı
        // "akıllı" kelimesinden uyku evresi ölçtüğümüzü sanmamalı (CLAUDE.md §1.1).
        Text(
          l10n.alarmExplain(widget.controller.alarmWindow.inMinutes),
          key: const Key('alarm-explain'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            OutlinedButton(
              key: const Key('alarm-choose'),
              onPressed: () => _pickAlarm(context),
              child: Text(l10n.alarmChoose),
            ),
            if (at != null) ...[
              const SizedBox(width: 12),
              TextButton(
                key: const Key('alarm-clear'),
                onPressed: () => widget.controller.setAlarm(null),
                child: Text(l10n.alarmClear),
              ),
            ],
          ],
        ),
      ],
    );
  }

  String _formatTime(BuildContext context, DateTime at) =>
      TimeOfDay.fromDateTime(at).format(context);

  Future<void> _pickAlarm(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 8))),
    );
    if (picked == null || !context.mounted) return;

    var at = DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
    // Seçilen saat GEÇMİŞSE yarın demektir — "07:00" diyen biri sabahı kastediyor,
    // 11 saat öncesini değil. Kırpmasaydık alarm anında (son tarih geçmiş) çalardı.
    if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
    widget.controller.setAlarm(at);
  }

  String _elapsed(DateTime started) {
    final d = DateTime.now().difference(started);
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final s = widget.controller.state;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.sleepModeTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(NoctaSpace.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // GİZLİLİK ÖNDE: kullanıcı mikrofonu açmadan ÖNCE ne olduğunu bilmeli.
              // Bunu ayarlara gömmek, iznin bilinçli olmasını engellerdi.
              Text(
                l10n.sleepModePrivacy,
                key: const Key('sleep-privacy'),
                style: TextStyle(
                  fontSize: NoctaFontSize.caption,
                  color: NoctaColors.inkSecondary,
                ),
              ),
              const Spacer(),

              if (s.isRecording && s.startedAt != null)
                Column(
                  children: [
                    Text(
                      _elapsed(s.startedAt!),
                      key: const Key('sleep-elapsed'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: NoctaFontSize.display,
                        color: NoctaColors.inkPrimary,
                      ),
                    ),
                    const SizedBox(height: NoctaSpace.s2),
                    Text(
                      l10n.sleepModeRecording,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: NoctaColors.accentAurora),
                    ),
                    const SizedBox(height: NoctaSpace.s3),
                    Text(
                      l10n.sleepModeEvents(s.eventCount),
                      key: const Key('sleep-event-count'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: NoctaColors.inkSecondary),
                    ),
                  ],
                ),

              if (s.permissionDenied)
                Text(
                  l10n.sleepModePermissionDenied,
                  key: const Key('sleep-permission-denied'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: NoctaColors.accentDawn),
                ),

              // Servis başlatılamadı → kayıt BAŞLATILMADI. Bunu izin reddinden ayrı
              // göstermek şart: biri kullanıcının seçimi, diğeri sistem sorunu.
              if (s.serviceFailed)
                Text(
                  l10n.sleepModeServiceFailed,
                  key: const Key('sleep-service-failed'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: NoctaColors.accentDawn),
                ),

              if (s.savedDraft != null) ...[
                Text(
                  l10n.sleepModeSaved(
                    s.savedDraft!.duration.inHours,
                    s.savedDraft!.duration.inMinutes % 60,
                  ),
                  key: const Key('sleep-saved'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: NoctaFontSize.h2,
                    color: NoctaColors.inkPrimary,
                  ),
                ),
                // Gece zarfı varsa paylaşılabilir (docs/04 §120 fixture'ı).
                // Otomatik gönderim YOK: veri kullanıcının cihazında üretildi.
                if (widget.controller.envelope != null) ...[
                  const SizedBox(height: NoctaSpace.s3),
                  Text(
                    l10n.sleepModeExportHint,
                    key: const Key('sleep-export-hint'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: NoctaFontSize.caption,
                      color: NoctaColors.inkFaint,
                    ),
                  ),
                  const SizedBox(height: NoctaSpace.s2),
                  NButton(
                    key: const Key('sleep-export'),
                    label: l10n.sleepModeExportEnvelope,
                    variant: NButtonVariant.ghost,
                    onPressed: () => widget.controller.shareEnvelope(
                      text: l10n.sleepModeExportHint,
                    ),
                  ),
                ],
                if (s.error != null) ...[
                  const SizedBox(height: NoctaSpace.s2),
                  // Gece YOK SAYILMAZ: veri cihazda üretildi, yalnızca sunucuya
                  // yazılamadı. Kullanıcıya bunu ayırt ettirmek dürüstlük.
                  Text(
                    l10n.sleepModeSaveFailed,
                    key: const Key('sleep-save-failed'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: NoctaFontSize.caption,
                      color: NoctaColors.accentDawn,
                    ),
                  ),
                ],
              ],

              // ÇALIYORSA her şeyin üstünde: kullanıcı yarı uykulu, aradığı tek
              // düğme bu. Aşağıda bir yerde olsaydı telefonu kurcalardı.
              if (s.alarmRinging) ...[
                Card(
                  key: const Key('alarm-ringing'),
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          s.alarmTrigger == AlarmTrigger.lightSleep
                              ? l10n.alarmRingingLightSleep
                              : l10n.alarmRingingDeadline,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        NButton(
                          key: const Key('alarm-dismiss'),
                          label: l10n.alarmDismiss,
                          onPressed: widget.controller.dismissAlarm,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              _alarmSection(context, l10n, s),

              const Spacer(),
              NButton(
                key: const Key('sleep-toggle'),
                label: s.isRecording ? l10n.sleepModeStop : l10n.sleepModeStart,
                // Karar BASMA ANINDA verilir, build anında değil. `onPressed`i
                // `s.isRecording`e göre seçmek, build ile basış arasında durum
                // değişirse YANLIŞ eylemi çağırırdı — nitekim çağırdı: testte
                // "bitir"e basmak yeniden `start()` tetikledi ve gece kaydedilmedi.
                onPressed: () {
                  final now = widget.controller.state;
                  if (now.isRecording) {
                    widget.controller.stopAndSave();
                  } else {
                    widget.controller.start(
                      notificationTitle: l10n.sleepModeNotificationTitle,
                      notificationBody: l10n.sleepModeNotificationBody,
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
