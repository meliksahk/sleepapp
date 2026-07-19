import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:nocta/core/audio_engine/dsp/mix_render.dart';
import 'package:nocta/core/audio_engine/mix_player.dart';

/// Asset (DOSYA) katmanı — cihazsız.
///
/// Kanıtlanan şey "dosya duyuluyor" DEĞİL (o cihaz işi). Kanıtlanan:
/// 1. dosya katmanı sentez katmanlarıyla AYNI player listesine giriyor
///    (→ sürgü/çal/duraklat tek koddan çalışıyor),
/// 2. dosya RENDER EDİLMİYOR (renderer'a hiç uğramıyor),
/// 3. bozuk/eksik dosya uygulamayı KIRMIYOR — mix eksik ama ÇALIYOR.
class _FakePlayer implements AudioPlayer {
  _FakePlayer({this.failOnSource = false});

  /// DOSYA kaynağı açılırken atsın mı — "dosya yok / ağ yok / bozuk kodek".
  ///
  /// Yalnızca [UriAudioSource] için atar, bellekteki sentez buffer'ı için DEĞİL.
  /// Gerçek dünyayı taklit ediyor: bellekten beslenen sentez katmanı açılmama
  /// riski taşımaz, ağdaki/diskteki dosya taşır. (İlk hâli her player'ı
  /// düşürüyordu; o zaman test, sentez katmanının çökmesini ölçüyordu — yani
  /// asset yolunu hiç sınamıyordu.)
  final bool failOnSource;

  AudioSource? source;
  LoopMode? capturedLoopMode;
  double lastVolume = -1;
  bool disposed = false;

  @override
  bool playing = false;

  @override
  Future<Duration?> setAudioSource(
    AudioSource source, {
    bool preload = true,
    int? initialIndex,
    Duration? initialPosition,
  }) async {
    if (failOnSource && source is UriAudioSource) {
      throw PlayerException(404, 'kaynak açılamadı (test)', null);
    }
    this.source = source;
    return Duration.zero;
  }

  @override
  Future<void> setVolume(double volume) async {
    lastVolume = volume;
  }

  @override
  Future<void> setLoopMode(LoopMode mode) async {
    capturedLoopMode = mode;
  }

  @override
  Future<void> play() async {
    playing = true;
  }

  @override
  Future<void> pause() async {
    playing = false;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const asset = AssetLayer(
    id: 'asset-1',
    title: 'Pad + Fire (demo)',
    url: 'https://minio.test/audio-assets/demo/pad-fire-demo.wav',
    gain: 0.4,
  );

  late List<_FakePlayer> created;
  late List<String> renderedIds;

  MixPlayer build({
    bool failAssets = false,
    void Function(String, Object)? onAssetError,
  }) {
    created = [];
    renderedIds = [];
    return MixPlayer(
      loopSeconds: 1,
      sampleRate: 8000,
      onAssetError: onAssetError,
      loopRenderer: (r) async {
        renderedIds.add(r.id);
        return renderLoopSync(r);
      },
      playerFactory: () {
        final p = _FakePlayer(failOnSource: failAssets);
        created.add(p);
        return p;
      },
    );
  }

  test('asset katmanı player listesine girer ve RENDER EDİLMEZ', () async {
    final player = build();
    await player.load(
      const MixSpec(
        <MixLayer>[MixLayer(id: 'brown', type: LayerSource.brown, gain: 0.3)],
        assets: <AssetLayer>[asset],
      ),
    );

    expect(player.voiceCount, 2, reason: 'sentez + dosya, tek listede');
    // Renderer YALNIZCA sentez katmanı için çağrıldı. Asset render edilseydi
    // burada 'asset-1' de olurdu — tam olarak engellemeye çalıştığımız hata.
    expect(renderedIds, <String>['brown']);
    expect(player.failedAssetIds, isEmpty);
  });

  test('asset kaynağı LoopMode.one ile ve doğru kazançla yüklenir', () async {
    final player = build();
    await player.load(const MixSpec(<MixLayer>[], assets: <AssetLayer>[asset]));

    expect(created, hasLength(1));
    expect(created.single.capturedLoopMode, LoopMode.one);
    expect(created.single.lastVolume, closeTo(0.4, 1e-9));
    expect(created.single.source, isA<UriAudioSource>());
    expect(
      (created.single.source! as UriAudioSource).uri.toString(),
      asset.url,
    );
  });

  test('sürgü asset katmanında da çalışır (setLayerGain id ile eşleşir)', () async {
    final player = build();
    await player.load(const MixSpec(<MixLayer>[], assets: <AssetLayer>[asset]));

    await player.setLayerGain('asset-1', 0.9);
    expect(created.single.lastVolume, closeTo(0.9, 1e-9));
  });

  test('BOZUK dosya mix’i çökertmez: sentez katmanı çalmaya devam eder', () async {
    final errors = <String>[];
    final player = build(
      failAssets: true,
      onAssetError: (id, _) => errors.add(id),
    );

    // Atmıyor — kanıt: bu satır bir istisna ile düşmüyor.
    await player.load(
      const MixSpec(
        <MixLayer>[MixLayer(id: 'pink', type: LayerSource.pink, gain: 0.3)],
        assets: <AssetLayer>[asset],
      ),
    );

    expect(player.voiceCount, 1, reason: 'yalnızca sentez katmanı ayakta');
    expect(player.failedAssetIds, <String>['asset-1']);
    expect(errors, <String>['asset-1'], reason: 'hata YUTULMADI, bildirildi');
    // Yarım kurulan asset player'ı sızmamalı (sentez player'ı ayakta kalır).
    expect(created, hasLength(2));
    expect(created.last.disposed, isTrue, reason: 'düşen asset player kapatıldı');
    expect(created.first.disposed, isFalse, reason: 'sentez katmanı ayakta');
  });

  test('yeniden load, önceki düşen asset kaydını temizler', () async {
    final player = build(failAssets: true);
    await player.load(const MixSpec(<MixLayer>[], assets: <AssetLayer>[asset]));
    expect(player.failedAssetIds, hasLength(1));

    final ok = build();
    await ok.load(const MixSpec(<MixLayer>[], assets: <AssetLayer>[asset]));
    expect(ok.failedAssetIds, isEmpty);
  });

  group('assetAudioUri', () {
    test('http(s) URL olduğu gibi korunur', () {
      expect(
        assetAudioUri('https://minio.test/a.wav').toString(),
        'https://minio.test/a.wav',
      );
    });

    test('file:// şeması korunur', () {
      expect(assetAudioUri('file:///tmp/a.wav').scheme, 'file');
    });

    test('şemasız POSIX yolu file: olur', () {
      expect(assetAudioUri('/data/user/0/a.wav').scheme, 'file');
    });

    test('Windows sürücü harfi ŞEMA sanılmaz (C: → file)', () {
      // `Uri.parse('C:\\ses\\a.wav')` şemayı 'c' olarak okur; just_audio bunu
      // çözemez. Tek harfli şema bu yüzden yol sayılıyor.
      final uri = assetAudioUri(r'C:\ses\a.wav');
      expect(uri.scheme, 'file');
      expect(uri.toString(), contains('a.wav'));
    });
  });
}
