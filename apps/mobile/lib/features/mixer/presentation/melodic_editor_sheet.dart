import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/audio_engine/dsp/user_melodic.dart'
    show melodicScales, chordProgressions, userChordsSource, userArpeggioSource, Waveform;
import '../../../core/audio_engine/dsp/wav_encoder.dart' show encodeWav;
import '../../../core/audio_engine/mix_player.dart' show BytesAudioSource;
import '../../../core/design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/melodic_preset_store.dart';

/// Kullanıcının kendi akor/arpejini oluşturduğu editör sheet'i.
///
/// Kök nota, ölçek, tempo, dalga şekli seçilir → canlı önizleme dinlenir →
/// isim verip preset olarak kaydedilir veya doğrudan mikse eklenir.
class MelodicEditorSheet extends StatefulWidget {
  const MelodicEditorSheet({
    super.key,
    required this.isChords,
    required this.presetStore,
    this.initial,
  });

  final bool isChords;
  final MelodicPresetStore presetStore;
  final MelodicPreset? initial;

  @override
  State<MelodicEditorSheet> createState() => _MelodicEditorSheetState();
}

class _MelodicEditorSheetState extends State<MelodicEditorSheet> {
  late int _rootSemi = widget.initial?.rootSemi ?? 0;
  late int _patternIdx = widget.initial?.patternIdx ?? 0;
  late String _waveform = widget.initial?.waveform ?? 'sine';
  late double _tempoScale = widget.initial?.tempoScale ?? 1.0;
  AudioPlayer? _previewPlayer;
  Timer? _debounce;

  static const List<String> _waveforms = ['sine', 'triangle', 'saw', 'square'];

  @override
  void dispose() {
    _debounce?.cancel();
    _previewPlayer?.dispose();
    super.dispose();
  }

