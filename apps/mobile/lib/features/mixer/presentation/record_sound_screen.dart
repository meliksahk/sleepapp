import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio_engine/dsp/asset_layer.dart';
import '../../../core/design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';
import '../data/local_sound_library_impl.dart' show kMaxImportedLayers;
import '../domain/local_sound.dart';
import '../domain/sound_recorder.dart';
import '../mixer_providers.dart';

/// **Kendi kaydın** (F3) — bir mekânın sesini kaydet, adını ver, mikse koy.
///
/// ## Neden ürünün merkezinde
///
/// Konum "gerçek yerlerin sesi". Kullanıcının kendi mutfağı, kendi yağmuru,
/// kendi treni bizim üretebileceğimiz hiçbir şeyin veremeyeceği bir bağ kurar.
///
/// ## Paylaşım YOK — bilinçli
///
/// Kayıt cihazda kalır, sunucuya GİTMEZ. Başkalarının kaydını dinlemek (UGC)
/// depolama/bant/moderasyon/DMCA maliyeti demek ve bu maliyet gelir gelmeden
/// alınmayacak. Bu ekranda hiçbir "paylaş" düğmesi yok ve bu bir eksiklik değil,
/// verilmiş bir karar.
///
/// ## Akış
///
/// izin → kaydet (süre sayacı, 5 dk tavanı) → durdur → mekân etiketi → kütüphane
/// → mikse katman. Vazgeçmek her adımda mümkün ve yarım dosya diskte kalmaz.
class RecordSoundScreen extends ConsumerStatefulWidget {
  const RecordSoundScreen({super.key, required this.currentAssetLayerCount});

  final int currentAssetLayerCount;

  @override
  ConsumerState<RecordSoundScreen> createState() => _RecordSoundScreenState();
}

enum _Stage { idle, recording, naming, saving }

class _RecordSoundScreenState extends ConsumerState<RecordSoundScreen> {
  _Stage _stage = _Stage.idle;
  Duration _elapsed = Duration.zero;
  Timer? _ticker;
  String? _path;
  String? _error;
  final TextEditingController _title = TextEditingController();

  /// **`dispose` içinde `ref` OKUNAMAZ** (Riverpod widget'ı düşmüşken atar —
  /// testte yakalandı). Kaydedici bu yüzden ekran kurulurken bir kez alınır.
  late final SoundRecorder _recorder;

  @override
  void initState() {
    super.initState();
    _recorder = ref.read(soundRecorderProvider);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _title.dispose();
    // Ekran kapanırken kayıt sürüyorsa iptal et: arka planda çalan bir mikrofon
    // hem pil hem güven sorunudur.
    //
    // `dispose()` ÇAĞRILMAZ: kaydedici provider'a ait (uygulama ömrü). Burada
    // kapatsaydık ikinci kayıt kapalı bir AudioRecorder'a düşerdi.
    if (_stage == _Stage.recording) unawaited(_recorder.cancel());
    super.dispose();
  }

  Future<void> _start() async {
    setState(() => _error = null);
    final l10n = AppL10n.of(context);

    final allowed = await _recorder.requestPermission();
    if (!mounted) return;
    if (!allowed) {
      setState(() => _error = l10n.recordPermissionDenied);
      return;
    }

    final path = await ref.read(localSoundLibraryProvider).newRecordingPath();
    if (!mounted) return;
    try {
      await _recorder.start(path);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = l10n.recordFailed);
      return;
    }
    if (!mounted) return;

