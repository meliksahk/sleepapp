import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:nocta/core/audio_engine/dsp/mix_render.dart';
import 'package:nocta/core/audio_engine/dsp/segment_chain.dart';
import 'package:nocta/core/audio_engine/mix_player.dart';

import 'fake_playlist_player.dart';

/// `MixPlayer`'ın sonsuz uzatma yolu: çalma listesi nasıl beslenir.
///
/// Kanıtlanan: tohumla değişen katman listeyle çalınır, sabit katman tek döngüde
/// kalır; parça geçişinde çalınan parça listeden çıkarılıp baytları bırakılır ve
/// sıradaki parça önceki parçanın kuyruğuyla üretilir; kapatılan katman üretmeye
/// devam etmez; üretim patlarsa ses kesilmez ve bir sonraki geçişte yeniden
/// denenir.
///
/// **Kanıtlanmayan:** gerçek oynatıcının parçaları boşluksuz birleştirmesi
/// (just_audio bunu Android ve iOS için belgeliyor) ve gece boyu bellek. İkisi
/// de cihazda ölçülecek.
class _FakePlayer with FakePlaylistPlayer implements AudioPlayer {
  AudioSource? initialSource;
  LoopMode? capturedLoopMode;
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
    initialSource = source;
    return Duration.zero;
  }

  @override
  Future<void> setLoopMode(LoopMode mode) async => capturedLoopMode = mode;
  @override
  Future<void> setVolume(double volume) async {}
  @override
  Future<void> play() async => playing = true;
  @override
  Future<void> pause() async => playing = false;
  @override
  Future<void> dispose() async => disposed = true;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// Birkaç olay döngüsü turu: senkron üretici mikro görevlerde biter.
