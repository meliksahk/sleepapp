import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/core/audio_engine/dsp/generative_chain.dart';
import 'package:nocta/core/audio_engine/dsp/mix_render.dart';
import 'package:nocta/core/audio_engine/dsp/wav_encoder.dart';
import 'package:nocta/core/audio_engine/generative_audio_source.dart';

/// Çalara giden BAYTLAR doğru mu — akış gerçekten bitmiyor mu.
///
/// Burada ses kalitesi ölçülmez (o `generative_chain_test.dart`'ta); ölçülen
/// şey kabın doğruluğu: başlık, süreklilik, durdurulabilirlik.
void main() {
  const sampleRate = 8000;

  GenerativeAudioSource build({int segmentSeconds = 1}) =>
      GenerativeAudioSource(
        chain: LayerSegmentChain(
          type: LayerSource.brown,
          seed: 3,
          segmentSeconds: segmentSeconds,
          sampleRate: sampleRate,
        ),
        sampleRate: sampleRate,
        render: (r) async => renderSegmentRequest(r),
      );

  test('başlık: uzunluğu BİLİNMEYEN WAV (0xFFFFFFFF) ve doğru örnekleme hızı', () {
    final h = wavStreamHeader(sampleRate: sampleRate);
    expect(h, hasLength(wavHeaderBytes));
    final view = ByteData.sublistView(Uint8List.fromList(h));
    expect(String.fromCharCodes(h.sublist(0, 4)), 'RIFF');
    expect(view.getUint32(4, Endian.little), 0xFFFFFFFF);
    expect(String.fromCharCodes(h.sublist(8, 12)), 'WAVE');
    expect(view.getUint32(24, Endian.little), sampleRate);
    expect(String.fromCharCodes(h.sublist(36, 40)), 'data');
    expect(view.getUint32(40, Endian.little), 0xFFFFFFFF);
  });

  test('ÇEKİRDEK: akış BİTMİYOR — istendikçe yeni segment üretiyor', () async {
    final source = build();
    // ignore: experimental_member_use
    final res = await source.request();
    expect(res.sourceLength, isNull, reason: 'uzunluk bilinmiyor olmalı');
    expect(res.contentType, 'audio/wav');

    final chunks = <List<int>>[];
    // İlk 4 parçayı al ve DURDUR — sonsuz akışı sonlu bir testte tüketmenin yolu.
    await for (final chunk in res.stream) {
      chunks.add(chunk);
      if (chunks.length == 4) break;
    }

    expect(chunks.first, hasLength(wavHeaderBytes), reason: 'ilk parça başlık');
    // Her segment: 1 sn @8 kHz, 16-bit mono = 16000 bayt.
    for (final c in chunks.skip(1)) {
      expect(c, hasLength(sampleRate * 2));
    }
  });

  test('ardışık segmentler farklı baytlar taşıyor (döngü değil)', () async {
    final source = build();
    // ignore: experimental_member_use
    final res = await source.request();

    final segs = <List<int>>[];
    await for (final chunk in res.stream) {
      if (chunk.length == wavHeaderBytes) continue; // başlık
      segs.add(chunk);
      if (segs.length == 3) break;
    }

    expect(segs[0], isNot(orderedEquals(segs[1])));
    expect(segs[1], isNot(orderedEquals(segs[2])));
  });

  test('offset > 0 istenirse başlık TEKRAR gönderilmez', () async {
    final source = build();
    // ignore: experimental_member_use
    final res = await source.request(1024);
    final first = await res.stream.first;
    expect(first, hasLength(sampleRate * 2), reason: 'başlık değil, ses olmalı');
  });

  test('close(): üretim durur (ölü zincir CPU yakmaz)', () async {
    final source = build();
    // ignore: experimental_member_use
    final res = await source.request();

    var produced = 0;
    await for (final chunk in res.stream) {
      if (chunk.length == wavHeaderBytes) continue;
      produced++;
      if (produced == 2) source.close();
      if (produced > 5) fail('close() sonrası üretim sürdü');
    }
    expect(produced, 2, reason: 'close çağrıldıktan sonra akış kapanmalı');
  });
}