    setState(() {
      _path = path;
      _stage = _Stage.recording;
      _elapsed = Duration.zero;
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed += const Duration(seconds: 1));
      // TAVAN: ekran açık unutulursa kayıt kendini durdurur (bkz.
      // kMaxRecordingDuration). Sessizce kesmek yerine adlandırmaya geçer —
      // kullanıcı o ana kadarki kaydını kaybetmez.
      if (_elapsed >= kMaxRecordingDuration) unawaited(_stop());
    });
  }

  Future<void> _stop() async {
    _ticker?.cancel();
    _ticker = null;
    final saved = await _recorder.stop();
    if (!mounted) return;
    setState(() {
      _path = saved ?? _path;
      _stage = _Stage.naming;
    });
  }

  Future<void> _cancel() async {
    _ticker?.cancel();
    _ticker = null;
    await _recorder.cancel();
    if (!mounted) return;
    setState(() {
      _stage = _Stage.idle;
      _elapsed = Duration.zero;
      _path = null;
    });
  }

  Future<void> _save() async {
    final path = _path;
    final l10n = AppL10n.of(context);
    if (path == null) {
      setState(() => _error = l10n.recordFailed);
      return;
    }
    setState(() => _stage = _Stage.saving);

    final library = ref.read(localSoundLibraryProvider);
    final result = await library.adoptRecording(
      partPath: path,
      title: _title.text,
      currentAssetLayerCount: widget.currentAssetLayerCount,
    );
    if (!mounted) return;

    switch (result) {
      case LocalSoundImported(:final sound):
        ref.invalidate(localSoundsProvider);
        final filePath = await library.pathOf(sound);
        if (!mounted) return;
        // Kaydı ALIP mikse koyuyoruz: kullanıcının niyeti "kütüphaneye koymak"
        // değil "duymak" (ithal akışıyla aynı gerekçe).
        Navigator.of(context).pop(
          AssetLayer(
            id: sound.id,
            title: sound.title,
            url: filePath,
            gain: 0.3,
          ),
        );
      case LocalSoundImportRejected(:final reason):
        setState(() {
          _stage = _Stage.naming;
          _error = switch (reason) {
            LocalSoundImportFailure.tooManyLayers =>
              l10n.mixerLocalImportTooManyLayers('$kMaxImportedLayers'),
            LocalSoundImportFailure.libraryFull => l10n.recordLibraryFull,
            LocalSoundImportFailure.noSpace => l10n.mixerLocalImportNoSpace,
            _ => l10n.recordFailed,
          };
        });
    }
  }

  String _clock(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Scaffold(
      appBar: AppBar(title: NMono(l10n.recordTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(NoctaSpace.s6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              NDisplay(l10n.recordTitle, size: NoctaFontSize.h1),
              const SizedBox(height: NoctaSpace.s3),
              Text(
                // Gizlilik sözü EKRANDA: kaydın nereye gittiği (hiçbir yere)
                // kullanıcıya kayıt başlamadan söylenir.
                l10n.recordPrivacy,
                key: const Key('record-privacy'),
                style: const TextStyle(
                  fontSize: NoctaFontSize.caption,
                  color: NoctaColors.inkSecondary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: NoctaSpace.s8),
              Center(
                child: Text(
                  _clock(_elapsed),
                  key: const Key('record-clock'),
                  style: const TextStyle(
                    fontFamily: NoctaFont.mono,
                    fontSize: 48,
                    color: NoctaColors.inkPrimary,
                    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(height: NoctaSpace.s8),
              if (_error != null) ...<Widget>[
                Text(
                  _error!,
                  key: const Key('record-error'),
                  style: const TextStyle(
                    fontSize: NoctaFontSize.caption,
                    color: NoctaColors.danger,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: NoctaSpace.s4),
              ],
              ..._stageBody(l10n),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _stageBody(AppL10n l10n) => switch (_stage) {
    _Stage.idle => <Widget>[
      NButton(
        key: const Key('record-start'),
        label: l10n.recordStart,
        onPressed: _start,
      ),
    ],
    _Stage.recording => <Widget>[
      NButton(
        key: const Key('record-stop'),
        label: l10n.recordStop,
        onPressed: _stop,
      ),
      const SizedBox(height: NoctaSpace.s3),
      NButton(
        key: const Key('record-cancel'),
        label: l10n.commonCancel,
        variant: NButtonVariant.ghost,
        onPressed: _cancel,
      ),
    ],
    _Stage.naming => <Widget>[
      TextField(
        key: const Key('record-title'),
        controller: _title,
        style: const TextStyle(
          fontSize: NoctaFontSize.body,
          color: NoctaColors.inkPrimary,
        ),
        decoration: InputDecoration(
          hintText: l10n.recordPlaceHint,
          hintStyle: const TextStyle(color: NoctaColors.inkSecondary),
          enabledBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: NoctaColors.lineSoft),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: NoctaColors.inkSecondary),
          ),
        ),
      ),
      const SizedBox(height: NoctaSpace.s4),
      NButton(
        key: const Key('record-save'),
        label: l10n.recordSave,
        onPressed: _save,
      ),
    ],
    _Stage.saving => <Widget>[
      const Center(
        child: CircularProgressIndicator(key: Key('record-saving')),
      ),
    ],
  };
}
