import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/design_system/design_system.dart';
import '../../../core/sleep_tracking/smart_alarm.dart';
import '../../../l10n/app_localizations.dart';
import '../sleep_mode_controller.dart';
import '../sleep_session_beacon.dart';
import 'widgets/night_orb.dart';

/// Uyku modu (docs/04 M3) — **mikrofonun gerçekten dinlediği ekran**.
///
/// #128–#132'de uyku takibi mantığı yazıldı ve test edildi ama kullanıcı ona hiç
/// ulaşamıyordu. Burası o kapı.
class SleepModeScreen extends StatefulWidget {
  const SleepModeScreen({
    super.key,
    required this.controller,
    this.micRationale,
    this.onEditAlarm,
  });

  final SleepModeController controller;

  /// Kayıt BAŞLAMADAN önce çalışan gerekçe kapısı (Elegy §13).
  ///
  /// `true` → başla · `false` → başlama (kullanıcı "şimdi değil" dedi).
  /// **Opsiyonel ve varsayılan null:** kapı bir yerleştirme (routing) kararı,
  /// bu ekranın iç mantığı değil. Null olduğunda ekran eskisi gibi doğrudan
  /// başlar — mevcut widget testleri router kurmadan koşmaya devam eder.
  final Future<bool> Function()? micRationale;

