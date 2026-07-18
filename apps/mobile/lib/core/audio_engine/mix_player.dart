/// `MixSpec` → gerçekten duyulan ses.
///
/// **NEDEN VAR:** DSP zinciri (`engine_params → MixSpec → renderMix → PCM`) baştan
/// sona yazılmış, test edilmiş ve **hiçbir yere bağlanmamıştı** — üretilen ses hiçbir
/// zaman çalınmadı (#95'ten beri ölü kod). Burası o zincirin hoparlöre çıktığı yer.
///
/// **KATMAN BAŞINA AYRI PLAYER — neden:** tek karışık buffer çalsaydık, slider'ı
/// oynatmak yeniden render + yeniden başlatma gerektirirdi: sesin kesilmesi ve tık.
/// Katman başına player'da slider doğrudan `setVolume`'a gider → **anında ve sürekli**.
/// Bu, mikserin gerçek semantiği (bağımsız katman kazançları).
///
/// **Player'ların birbirinden kayması** kabul edilebilir: katmanlar gürültü (pembe/
/// kahverengi/beyaz) ve gürültüde faz algısal DEĞİL — kayma duyulmaz. Ritmik/tonal
/// katman eklenirse bu varsayım ÇÖKER ve senkron gerekir (o zaman native graf zaten şart).
///
/// ## ⚠️ BU NİHAİ MİMARİ DEĞİL
///
/// CLAUDE.md §3.1 native ses grafı (iOS: AVAudioEngine, Android: Oboe) şart koşuyor.
/// Bu katman **önceden render edilmiş buffer'ı döngüler**. Bilinen sınırları:
///
/// - **✓ Döngü dikişi (ÇÖZÜLDÜ, #170):** eskiden buffer'ın sonu ile başı arasında
///   süreklilik yoktu → her döngüde tık. Artık katman buffer'ı `renderSeamlessLoop`
///   ile üretiliyor (kuyruk başa eşit-güç crossfade) → `LoopMode.one` dikişi sürekli.
/// - **Referans mikserin kompresörü devrede değil:** `renderMix` katmanları toplayıp
///   sıkıştırıyordu; burada toplama işletim sistemi mikserinde oluyor → yüksek
///   kazançlarda OS seviyesinde kırpma olabilir.
/// - **Gerçek zamanlı kazanç rampası yok:** `setVolume` platformun rampasına bağlı.
/// - **RAM:** katman başına ~2.8 MB (30 sn @48kHz, 16-bit).
///
/// Kalan sınırlar (kompresör, rampa, RAM) native graf gelince çözülür; o zaman bu
/// sınıf `AudioEngineFacade`'in arkasındaki bir implementasyona dönüşür.
library;

import 'dart:typed_data';

import 'package:just_audio/just_audio.dart';

import 'dsp/mix_loop.dart';
import 'dsp/mix_render.dart';
import 'dsp/wav_encoder.dart';

/// Bellekteki WAV'ı just_audio'ya besleyen kaynak — geçici DOSYA YOK.
///
/// Diske yazmamak bilinçli: uyku sesi kullanıcının cihazında saatlerce çalar; her
/// mix değişiminde dosya yazmak hem gereksiz I/O hem de temizlenmesi unutulacak çöp.
///
/// **Public çünkü alarm da aynı şeye ihtiyaç duyuyor** (`SunriseAlarmSound`): ikinci
/// bir kopya yazmak, `experimental_member_use` bastırmasını ve içerik tipini iki yerde
/// tutmak olurdu.
// ignore: experimental_member_use
class BytesAudioSource extends StreamAudioSource {
  BytesAudioSource(this._bytes);

  final Uint8List _bytes;

  // just_audio 0.10'da StreamAudioSource API'si "experimental" işaretli ama bellekten
  // besleme için TEK yol; alternatifi her mix değişiminde geçici DOSYA yazmak olurdu.
  // Bilinçli kabul: paket sürümü pubspec'te sabit (^0.10.6), kırılırsa test yakalar.
  @override
  // ignore: experimental_member_use
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final from = start ?? 0;
    final to = end ?? _bytes.length;
    // ignore: experimental_member_use
    return StreamAudioResponse(
      sourceLength: _bytes.length,
      contentLength: to - from,
      offset: from,
      stream: Stream.value(_bytes.sublist(from, to)),
      contentType: 'audio/wav',
    );
  }
}

