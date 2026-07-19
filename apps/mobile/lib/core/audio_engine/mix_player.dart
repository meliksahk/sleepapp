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
/// **Player'ların birbirinden kayması** gürültü katmanlarında kabul edilebilir:
/// gürültüde faz algısal DEĞİL — kayma duyulmaz.
///
/// **AMA BU VARSAYIM ARTIK TAM DEĞİL (#213).** Motora `pad` eklendi ve pad TONAL.
/// Bu yorum eskiden "tonal katman eklenirse varsayım çöker" diyordu; katman eklendi,
/// yorum güncellenmedi — denetimde yakalandı. Bugünkü durum dürüstçe şudur:
///
/// - **Tek pad + gürültüler:** sorun yok. Kayma ancak İKİ tonal kaynak arasında
///   duyulur (vuru/faz girişimi); pad ile gürültü arasında algısal bir faz ilişkisi
///   yoktur.
/// - **İki pad katmanı aynı tarifte:** player'lar bağımsız başladığı için aralarında
///   sabit olmayan bir faz farkı olur → vuru duyulabilir. Bu ÖLÇÜLMEDİ (cihaz
///   gerekiyor) ve bugün hiçbir tarifte iki pad yok.
///
/// Gerçek çözüm native graf (aşağıda); o gelene kadar tarif yazarken tek pad kuralı
/// geçerli sayılmalıdır.
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

