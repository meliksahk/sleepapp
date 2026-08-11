import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';
import '../sleep_mode_controller.dart';

/// **Akıllı alarm kurulumu** (Elegy §14).
///
/// **Neden kendi ekranı:** alarm daha önce sistemin `showTimePicker` diyaloğuydu.
/// O diyalog yalnızca SAAT sorar — oysa buradaki alarmın asıl ayarı *pencere*:
/// "en geç 07:00, ama 06:30'dan sonra hafif uykuda yakalarsan daha erken kaldır".
/// Pencereyi soramayan bir kontrol, ürünün farkını gizliyordu.
///
/// **Gün doğumu rampası burada YOK.** Tasarımda bir anahtar var ama motorda
/// karşılığı yok (`SunriseAlarmSound` her zaman açık). Çalışmayan bir anahtar
/// çizmek, olmayan bir özelliği varmış gibi göstermek olurdu — F2'nin kalan işi.
class AlarmSetupScreen extends StatefulWidget {
  const AlarmSetupScreen({super.key, required this.controller});

  final SleepModeController controller;

  @override
  State<AlarmSetupScreen> createState() => _AlarmSetupScreenState();
}

class _AlarmSetupScreenState extends State<AlarmSetupScreen> {
  DateTime? _at;
  late Duration _window = widget.controller.alarmWindow;

  /// Pencere sınırları: 10 dk'nın altı hafif uyku yakalamaya yetmez, 60 dk'nın
  /// üstü "istediğimden bir saat erken kalktım" demektir.
  static const int _minWindow = 10;
  static const int _maxWindow = 60;

  @override
  void initState() {
    super.initState();
    _at = widget.controller.state.alarmAt;
  }

  Future<void> _pickTime() async {
    final now = DateTime.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        _at ?? now.add(const Duration(hours: 8)),
      ),
    );
    if (picked == null) return;
    var at = DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
    // Seçilen saat GEÇMİŞSE yarın demektir (uyku modu ekranındaki kararla aynı).
    if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
    setState(() => _at = at);
  }

  void _save() {
    widget.controller.setAlarmWindow(_window);
    widget.controller.setAlarm(_at);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final at = _at;
    return Scaffold(
      backgroundColor: NoctaColors.bgNight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: NMono(l10n.alarmSectionTitle, color: NoctaColors.nightFaint),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(NoctaSpace.s6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const SizedBox(height: NoctaSpace.s6),
                      // Saatin kendisi bir DÜĞME: ekranın en büyük ögesi zaten o,
                      // ayrı bir "saati değiştir" butonu fazlalık olurdu.
                      Center(
                        child: GestureDetector(
                          key: const Key('alarm-setup-time'),
                          onTap: _pickTime,
                          behavior: HitTestBehavior.opaque,
                          child: Column(
                            children: <Widget>[
                              Text(
                                at == null
                                    ? '--:--'
                                    : TimeOfDay.fromDateTime(at).format(context),
                                style: const TextStyle(
                                  fontFamily: NoctaFont.display,
                                  fontSize: 62,
                                  height: 1,
                                  color: NoctaColors.inkPrimary,
                                  fontFeatures: <FontFeature>[
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                              const SizedBox(height: NoctaSpace.s3),
                              NMono(l10n.alarmLatestAt, track: NoctaTrack.wide),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: NoctaSpace.s8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          NMono(l10n.alarmWindowWidth),
                          NMono(
                            l10n.alarmWindowMinutes(_window.inMinutes),
                            key: const Key('alarm-setup-window-value'),
                            color: NoctaColors.inkPrimary,
                          ),
                        ],
                      ),
                      const SizedBox(height: NoctaSpace.s3),
                      SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 30,
                          activeTrackColor: NoctaColors.bgPaper,
                          inactiveTrackColor: NoctaColors.bgRaised,
                          thumbColor: NoctaColors.accentAurora,
                          overlayColor: NoctaColors.accentAurora.withValues(
                            alpha: 0.12,
                          ),
                          trackShape: const RectangularSliderTrackShape(),
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 8,
                          ),
                          tickMarkShape: SliderTickMarkShape.noTickMark,
                        ),
                        child: Slider(
                          key: const Key('alarm-setup-window'),
                          value: _window.inMinutes.toDouble(),
                          min: _minWindow.toDouble(),
                          max: _maxWindow.toDouble(),
                          divisions: (_maxWindow - _minWindow) ~/ 5,
                          label: l10n.alarmWindowMinutes(_window.inMinutes),
                          onChanged: (v) => setState(
                            () => _window = Duration(minutes: v.round()),
                          ),
                        ),
                      ),
                      const SizedBox(height: NoctaSpace.s5),
                      // Alarmın ne YAPTIĞINI söyler — "akıllı" kelimesi uyku
                      // evresi ölçtüğümüz izlenimi vermemeli (CLAUDE.md §1.1).
                      Text(
                        l10n.alarmExplain(_window.inMinutes),
                        key: const Key('alarm-setup-explain'),
                        style: const TextStyle(
                          fontSize: NoctaFontSize.caption,
                          height: 1.7,
                          color: NoctaColors.nightInk,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: NoctaSpace.s5),
              NButton(
                key: const Key('alarm-setup-save'),
                label: l10n.alarmSave,
                expand: true,
                rule: true,
                onPressed: at == null ? null : _save,
              ),
              const SizedBox(height: NoctaSpace.s3),
              NButton(
                key: const Key('alarm-setup-clear'),
                label: l10n.alarmClear,
                variant: NButtonVariant.ghost,
                onPressed: () {
                  widget.controller.setAlarm(null);
                  context.pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