  /// Önizleme: GERÇEK akor progresyonunu veya arpej desenini çalar (4 sn).
  ///
  /// Önceki hali tek nota çalıyordu — kullanıcı "sadece bir akör duydum" dedi.
  /// Artık DSP kaynaklarını KISA SÜRELİ çağırarak tam melodik içeriği duyurur.
  Future<void> _preview() async {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final player = _previewPlayer ??= AudioPlayer();
      try {
        const sr = 48000;
        const previewSec = 4;
        final samples = sr * previewSec;
        final loopSamples = samples; // önizleme = tek döngü
        final Float32List pcm;

        if (widget.isChords) {
          // Gerçek akor progresyonu render et (kısa süre).
          pcm = userChordsSource(
            samples,
            sampleRate: sr,
            loopSamples: loopSamples,
            rootSemi: _rootSemi,
            progressionIdx: _patternIdx,
            waveform: Waveform.values.firstWhere(
              (w) => w.name == _waveform, orElse: () => Waveform.sine),
            tempoScale: _tempoScale,
          );
        } else {
          // Gerçek arpej render et (kısa süre).
          pcm = userArpeggioSource(
            samples,
            seed: 42,
            sampleRate: sr,
            loopSamples: loopSamples,
            rootSemi: _rootSemi,
            scaleIdx: _patternIdx,
            waveform: Waveform.values.firstWhere(
              (w) => w.name == _waveform, orElse: () => Waveform.sine),
            tempoScale: _tempoScale,
          );
        }

        final wav = encodeWav(pcm, sampleRate: sr);
        await player.setAudioSource(BytesAudioSource(wav));
        await player.play();
      } catch (e, st) {
        // Önizleme çalınamazsa editör çalışmaya devam eder; ama hata YUTULMAZ
        // (CLAUDE.md §4: boş catch yasak).
        debugPrint('nocta.melodic: önizleme çalınamadı: $e\n$st');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NDisplay(
              widget.isChords ? l10n.mixerLayerChords : l10n.mixerLayerArpeggio,
              key: const Key('melodic-editor-title'),
              size: NoctaFontSize.h2,
            ),
            const SizedBox(height: NoctaSpace.s4),

            // ── Kök nota ──
            Text(l10n.melodicRootNote, style: TextStyle(fontSize: NoctaFontSize.caption, color: NoctaColors.inkSecondary)),
            const SizedBox(height: NoctaSpace.s2),
            Wrap(
              spacing: NoctaSpace.s1,
              children: List.generate(12, (i) => _noteChip(i)),
            ),
            const SizedBox(height: NoctaSpace.s4),

            // ── Ölçek / Progresyon ──
            if (!widget.isChords) ...[
              Text(l10n.melodicScale, style: TextStyle(fontSize: NoctaFontSize.caption, color: NoctaColors.inkSecondary)),
              const SizedBox(height: NoctaSpace.s2),
              Wrap(
                spacing: NoctaSpace.s2,
                children: List.generate(melodicScales.length, (i) => _chip(
                  label: melodicScaleLabel(l10n, melodicScales[i].name) ??
                      melodicScales[i].name,
                  selected: _patternIdx == i,
                  onTap: () { setState(() => _patternIdx = i); _preview(); },
                )),
              ),
              const SizedBox(height: NoctaSpace.s4),
            ],
            if (widget.isChords) ...[
              Text(l10n.melodicProgression, style: TextStyle(fontSize: NoctaFontSize.caption, color: NoctaColors.inkSecondary)),
              const SizedBox(height: NoctaSpace.s2),
              Wrap(
                spacing: NoctaSpace.s2,
                children: List.generate(chordProgressions.length, (i) => _chip(
                  label: chordProgressions[i].name,
                  selected: _patternIdx == i,
                  onTap: () { setState(() => _patternIdx = i); _preview(); },
                )),
              ),
              const SizedBox(height: NoctaSpace.s4),
            ],

            // ── Tempo ──
            Text(l10n.melodicTempo, style: TextStyle(fontSize: NoctaFontSize.caption, color: NoctaColors.inkSecondary)),
            SliderTheme(
              data: SliderThemeData(trackHeight: 20, activeTrackColor: NoctaColors.bgPaper, inactiveTrackColor: NoctaColors.bgOverlay, thumbColor: NoctaColors.accentAurora),
              child: Slider(
                key: const Key('melodic-tempo'),
                value: _tempoScale.clamp(0.5, 2.0),
                min: 0.5, max: 2.0, divisions: 6,
                label: l10n.melodicTempoValue(_tempoScale.toStringAsFixed(1)),
                onChanged: (v) { setState(() => _tempoScale = v); _preview(); },
              ),
            ),

            // ── Dalga şekli ──
            Text(l10n.melodicInstrument, style: TextStyle(fontSize: NoctaFontSize.caption, color: NoctaColors.inkSecondary)),
            const SizedBox(height: NoctaSpace.s2),
            Wrap(
              spacing: NoctaSpace.s2,
              children: List.generate(_waveforms.length, (i) => _chip(
                label: _waveformLabel(l10n, _waveforms[i]),
                selected: _waveform == _waveforms[i],
                onTap: () { setState(() => _waveform = _waveforms[i]); _preview(); },
              )),
            ),

            const SizedBox(height: NoctaSpace.s5),
            Row(children: [
              Expanded(child: NButton(key: const Key('melodic-preview'), label: l10n.melodicPreview, variant: NButtonVariant.ghost, onPressed: _preview)),
              const SizedBox(width: NoctaSpace.s3),
              Expanded(child: NButton(
                key: const Key('melodic-add'),
                label: l10n.mixerAddToneConfirm,
                expand: true, rule: true,
                onPressed: () => Navigator.of(context).pop(MelodicPreset(
                  name: '', rootSemi: _rootSemi, patternIdx: _patternIdx,
                  waveform: _waveform, tempoScale: _tempoScale,
                  isChords: widget.isChords,
                )),
              )),
            ]),
            const SizedBox(height: NoctaSpace.s3),
            // ── Kaydet ──
            NButton(
              key: const Key('melodic-save'),
              label: l10n.melodicSaveAsSet,
              variant: NButtonVariant.ghost,
              expand: true,
              onPressed: () async {
                final nameCtrl = TextEditingController();
                final name = await showDialog<String>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: NoctaColors.bgRaised,
                    title: Text(l10n.melodicSetNameTitle),
                    content: TextField(controller: nameCtrl, autofocus: true,
                      decoration: InputDecoration(hintText: l10n.melodicSetNameHint)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
                      TextButton(key: Key('melodic-save-confirm'), onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()), child: Text(l10n.melodicSave)),
                    ],
                  ),
                );
                if (name == null || name.isEmpty || !context.mounted) return;
                await widget.presetStore.save(MelodicPreset(
                  name: name, rootSemi: _rootSemi, patternIdx: _patternIdx,
                  waveform: _waveform, tempoScale: _tempoScale, isChords: widget.isChords,
                ));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.melodicSaved(name))));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _noteChip(int semi) {
    final names = ['A','A♯','B','C','C♯','D','D♯','E','F','F♯','G','G♯'];
    return FilterChip(
      label: Text(names[semi]),
      selected: _rootSemi == semi,
      showCheckmark: false,
      onSelected: (_) { setState(() => _rootSemi = semi); _preview(); },
      labelStyle: TextStyle(fontSize: NoctaFontSize.caption, color: _rootSemi == semi ? NoctaColors.bgBase : NoctaColors.inkPrimary),
      backgroundColor: NoctaColors.bgOverlay,
      selectedColor: NoctaColors.accentAurora,
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
  }

  Widget _chip({required String label, required bool selected, required VoidCallback onTap}) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
      labelStyle: TextStyle(fontSize: NoctaFontSize.caption, color: selected ? NoctaColors.bgBase : NoctaColors.inkPrimary),
      backgroundColor: NoctaColors.bgOverlay,
      selectedColor: NoctaColors.accentAurora,
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
  }
}