import 'package:flutter/foundation.dart' show compute;

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
  /// Varsayılan döngü uzunluğu. **Paylaşılan sabit:** video export'u da meditatif
  /// kaynakların modülasyon periyodunu buna kilitler ki paylaşılan ses, kullanıcının
  /// duyduğu sesle aynı karakterde olsun (bkz. `renderMix(loopSeconds:)`).
  static const int defaultLoopSeconds = 30;

  MixPlayer({
    this.loopSeconds = defaultLoopSeconds,
    this.sampleRate = 48000,
    AudioPlayer Function()? playerFactory,
    Future<Float32List> Function(LoopRequest)? loopRenderer,
    this.onAssetError,
  })  : _newPlayer = playerFactory ?? AudioPlayer.new,
        _renderLoop = loopRenderer ?? _computeLoop;

  /// Bir asset katmanı yüklenemediğinde çağrılır (dosya yok, ağ yok, bozuk kod
  /// çözücü...). **Yüklenemeyen katman mix'i ÇÖKERTMEZ:** diğer katmanlar çalar.
  ///
  /// Gerekçe (CLAUDE.md §3.1 offline-first): kullanıcı uçakta, presigned URL'i
  /// dolmuş ya da dosya silinmiş olabilir. Bu durumda doğru davranış sessiz bir
  /// hata ekranı değil, EKSİK AMA ÇALAN bir mikserdir. Hata YUTULMAZ (§4): log'a
  /// basılır ve bu geri çağrı ile UI'a bildirilir.
  final void Function(String assetId, Object error)? onAssetError;

  /// Bu yüklemede düşen asset katmanlarının id'leri. [load] her çağrıda sıfırlar.
  final List<String> failedAssetIds = <String>[];

  /// Katman buffer'ını üreten fonksiyon.
  ///
  /// **Neden enjekte edilebilir:** üretimde `compute()` ile AYRI ISOLATE'te
  /// çalışır (ölçüldü: yedi katman 285 ms — UI isolate'inde görünür donma).
  /// Ama `compute()` gerçek bir isolate açar ve widget testlerinin sabit `pump`
  /// döngüleri onun tamamlanmasını beklemez; testler senkron bir renderer
  /// enjekte eder. `playerFactory` ile aynı desen.
  final Future<Float32List> Function(LoopRequest) _renderLoop;

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
    failedAssetIds.clear();

    for (var i = 0; i < spec.layers.length; i++) {
      final layer = spec.layers[i];

      // Tek katmanlık spec, SORUNSUZ döngü ile: kuyruk başa crossfade'lenir →
      // `LoopMode.one` dikişinde periyodik tık yok (#170). Seed katman indeksinden
      // türetilir → katmanlar korelasyonsuz.
      // AYRI ISOLATE'TE ÜRETİLİR. Ölçüldü (30 sn @48kHz, host CPU): pad tek
      // başına 189 ms, yedi katmanın tamamı 285 ms. UI isolate'inde yapılırsa
      // mikser açılışında görünür donma olur. Kod tabanının kendi kuralı bu:
      // `signature_player.dart` aynı gerekçeyle `compute()` kullanıyor ve
      // `nocta_signature.dart` "çağıran compute() ile ayrı isolate'e almalıdır"
      // diyor — pad aynı partial+shimmer desenini kullandığı için kural ona da
      // uygulanmalıydı; bu iterasyonda atlanmıştı.
      final pcm = await _renderLoop(
        LoopRequest(
          type: layer.type,
          id: layer.id,
          loopSeconds: loopSeconds,
          sampleRate: sampleRate,
          seed: i * 104729, // asal: katmanlar arası benzerlik olmasın
        ),
      );

      final player = _newPlayer();
      await player.setAudioSource(BytesAudioSource(encodeWav(pcm, sampleRate: sampleRate)));
      await player.setLoopMode(LoopMode.one);
      await player.setVolume(layer.gain.clamp(0.0, 1.0));
      _voices.add(_LayerVoice(layer.id, player));
    }

    await _loadAssets(spec);
  }

  /// DOSYA katmanları — **render YOK**, kaynak doğrudan dosya/URL.
  ///
  /// Sentez yolundan ayrı tutuluyor çünkü ortak hiçbir adımı yok: buffer
  /// üretilmiyor, WAV'a paketlenmiyor, isolate'e iş atılmıyor. Ortak olan tek şey
  /// sonuç: aynı `_voices` listesine giren bir `AudioPlayer`. Bu bilinçli —
  /// böylece `setLayerGain`, `play`, `pause`, `dispose` İKİ TÜR İÇİN DE tek
  /// koddan çalışır ve sürgü, katmanın sentez mi dosya mı olduğunu bilmez.
  ///
  /// Her katman AYRI try/catch içinde: bozuk tek bir dosya, mix'in tamamını
  /// düşürmemeli.
  Future<void> _loadAssets(MixSpec spec) async {
    for (final asset in spec.assets) {
      await addAsset(asset);
    }
  }

  /// TEK bir dosya katmanını **çalarken** mikse ekler.
  ///
  /// **Neden `load()` yeniden çağrılmıyor:** kullanıcı katalogdan bir ses
  /// eklediğinde mix zaten çalıyor olabilir. `load()` tüm sesleri atıp her sentez
  /// katmanını YENİDEN render ederdi (yedi katman ≈ 285 ms + sesin kesilmesi).
  /// Yeni bir dosya katmanı ise diğer katmanlardan tamamen bağımsız: kendi
  /// player'ı var, ötekilere dokunmuyor.
  ///
  /// [autoPlay] true ise (mix o an ÇALIYORSA) yeni katman da hemen başlar —
  /// aksi hâlde kullanıcı sürgüyü görür ama hiçbir şey duymaz ve motoru suçlar.
  ///
  /// Dönüş: yüklendi mi. **false = katman EKLENMEDİ** (çağıran kullanıcıya
  /// söylemeli); id [failedAssetIds]'e yazılır ve [onAssetError] tetiklenir.
  Future<bool> addAsset(AssetLayer asset, {bool autoPlay = false}) async {
    AudioPlayer? player;
    try {
      player = _newPlayer();
      await player.setAudioSource(AudioSource.uri(assetAudioUri(asset.url)));
      // Dosya KENDİ BAŞINA dikişsiz döngülenmeli. Kuyruk→baş crossfade'ini
      // burada uygulayamayız (PCM'e erişim yok, bkz. asset_layer.dart) —
      // dosya dikişsiz değilse her sarmada tık duyulur. Kullanıcıya
      // `mixerAssetLoopNotice` ile söyleniyor.
      await player.setLoopMode(LoopMode.one);
      await player.setVolume(asset.gain.clamp(0.0, 1.0));
      _voices.add(_LayerVoice(asset.id, player));
      if (autoPlay) unawaited(player.play());
      return true;
    } catch (e) {
      // SESSİZ DÜŞÜŞ ama SESSİZ HATA DEĞİL (CLAUDE.md §4: boş catch yasak).
      // Yarım kurulmuş player sızmasın diye atılır.
      failedAssetIds.add(asset.id);
      // ignore: avoid_print
      print('MixPlayer: asset katmanı yüklenemedi (${asset.id}): $e');
      onAssetError?.call(asset.id, e);
      if (player != null) {
        try {
          await player.dispose();
        } catch (disposeError) {
          // ignore: avoid_print
          print('MixPlayer: düşen asset player kapatılamadı (${asset.id}): $disposeError');
        }
      }
      return false;
    }
  }

  /// Katmanı mikserden ÇIKARIR ve player'ını kapatır.
  ///
  /// Bilinmeyen id sessizce yok sayılır (henüz `prepare()` edilmemiş bir mikserde
  /// katman state'te vardır ama sesi yoktur — bu bir hata değil).
  ///
  /// **Kapatma şart:** yalnızca listeden düşürmek, sesi çalmaya devam eden ama
  /// artık sürgüsü olmayan bir player bırakırdı — kullanıcı "kaldırdım ama hâlâ
  /// duyuyorum" derdi.
  Future<void> removeVoice(String id) async {
    final index = _voices.indexWhere((v) => v.id == id);
    if (index < 0) return;
    final voice = _voices.removeAt(index);
    failedAssetIds.remove(id);
    try {
      await voice.player.dispose();
    } catch (e) {
      // ignore: avoid_print
      print('MixPlayer: katman kapatılamadı ($id): $e');
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

/// Asset katmanının kaynak adresini `Uri`'ye çevirir.
///
/// İki biçimi de kabul eder çünkü ikisi de gerçek yolda var:
/// - **Şemalı** (`https://...` presigned URL, `file:///...`) → olduğu gibi.
/// - **Şemasız yerel yol** (`/data/user/0/.../a.wav`, `C:\sesler\a.wav`) →
///   `Uri.file`. `Uri.parse` bunu şemasız bir "yol" olarak ayrıştırır ve
///   just_audio kaynağı ÇÖZEMEZ; Windows yolunda ise `C:` sürücü harfini ŞEMA
///   sanar (`scheme: 'c'`). İkisi de sessizce çalmayan bir katman üretirdi.
///
/// Public: `mix_player_asset_test.dart` bu ayrımı doğrudan kilitler.
Uri assetAudioUri(String url) {
  final parsed = Uri.tryParse(url);
  if (parsed != null && parsed.hasScheme && parsed.scheme.length > 1) return parsed;
  return Uri.file(url);
}

/// `unawaited` için minik yardımcı (dart:async'i tüm dosyaya taşımamak için).
void unawaited(Future<void> f) {
  // Hata YUTULMAZ (CLAUDE.md §4: boş catch yasak) — sessizce ölen ses en kötüsü.
  f.catchError((Object e, StackTrace s) {
    // ignore: avoid_print
    print('MixPlayer: çalma hatası: $e');
  });
}


/// `compute()` argümanı — isolate'e kapanış gönderilemez, sade veri gerekir.
///
/// **Public çünkü** hem `compute()` imzasında hem de testlerin enjekte ettiği
/// renderer imzasında görünüyor (private tip public API'de kullanılamaz).
class LoopRequest {
  const LoopRequest({
    required this.type,
    required this.id,
    required this.loopSeconds,
    required this.sampleRate,
    required this.seed,
  });

  final LayerSource type;
  final String id;
  final int loopSeconds;
  final int sampleRate;
  final int seed;
}

/// Üretim yolu: render'ı ayrı isolate'e taşır.
Future<Float32List> _computeLoop(LoopRequest r) => compute(renderLoopSync, r);

/// Testlerin de kullanabildiği SENKRON render (isolate giriş noktası).
Float32List renderLoopSync(LoopRequest r) => renderSeamlessLoop(
      MixSpec([MixLayer(id: r.id, type: r.type, gain: 1.0)]),
      loopSeconds: r.loopSeconds,
      sampleRate: r.sampleRate,
      seed: r.seed,
    );