  /// Alarm kurulum EKRANINA götürür (Elegy §14). Verilmezse ekran eski
  /// davranışa düşer: sistemin saat diyaloğu. Yerleştirme kararı router'ın.
  final VoidCallback? onEditAlarm;

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
  ///
  /// Elegy: gece ekranında hiçbir şey parlamaz; bölüm mono etiket + ince
  /// çizgiyle ayrılır, kontroller sönük.
  Widget _alarmSection(BuildContext context, AppL10n l10n, SleepModeState s) {
    final at = s.alarmAt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(color: NoctaColors.nightLine),
        const SizedBox(height: NoctaSpace.s4),
        NMono(l10n.alarmSectionTitle, color: NoctaColors.nightFaint),
        const SizedBox(height: NoctaSpace.s2),
        Text(
          at == null ? l10n.alarmOff : l10n.alarmSet(_formatTime(context, at)),
          key: const Key('alarm-status'),
          style: const TextStyle(
            fontFamily: NoctaFont.mono,
            fontSize: NoctaFontSize.caption,
            letterSpacing: NoctaTrack.tight,
            color: NoctaColors.nightInk,
          ),
        ),
        const SizedBox(height: NoctaSpace.s2),
        // Alarmın ne YAPTIĞINI söyler: sezgisel + son tarih garantisi. Kullanıcı
        // "akıllı" kelimesinden uyku evresi ölçtüğümüzü sanmamalı (CLAUDE.md §1.1).
        Text(
          l10n.alarmExplain(widget.controller.alarmWindow.inMinutes),
          key: const Key('alarm-explain'),
          style: const TextStyle(
            fontSize: NoctaFontSize.caption,
            height: 1.6,
            color: NoctaColors.nightFaint,
          ),
        ),
        const SizedBox(height: NoctaSpace.s3),
        Row(
          children: [
            _NightAction(
              key: const Key('alarm-choose'),
              label: l10n.alarmChoose,
              onTap: () => _pickAlarm(context),
              boxed: true,
            ),
            if (at != null) ...[
              const SizedBox(width: NoctaSpace.s3),
              _NightAction(
                key: const Key('alarm-clear'),
                label: l10n.alarmClear,
                onTap: () => widget.controller.setAlarm(null),
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
    // Kurulum ekranı varsa oraya: saat + PENCERE birlikte ayarlanır. Sistemin
    // diyaloğu pencereyi soramaz, yani ürünün farkını gizler.
    final edit = widget.onEditAlarm;
    if (edit != null) {
      edit();
      return;
    }
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

  /// Biçim, kabuk şeridiyle ORTAK (`formatElapsed`): kullanıcı şeritten bu ekrana
  /// geçtiğinde iki farklı biçimde iki sayı görürse hangisine güveneceğini bilemez.
  String _elapsed(DateTime started) =>
      formatElapsed(DateTime.now().difference(started));

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final s = widget.controller.state;

    return Scaffold(
      // Uyku modu bg.base'ten de karanlık: bu ekran gece boyunca AÇIK kalıyor.
      backgroundColor: NoctaColors.bgNight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: NMono(l10n.sleepModeTitle, color: NoctaColors.nightFaint),
      ),
      // İÇERİK kaydırılır, ASIL EYLEM SABİT kalır. Küre + 64px saat + alarm
      // bölümü küçük ekranda sabit `Column`'a sığmıyordu (testte 136px taşma);
      // her şeyi kaydırılabilir yapmak ise başlat/bitir düğmesini ekranın
      // altına itiyordu — yarı uykulu kullanıcının aradığı tek düğme o.
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(NoctaSpace.s6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ÇALIYORSA HER ŞEYİN ÜSTÜNDE ve kaydırma alanının DIŞINDA:
              // kullanıcı yarı uykulu, aradığı tek düğme bu. Kaydırma içinde
              // kalsaydı ekranın altına düşer ve dokunuş alttaki "geceyi bitir"
              // düğmesine giderdi — testte tam olarak bu oldu.
              //
              // Elegy §15: sabahın ilk karesi GÜN DOĞUMU. Gece paletinin tek
              // sıcak anı burası — ekran kullanıcıyı uyandırıyor, artık
              // karartmanın anlamı yok.
              if (s.alarmRinging) ...[
                Container(
                  key: const Key('alarm-ringing'),
                  padding: const EdgeInsets.all(NoctaSpace.s5),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: <Color>[
                        NoctaColors.accentDawn,
                        NoctaColors.bgNight,
                      ],
                    ),
                  ),
                  child: Column(
                    children: [
                      NMono(
                        s.alarmTrigger == AlarmTrigger.lightSleep
                            ? l10n.alarmRingingLightSleep
                            : l10n.alarmRingingDeadline,
                        color: NoctaColors.inkPrimary,
                        track: NoctaTrack.wide,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: NoctaSpace.s5),
                      NButton(
                        key: const Key('alarm-dismiss'),
                        label: l10n.alarmDismiss,
                        onPressed: widget.controller.dismissAlarm,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: NoctaSpace.s4),
              ],
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // "MİKROFON AÇIK" göstergesi GİZLENMEZ (docs/04 §1.3): kullanıcı
                      // gece boyunca mikrofonun açık olduğunu görür.
                      if (s.isRecording)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: NoctaColors.nightInk,
                              ),
                            ),
                            const SizedBox(width: NoctaSpace.s2),
                            NMono(
                              l10n.sleepModeRecording,
                              color: NoctaColors.nightFaint,
                            ),
                          ],
                        ),
                      const SizedBox(height: NoctaSpace.s8),

                      if (s.isRecording && s.startedAt != null)
                        Column(
                          children: [
                            const NightOrb(size: 200),
                            const SizedBox(height: NoctaSpace.s8),
                            // Saat serif ve BÜYÜK ama sönük: yarı uykuluyken okunur,
                            // gözü açmaz.
                            Text(
                              _elapsed(s.startedAt!),
                              key: const Key('sleep-elapsed'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: NoctaFont.display,
                                fontSize: 64,
                                height: 1,
                                color: NoctaColors.nightInk,
                                fontFeatures: <FontFeature>[
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                            const SizedBox(height: NoctaSpace.s4),
                            NMono(
                              l10n.sleepModeEvents(s.eventCount),
                              key: const Key('sleep-event-count'),
                              color: NoctaColors.nightFaint,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),

                      if (s.permissionDenied)
                        _NightNotice(
                          key: const Key('sleep-permission-denied'),
                          text: l10n.sleepModePermissionDenied,
                        ),

                      // Servis başlatılamadı → kayıt BAŞLATILMADI. Bunu izin reddinden ayrı
                      // göstermek şart: biri kullanıcının seçimi, diğeri sistem sorunu.
                      if (s.serviceFailed)
                        _NightNotice(
                          key: const Key('sleep-service-failed'),
                          text: l10n.sleepModeServiceFailed,
                        ),

                      if (s.savedDraft != null) ...[
                        NDisplay(
                          l10n.sleepModeSaved(
                            s.savedDraft!.duration.inHours,
                            s.savedDraft!.duration.inMinutes % 60,
                          ),
                          key: const Key('sleep-saved'),
                          size: NoctaFontSize.h2,
                          color: NoctaColors.nightInk,
                          textAlign: TextAlign.center,
                        ),
                        // Gece zarfı varsa paylaşılabilir (docs/04 §120 fixture'ı).
                        // Otomatik gönderim YOK: veri kullanıcının cihazında üretildi.
                        if (widget.controller.envelope != null) ...[
                          const SizedBox(height: NoctaSpace.s3),
                          Text(
                            l10n.sleepModeExportHint,
                            key: const Key('sleep-export-hint'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: NoctaFontSize.caption,
                              height: 1.6,
                              color: NoctaColors.nightFaint,
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
                          _NightNotice(
                            key: const Key('sleep-save-failed'),
                            text: l10n.sleepModeSaveFailed,
                          ),
                        ],
                      ],

                      _alarmSection(context, l10n, s),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: NoctaSpace.s5),
              // GİZLİLİK: kullanıcı mikrofonu açmadan ÖNCE ne olduğunu bilmeli.
              // Ayarlara gömmek, iznin bilinçli olmasını engellerdi.
              Text(
                l10n.sleepModePrivacy,
                key: const Key('sleep-privacy'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: NoctaFontSize.caption,
                  height: 1.6,
                  color: NoctaColors.nightFaint,
                ),
              ),
              const SizedBox(height: NoctaSpace.s4),
              NButton(
                key: const Key('sleep-toggle'),
                variant: s.isRecording
                    ? NButtonVariant.ghost
                    : NButtonVariant.primary,
                label: s.isRecording ? l10n.sleepModeStop : l10n.sleepModeStart,
                // Karar BASMA ANINDA verilir, build anında değil. `onPressed`i
                // `s.isRecording`e göre seçmek, build ile basış arasında durum
                // değişirse YANLIŞ eylemi çağırırdı — nitekim çağırdı: testte
                // "bitir"e basmak yeniden `start()` tetikledi ve gece kaydedilmedi.
                onPressed: () async {
                  final now = widget.controller.state;
                  if (now.isRecording) {
                    widget.controller.stopAndSave();
                    return;
                  }
                  // Gerekçe kapısı: sistemin izin kutusu bundan SONRA çıkar.
                  final gate = widget.micRationale;
                  if (gate != null && !await gate()) return;
                  widget.controller.start(
                    notificationTitle: l10n.sleepModeNotificationTitle,
                    notificationBody: l10n.sleepModeNotificationBody,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Gece ekranındaki uyarı satırı — kızıl işaret bloğu + sönük metin.
/// Gece paletinde parlak uyarı rengi kullanmıyoruz: kullanıcıyı uyandırmaz.
class _NightNotice extends StatelessWidget {
  const _NightNotice({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: NoctaSpace.s2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 6),
            color: NoctaColors.lineDanger,
          ),
          const SizedBox(width: NoctaSpace.s3),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: NoctaFontSize.caption,
                height: 1.6,
                color: NoctaColors.nightInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Gece ekranının sönük eylemi. `OutlinedButton`/`TextButton` Material'ın
/// kendi renklerini getiriyordu (mor dalgalanma, parlak metin) — gece paletini
/// deliyordu.
class _NightAction extends StatelessWidget {
  const _NightAction({
    super.key,
    required this.label,
    required this.onTap,
    this.boxed = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool boxed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(
            horizontal: NoctaSpace.s4,
            vertical: NoctaSpace.s3,
          ),
          alignment: Alignment.center,
          decoration: boxed
              ? const BoxDecoration(
                  border: Border.fromBorderSide(
                    BorderSide(color: NoctaColors.nightLine),
                  ),
                )
              : null,
          child: NMono(label, color: NoctaColors.nightInk, height: 1),
        ),
      ),
    );
  }
}
