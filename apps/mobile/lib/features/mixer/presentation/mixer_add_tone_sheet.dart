import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/audio_engine/dsp/tone.dart'
    show toneBeatMaxHz, toneGridBeat, toneGridHz, toneHzText, toneMaxHz, toneMinHz;
import '../../../core/audio_engine/mix_player.dart' show BytesAudioSource;
import '../../../core/design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';

/// Mikserdeki "Ton ekle" seçicisi — kullanıcının Hz SEÇTİĞİ sheet.
///
/// ## Neden ayrı bir sheet ("Ses ekle" kataloğuna gömülmedi)
///
/// Katalog DOSYA listeler; ton dosya değil SENTEZ'dir — listeye bir satır
/// koymak "ton = hazır ses" yanılgısını üretirdi. Tonun arayüzü bir SEÇİM
/// aracıdır (sürgü + nota kısayolları); onun kendi yüzeyi olmalı.
///
/// ## SAĞLIK İDDİASI YOK (CLAUDE.md §1.1)
///
/// Nota ön ayarları MÜZİKAL isimlerdir (A2, C3...): eşit tampere perde
/// frekansları. Solfeggio/"şifa frekansı"/"beyin dalgası" söylemi bilinçli
/// olarak YOKTUR — ne etiketlerde ne açıklamada. Konumlandırma "relaxation &
/// sleep ritual"; bu sheet bir müzik aletidir, iddia cihazı değil.
///
/// ## Gösterilen sayı = DUYULAN sayı
///
/// Sürgü serbest değer verir ama motor frekansı 30 sn'lik döngü ızgarasına
/// oturtur ([toneGridHz]). Ekranda istenen DEĞİL oturmuş değer yazılır:
/// fark algısal olarak sıfır olsa bile iki farklı sayı göstermek yalandır.
///
/// ## Binaural vuru (beatHz)
///
/// İkinci sürgü: her kulakta hafif farklı perde → kulakta titreşen bir vuru.
/// 0 = kapalı (mono ton). Vuru değeri de döngü ızgarasına oturur
/// ([toneGridBeat]); ekranda o da oturmuş hâliyle yazılır. **EEG/beyin dalgası
/// adları kullanılmaz** (§1.1) — bu bir akustik olay tanımıdır, iddia değil.
Future<TonePick?> showAddToneSheet(BuildContext context) {
  return showModalBottomSheet<TonePick>(
    context: context,
    isScrollControlled: true,
    backgroundColor: NoctaColors.bgBase,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(NoctaRadius.sheet),
      ),
    ),
    builder: (_) => const AddToneSheet(),
  );
}

/// Sheet'in onayla döndürdüğü seçim.
///
/// **`double` DEĞİL:** ikinci parametre (vuru) geldiğinde iki `double`
/// döndürmenin yolu yoktu; kayıt sınıfı alanları adlandırır — çağıran tarafın
/// "hangisi hangisiydi" bakması gerekmez.
class TonePick {
  const TonePick({required this.frequencyHz, required this.beatHz});

  /// Kullanıcının sürgüyle verdiği TEMEL frekans. Motor ızgaraya oturtur;
  /// etiketteki duyulan değer için `toneGridHz`.
  final double frequencyHz;

  /// Binaural vuru (Hz/s). 0 → mono ton.
  final double beatHz;
}

/// Nota ön ayarları: (etiket, Hz). Eşit tampere, A4=440 referansı.
///
/// Seçim ölçütü AKADEMİK değil PRATİKTİR: düşük perdeden başlayıp oktav
/// atlayan beş durak, sürgüyle arama yapmak istemeyen kullanıcıya hızlı ve
/// makul bir başlangıç verir. Hepsi [toneMinHz]–[toneMaxHz] içindedir.
const List<(String, double)> kToneNotePresets = <(String, double)>[
  ('A2', 110.0),
  ('C3', 130.81),
  ('E3', 164.81),
  ('G3', 196.0),
  ('A3', 220.0),
];

class AddToneSheet extends StatefulWidget {
  const AddToneSheet({super.key});

  @override
  State<AddToneSheet> createState() => _AddToneSheetState();
}

class _AddToneSheetState extends State<AddToneSheet> {
  /// Başlangıç: en düşük nota (A2). Rastgele değil — listenin İLK ön ayarı,
  /// kullanıcı hiçbir şeye dokunmazsa da makul bir uğultu duyulsun.
  double _hz = kToneNotePresets.first.$2;