/// Tek bir katmanın çalar durumu.
class _LayerVoice {
  _LayerVoice(this.id, this.player);

  final String id;
  final AudioPlayer player;
}

/// Bir [MixSpec]'i çalar; katman kazançları canlı değiştirilebilir.
class MixPlayer {
  MixPlayer({
    this.loopSeconds = 30,
    this.sampleRate = 48000,
    AudioPlayer Function()? playerFactory,
  }) : _newPlayer = playerFactory ?? AudioPlayer.new;

  /// Döngü uzunluğu. Uzun = dikiş daha seyrek duyulur, RAM daha çok. 30 sn ≈ 2.8 MB/katman.
  final int loopSeconds;
  final int sampleRate;

  /// Test, gerçek `AudioPlayer` yerine sahte enjekte edebilsin diye (cihazsız test).
  final AudioPlayer Function() _newPlayer;

  final List<_LayerVoice> _voices = [];
  bool _disposed = false;

  bool get isPlaying => _voices.isNotEmpty && _voices.first.player.playing;

  /// Katman sayısı — testte ve teşhis için.
  int get voiceCount => _voices.length;

  /// [spec]'i hazırlar: her katmanı AYRI render eder ve kendi player'ına yükler.
  ///
  /// **Katmanlar `gain: 1.0` ile render edilir**, kazanç `setVolume` ile uygulanır —
  /// tam da bu yüzden slider yeniden render gerektirmez.
  Future<void> load(MixSpec spec) async {
    await _disposeVoices();

    for (var i = 0; i < spec.layers.length; i++) {
      final layer = spec.layers[i];

      // Tek katmanlık spec, SORUNSUZ döngü ile: kuyruk başa crossfade'lenir →
      // `LoopMode.one` dikişinde periyodik tık yok (#170). Seed katman indeksinden
      // türetilir → katmanlar korelasyonsuz.
      final pcm = renderSeamlessLoop(
        MixSpec([MixLayer(id: layer.id, type: layer.type, gain: 1.0)]),
        loopSeconds: loopSeconds,
        sampleRate: sampleRate,
        seed: i * 104729, // asal: katmanlar arası benzerlik olmasın
      );

      final player = _newPlayer();
      await player.setAudioSource(BytesAudioSource(encodeWav(pcm, sampleRate: sampleRate)));
      await player.setLoopMode(LoopMode.one);
      await player.setVolume(layer.gain.clamp(0.0, 1.0));
      _voices.add(_LayerVoice(layer.id, player));
    }
  }

  Future<void> play() async {
    // `play()` beklenmez (await) — o, ses BİTENE kadar bekler; burada döngüdeyiz,
    // yani beklemek sonsuza kadar asılı kalmak olurdu. Bilinçli fire-and-forget.
    for (final v in _voices) {
      unawaited(v.player.play());
    }
  }

  Future<void> pause() async {
    await Future.wait(_voices.map((v) => v.player.pause()));
  }

  /// Katman kazancını CANLI değiştirir. Bilinmeyen id sessizce yok sayılır:
  /// UI ile spec arasındaki geçici uyumsuzluk sesi kesmemeli.
  Future<void> setLayerGain(String id, double gain) async {
    for (final v in _voices) {
      if (v.id == id) {
        await v.player.setVolume(gain.clamp(0.0, 1.0));
        return;
      }
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    await _disposeVoices();
  }

  Future<void> _disposeVoices() async {
    final old = List.of(_voices);
    _voices.clear();
    await Future.wait(old.map((v) => v.player.dispose()));
  }

  bool get isDisposed => _disposed;
}

/// `unawaited` için minik yardımcı (dart:async'i tüm dosyaya taşımamak için).
void unawaited(Future<void> f) {
  // Hata YUTULMAZ (CLAUDE.md §4: boş catch yasak) — sessizce ölen ses en kötüsü.
  f.catchError((Object e, StackTrace s) {
    // ignore: avoid_print
    print('MixPlayer: çalma hatası: $e');
  });
}