Future<void> _settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late List<_FakePlayer> players;
  late List<SegmentRequest> segmentRequests;
  late List<LoopRequest> loopRequests;
  late bool Function(SegmentRequest r) failWhen;

  MixPlayer build({bool extendForever = true}) {
    players = [];
    segmentRequests = [];
    loopRequests = [];
    failWhen = (_) => false;
    return MixPlayer(
      loopSeconds: 1,
      sampleRate: 8000,
      extendForever: extendForever,
      loopRenderer: (r) async {
        loopRequests.add(r);
        return renderLoopSync(r);
      },
      segmentRenderer: (r) async {
        segmentRequests.add(r);
        if (failWhen(r)) throw StateError('üretim patladı (test)');
        return renderSegmentSync(r);
      },
      playerFactory: () {
        final p = _FakePlayer();
        players.add(p);
        return p;
      },
    );
  }

  const brown = MixLayer(id: 'brown', type: LayerSource.brown, gain: 0.4);
  const tone = MixLayer(id: 'tone', type: LayerSource.tone, gain: 0.3, frequencyHz: 200);

  test('ÇEKİRDEK: tohumla değişen katman listeyle, sabit katman tek döngüyle çalınır', () async {
    final player = build();
    await player.load(const MixSpec(<MixLayer>[brown, tone]));
    await _settle();

    final b = players[0], t = players[1];
    expect(b.capturedLoopMode, LoopMode.all, reason: 'liste bitmeden parça gelmezse döndürmeli');
    expect(b.initialSource, isA<BytesAudioSource>());
    expect(b.appendedSources, hasLength(1), reason: 'ikinci parça hazırlanıp eklenmeli');
    expect(segmentRequests.map((r) => r.index), <int>[0, 1]);

    expect(t.capturedLoopMode, LoopMode.one, reason: 'sabit ton yeniden üretilmez');
    expect(t.appendedSources, isEmpty);
    expect(loopRequests.single.type, LayerSource.tone);
  });

  test('ÇEKİRDEK: parça geçişinde çalınan çıkarılır, bırakılır; sıradaki üretilir', () async {
    final player = build();
    await player.load(const MixSpec(<MixLayer>[brown]));
    await _settle();
    final b = players.single;
    final first = b.initialSource! as BytesAudioSource;

    b.emitCurrentIndex(1); // çalar ikinci parçaya geçti
    await _settle();

    expect(b.removedIndices, <int>[0], reason: 'çalınan parça listeden çıkmalı');
    await expectLater(first.request(), throwsStateError, reason: 'çalınan parçanın baytları bırakılmalı');
    expect(b.appendedSources, hasLength(2), reason: 'üçüncü parça eklenmeli');
    final third = segmentRequests.last;
    expect(third.index, 2);
    expect(third.prevTail, isNotNull, reason: 'dikiş önceki parçanın kuyruğuyla yapılır');
    expect(third.refRms, isNotNull, reason: 'seviye ilk parçaya hizalanır');

    // just_audio çıkarmadan sonra indeksi 0'a kaydırır; bu yeni bir geçiş değil.
    b.emitCurrentIndex(0);
    await _settle();
    expect(b.appendedSources, hasLength(2), reason: 'kaydırma olayı fazladan parça üretmemeli');
  });

  test('uzun gece: her geçişte liste iki parçada kalır', () async {
    final player = build();
    await player.load(const MixSpec(<MixLayer>[brown]));
    await _settle();
    final b = players.single;
    for (var k = 0; k < 6; k++) {
      b.emitCurrentIndex(1);
      await _settle();
      b.emitCurrentIndex(0);
      await _settle();
    }
    expect(b.removedIndices, hasLength(6));
    expect(b.appendedSources, hasLength(7), reason: 'her çalınan parça için tam bir yeni parça');
    expect(segmentRequests.map((r) => r.index), <int>[0, 1, 2, 3, 4, 5, 6, 7]);
  });

  test('kapatılan katman üretmeye devam etmez', () async {
    final player = build();
    await player.load(const MixSpec(<MixLayer>[brown]));
    await _settle();
    final b = players.single;

    await player.removeVoice('brown');
    b.emitCurrentIndex(1);
    await _settle();

    expect(b.disposed, isTrue);
    expect(b.appendedSources, hasLength(1), reason: 'kapatıldıktan sonra parça eklenmemeli');
    expect(segmentRequests, hasLength(2));
  });

  test('üretim patlarsa ses kesilmez ve sonraki geçişte yeniden denenir', () async {
    final player = build();
    await player.load(const MixSpec(<MixLayer>[brown]));
    await _settle();
    final b = players.single;

    var failures = 0;
    failWhen = (r) => r.index == 2 && failures++ == 0;
    b.emitCurrentIndex(1);
    await _settle();
    expect(b.appendedSources, hasLength(1), reason: 'patlayan parça eklenmez; çalar listeyi döndürür');
    expect(b.capturedLoopMode, LoopMode.all);

    b.emitCurrentIndex(0); // çalar listeyi döndürdü
    await _settle();
    expect(b.appendedSources, hasLength(2), reason: 'bir sonraki olayda yeniden denenmeli');
    expect(segmentRequests.where((r) => r.index == 2), hasLength(2));
  });

  test('katmanlar aynı anda geçse de parçalar SIRAYLA üretilir (bellek sıçraması yok)', () async {
    var inFlight = 0, maxInFlight = 0;
    players = [];
    final player = MixPlayer(
      loopSeconds: 1,
      sampleRate: 8000,
      loopRenderer: (r) async => renderLoopSync(r),
      segmentRenderer: (r) async {
        inFlight++;
        if (inFlight > maxInFlight) maxInFlight = inFlight;
        await Future<void>.delayed(Duration.zero); // gerçek üretim gibi zaman alsın
        final out = renderSegmentSync(r);
        inFlight--;
        return out;
      },
      playerFactory: () {
        final p = _FakePlayer();
        players.add(p);
        return p;
      },
    );
    await player.load(const MixSpec(<MixLayer>[
      brown,
      MixLayer(id: 'pink', type: LayerSource.pink, gain: 0.2),
      MixLayer(id: 'rain', type: LayerSource.rain, gain: 0.2),
    ]));
    await _settle();
    for (final p in players) {
      p.emitCurrentIndex(1); // üç katman aynı anda sıradaki parçaya geçti
    }
    await _settle();
    expect(players.every((p) => p.appendedSources.length == 2), isTrue);
    expect(maxInFlight, 1, reason: 'aynı anda birden çok parça üretildi');
  });

  test('kaçış yolu: extendForever false eski davranışa döner', () async {
    final player = build(extendForever: false);
    await player.load(const MixSpec(<MixLayer>[brown]));
    await _settle();
    final b = players.single;
    expect(b.capturedLoopMode, LoopMode.one);
    expect(b.appendedSources, isEmpty);
    expect(segmentRequests, isEmpty);
  });

  test('ÇEKİRDEK: melodi ayarları canlı eklenen katmanın üretimine ulaşır', () async {
    final player = build();
    await player.load(const MixSpec(<MixLayer>[tone]));
    await player.addSynthLayer(const MixLayer(
      id: 'arp',
      type: LayerSource.arpeggio,
      gain: 0.3,
      rootSemi: 7,
      waveform: 'triangle',
      tempoScale: 1.5,
      patternIdx: 2,
    ));
    await player.addSynthLayer(const MixLayer(
      id: 'chords',
      type: LayerSource.chords,
      gain: 0.3,
      rootSemi: 5,
      waveform: 'saw',
      tempoScale: 2.0,
      patternIdx: 3,
    ));
    await _settle();

    final arp = segmentRequests.firstWhere((r) => r.layer.id == 'arp').layer;
    expect(<Object?>[arp.rootSemi, arp.waveform, arp.tempoScale, arp.patternIdx], <Object?>[7, 'triangle', 1.5, 2]);
    final chords = loopRequests.firstWhere((r) => r.id == 'chords');
    expect(
      <Object?>[chords.rootSemi, chords.waveform, chords.tempoScale, chords.patternIdx],
      <Object?>[5, 'saw', 2.0, 3],
    );
  });
}