/// Kayıtlı melodik preset'lerin listelendiği ve seçilebildiği sheet.
class MelodicPresetLibrarySheet extends StatefulWidget {
  const MelodicPresetLibrarySheet({super.key, required this.store});

  final MelodicPresetStore store;

  @override
  State<MelodicPresetLibrarySheet> createState() => _MelodicPresetLibrarySheetState();
}

class _MelodicPresetLibrarySheetState extends State<MelodicPresetLibrarySheet> {
  List<MelodicPreset> _presets = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    widget.store.list().then((presets) {
      if (mounted) setState(() { _presets = presets; _loading = false; });
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NDisplay(l10n.melodicPresetLibraryTitle, key: const Key('melodic-preset-lib-title'), size: NoctaFontSize.h2),
            const SizedBox(height: NoctaSpace.s4),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_presets.isEmpty)
              Text(l10n.melodicPresetLibraryEmpty,
                style: TextStyle(fontSize: NoctaFontSize.body, color: NoctaColors.inkSecondary))
            else
              for (final p in _presets)
                Padding(
                  padding: const EdgeInsets.only(bottom: NoctaSpace.s2),
                  child: InkWell(
                    key: Key('preset-${p.name}'),
                    onTap: () => Navigator.of(context).pop(p),
                    borderRadius: BorderRadius.circular(NoctaRadius.card),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: NoctaSpace.s4, vertical: NoctaSpace.s3),
                      decoration: BoxDecoration(
                        color: NoctaColors.bgOverlay,
                        border: Border.all(color: NoctaColors.lineDashed),
                      ),
                      child: Row(children: [
                        Expanded(child: Text(p.name.isEmpty ? l10n.melodicUntitled : p.name,
                          style: TextStyle(fontSize: NoctaFontSize.body, color: NoctaColors.inkPrimary))),
                        Text(p.isChords ? l10n.melodicKindChords : l10n.melodicKindArpeggio,
                          style: TextStyle(fontSize: NoctaFontSize.caption, color: NoctaColors.inkFaint)),
                      ]),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

/// Ölçek adının kullanıcıya görünen hâli; tanınmayan ad için `null`.
///
/// Ses motorundaki ad (`melodicScales[i].name`) bir KİMLİKTİR, arayüz metni
/// değil: motor katmanı (`core/audio_engine`) çeviri bilmez ve bilmemeli.
/// Eskiden bu ad doğrudan ekrana basılıyordu; İngilizce kullanıcı "Majör",
/// "Minör" görüyordu. `null` dönüşü, motora eklenip buraya eklenmeyen bir
/// ölçeği testin yakalayabilmesi için var (bkz. melodic_editor_sheet_test).
String? melodicScaleLabel(AppL10n l10n, String engineName) => switch (engineName) {
  'Pentatonik' => l10n.melodicScalePentatonic,
  'Majör' => l10n.melodicScaleMajor,
  'Minör' => l10n.melodicScaleMinor,
  'Dorian' => l10n.melodicScaleDorian,
  'Frygian' => l10n.melodicScalePhrygian,
  'Lydian' => l10n.melodicScaleLydian,
  'Mixolydian' => l10n.melodicScaleMixolydian,
  'Harmonic Minör' => l10n.melodicScaleHarmonicMinor,
  'Blues' => l10n.melodicScaleBlues,
  _ => null,
};

/// Dalga şeklinin kullanıcıya görünen adı. Motor kimliği (`sine` vb.) değişmez.
String _waveformLabel(AppL10n l10n, String waveform) => switch (waveform) {
  'sine' => l10n.melodicWaveSine,
  'triangle' => l10n.melodicWaveTriangle,
  'saw' => l10n.melodicWaveSaw,
  'square' => l10n.melodicWaveSquare,
  _ => waveform,
};