  /// Vuru başlangıcı 0 = KAPALI. Binaural bir OPT-IN'dir: hiçbir sürgü
  /// kullanıcının haberi olmadan kulaklar arasında fark yaratmamalı.
  double _beat = 0;

  /// Önizleme player'ı — sürgü bırakıldığında kısa bir ton çalar.
  AudioPlayer? _previewPlayer;
  Timer? _previewDebounce;

  /// Döngü uzunluğu: MixPlayer.defaultLoopSeconds ile aynı değer. Sabiti
  /// buraya taşımak yerine sayısal olarak AYNI tutmak yeterlidir — toneGridHz
  /// yalnızca ETİKET için; motor kendi loopSeconds'iyla aynı hesabı yapar ve
  /// her ikisi de aynı formüle (loopLockedHz) dayanır.
  static const double _loopSecondsForLabel = 30;

  /// Önizleme: sürgü bırakıldığında 1 sn'lik saf ton çalar (debounce'lu).
  /// Kullanıcı frekansı DUYARAK seçer — sayı yeterli değil.
  Future<void> _preview() async {
    _previewDebounce?.cancel();
    _previewDebounce = Timer(const Duration(milliseconds: 400), () async {
      final player = _previewPlayer ??= AudioPlayer();
      try {
        const sr = 48000;
        final samples = sr; // 1 saniye
        final f = toneGridHz(_hz, _loopSecondsForLabel);
        final pcm = Float32List(samples);
        for (var i = 0; i < samples; i++) {
          pcm[i] = 0.3 * math.sin(2 * math.pi * f * i / sr);
        }
        // Basit WAV header + PCM
        final wav = BytesBuilder();
        final dataBytes = samples * 2;
        void wAscii(String s) {
          for (final c in s.codeUnits) { wav.addByte(c); }
        }
        void wU32(int v) { final b = ByteData(4)..setUint32(0, v, Endian.little); wav.add(b.buffer.asUint8List()); }
        void wU16(int v) { final b = ByteData(2)..setUint16(0, v, Endian.little); wav.add(b.buffer.asUint8List()); }
        wAscii('RIFF'); wU32(36 + dataBytes); wAscii('WAVE');
        wAscii('fmt '); wU32(16); wU16(1); wU16(1); wU32(sr);
        wU32(sr * 2); wU16(2); wU16(16);
        wAscii('data'); wU32(dataBytes);
        for (final v in pcm) {
          final clamped = v.clamp(-1.0, 1.0);
          final b = ByteData(2)..setInt16(0, (clamped * 32767).round(), Endian.little);
          wav.add(b.buffer.asUint8List());
        }
        await player.setAudioSource(BytesAudioSource(wav.toBytes()));
        await player.play();
      } catch (_) {
        // Önizleme hatası sessizdir — kritik bir özellik değil.
      }
    });
  }

