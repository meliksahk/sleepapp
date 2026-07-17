import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/design_system/design_system.dart';
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
                    widget.controller.start();
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
