import '../../../core/audio_engine/dsp/mix_render.dart';
import '../../../core/audio_engine/mix_player.dart';
import '../mixer/mixer_controller.dart' show defaultMixSpec;

/// Uyku ritüeli ses portu — gece boyu çalınacak jeneratif miksin denetim düzeyi.
///
/// [SleepModeController] bu arayüzü bilir, [MixPlayer]'ı DEĞİL: ses motoruyla
/// uyku takibinin birleşmesi (4. özellik "tek tuş") bağımlılık yönünü bozmaz.
/// Testler sahte bir player enjekte eder; gerçek yol aşağıdaki sarmalayıcıdır.
abstract class NightSoundPlayer {
  bool get isPlaying;

  /// Mevcut/kayıtlı spec'i hazir hale getirip başlatır. Tekrar çağrılması
  /// güvenlidir (zaten çalıyorsa no-op davranışı sarmalayıcının sorumluluğu).
  Future<void> play();

  /// Susturur ama yükü BIRAKMAZ: kullanıcı gece yarısı kapatıp açabilir;
  /// yeniden render (~300 ms/katman) yerine anında dönüş.
  Future<void> stop();
}

/// Üretim: kendi [MixPlayer] örneğiyle varsayılan tarifi gece boyu döngüler.
///
/// **MixerScreen'in player'ıyla PAYLAŞILMAZ**, bilinçli: iki ekran aynı
/// controller'a komut etseydi, gündüz mikserde sürgü oynatan kullanıcı ile
/// gece ritüeli birbirini sustururdu. Ayrık örnek = ayrık yaşam.
class MixNightSoundPlayer implements NightSoundPlayer {
  MixNightSoundPlayer({required this.player, this.spec});

  final MixPlayer player;

  /// null → [defaultMixSpec] (uygulamanın varsayılan karışımı).
  final MixSpec? spec;

  bool _loaded = false;

  @override
  bool get isPlaying => _loaded && player.isPlaying;

  @override
  Future<void> play() async {
    if (player.isPlaying) return;
    if (!_loaded) {
      // İlk gece: tek seferlik render (~300 ms/7 katman). Sonrakiler bellekten.
      await player.load(spec ?? defaultMixSpec());
      _loaded = true;
    }
    await player.play();
  }

  @override
  Future<void> stop() => player.pause();
}