  @override
  void dispose() {
    _previewDebounce?.cancel();
    _previewPlayer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final gridHz = toneGridHz(_hz, _loopSecondsForLabel);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            NoctaSpace.s6,
            NoctaSpace.s5,
            NoctaSpace.s6,
            NoctaSpace.s6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              NDisplay(
                l10n.mixerAddToneTitle,
                key: const Key('add-tone-title'),
                size: NoctaFontSize.h2,
              ),
              const SizedBox(height: NoctaSpace.s2),
              Text(
                l10n.mixerAddToneHint,
                key: const Key('add-tone-hint'),
                style: TextStyle(
                  fontSize: NoctaFontSize.caption,
                  color: NoctaColors.inkSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: NoctaSpace.s5),

              // ── Nota ön ayarları ── müzikal kısayollar, iddia değil.
              Wrap(
                spacing: NoctaSpace.s2,
                runSpacing: NoctaSpace.s2,
                children: <Widget>[
                  for (final (label, hz) in kToneNotePresets)
                    _noteChip(label, hz, selected: _isNear(hz)),
                ],
              ),
              const SizedBox(height: NoctaSpace.s5),

              // ── Serbest frekans ── sürgü + DUYULAN değerin okunması.
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Expanded(child: _slider(Key('add-tone-slider'),
                      value: _hz.clamp(toneMinHz, toneMaxHz),
                      min: toneMinHz,
                      max: toneMaxHz,
                      onChanged: (v) { setState(() => _hz = v); _preview(); })),
                  const SizedBox(width: NoctaSpace.s3),
                  Text(
                    // Izgaraya OTURMUŞ değer: ekranda yazan = duyulan.
                    '${toneHzText(gridHz)} Hz',
                    key: const Key('add-tone-value'),
                    style: const TextStyle(
                      fontFamily: NoctaFont.mono,
                      fontSize: NoctaFontSize.body,
                      letterSpacing: NoctaTrack.tight,
                      fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                      color: NoctaColors.inkPrimary,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: NoctaSpace.s4),

              // ── Binaural vuru ── 0 = kapalı (mono). Kulaklıkla duyulur;
              // hoparlörde iki kanal havada karıştığı için etki zayıflar — bunu
              // ipucunda dürüstçe söylüyoruz.
              Text(
                l10n.mixerToneBeatLabel,
                key: const Key('add-tone-beat-label'),
                style: TextStyle(
                  fontSize: NoctaFontSize.caption,
                  color: NoctaColors.inkSecondary,
                ),
              ),
              const SizedBox(height: NoctaSpace.s1),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Expanded(child: _slider(
                    const Key('add-tone-beat-slider'),
                    value: _beat.clamp(0, toneBeatMaxHz),
                    min: 0,
                    max: toneBeatMaxHz,
                    onChanged: (v) => setState(() => _beat = v),
                  )),
                  const SizedBox(width: NoctaSpace.s3),
                  Text(
                    _beatText(),
                    key: const Key('add-tone-beat-value'),
                    style: const TextStyle(
                      fontFamily: NoctaFont.mono,
                      fontSize: NoctaFontSize.body,
                      letterSpacing: NoctaTrack.tight,
                      fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                      color: NoctaColors.inkPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: NoctaSpace.s2),
              Text(
                l10n.mixerToneBeatHint,
                key: const Key('add-tone-beat-hint'),
                style: TextStyle(
                  fontSize: NoctaFontSize.micro,
                  color: NoctaColors.inkFaint,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: NoctaSpace.s4),
              NButton(
                key: const Key('add-tone-confirm'),
                label: l10n.mixerAddToneConfirm,
                expand: true,
                rule: true,
                onPressed: () =>
                    Navigator.of(context).pop(TonePick(frequencyHz: _hz, beatHz: _beat)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// İki sürgünün ORTAK stili — tek yerde: aynı parmak izi, iki ayrı sürgü.
  Widget _slider(
    Key key, {
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return SliderTheme(
      data: SliderThemeData(
        trackHeight: 26,
        activeTrackColor: NoctaColors.bgPaper,
        inactiveTrackColor: NoctaColors.bgOverlay,
        thumbColor: NoctaColors.accentAurora,
        overlayColor: NoctaColors.accentAurora.withValues(alpha: 0.12),
        trackShape: const RectangularSliderTrackShape(),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
        tickMarkShape: SliderTickMarkShape.noTickMark,
      ),
      child: Slider(key: key, value: value, min: min, max: max, onChanged: onChanged),
    );
  }

  /// Ekranda yazan vuru metni: kapalıyken "Kapalı"; açıkken OTURMUŞ değer.
  String _beatText() {
    if (_beat <= 0) return AppL10n.of(context).mixerToneBeatOff;
    final grid = toneGridBeat(_beat, _loopSecondsForLabel);
    final text = toneHzText(grid); // "8" ya da "7.5"
    return '$text Hz';
  }

  /// Ön ayar çipinin "seçili" kararı: tam eşitlik yerine TOLERANSLU — sürgü
  /// 130.9'a kaymışsa C3 hâlâ "yakın"dır ve basılı görünmesi doğru his verir.
  /// Eşik ±1 Hz: nota adımından (~35 Hz) çok küçük, sürgü titremesinden büyük.
  bool _isNear(double presetHz) => (_hz - presetHz).abs() <= 1;

  Widget _noteChip(String label, double hz, {required bool selected}) {
    return FilterChip(
      key: Key('add-tone-note-$label'),
      label: Text('$label · ${toneHzText(hz)}'),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => setState(() => _hz = hz),
      labelStyle: TextStyle(
        fontSize: NoctaFontSize.caption,
        color: selected ? NoctaColors.bgBase : NoctaColors.inkPrimary,
      ),
      backgroundColor: NoctaColors.bgOverlay,
      selectedColor: NoctaColors.accentAurora,
      checkmarkColor: NoctaColors.bgBase,
      side: BorderSide(color: NoctaColors.lineDashed),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(NoctaRadius.chip)),
      padding: const EdgeInsets.symmetric(horizontal: NoctaSpace.s2, vertical: NoctaSpace.s1),
      // Dokunma hedefi ≥44px (CLAUDE.md §7).
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
  }
}
