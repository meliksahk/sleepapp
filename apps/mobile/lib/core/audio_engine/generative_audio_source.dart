/// **Sonsuz ses kaynağı** — çalara bitmeyen bir WAV akışı sunar (F2).
///
/// ## Neden akış, neden çalma listesi değil
///
/// Alternatif, her segmenti ayrı bir parça olarak çalar kuyruğuna eklemekti
/// (`setAudioSources` + `addAudioSources`). Bu, parça sınırında boşluk/tık
/// riskini PLATFORMA bırakır ve kuyruk yönetimi (indeks takibi, tüketilenleri
/// silme) mikserin içine sızardı. Akışta ise sınır diye bir şey yok: çalar tek
/// bir "dosya" görür, biz o dosyanın baytlarını üretmeye devam ederiz.
///
/// ## Geri basınç (back-pressure) bedava
///
/// Baytlar bir `async*` üreteciyle veriliyor. Çalar tamponunu doldurup okumayı
/// yavaşlattığında `yield` orada bekler → üretim de yavaşlar. Böylece bellek
/// çaların tampon politikasıyla sınırlı kalır; bizim ayrıca kuyruk boyu
/// kollamamız gerekmez.
///
/// ## ⚠️ CİHAZDA DOĞRULANMADI
///
/// Bu yol birim testleriyle (bayt akışı, başlık, segment farklılığı) kapsandı
/// ama GERÇEK CİHAZDA kulakla dinlenmedi. Bilinen riskler: (a) uzunluğu
/// bilinmeyen WAV başlığını çözücünün kabulü, (b) uzun akışta çaların yeniden
/// arama (seek) yapması. Kırılırsa kaçış yolu `MixPlayer(extendForever: false)`
/// — eski, kanıtlanmış döngü yolu olduğu gibi duruyor.
library;

import 'dart:typed_data';

import 'package:just_audio/just_audio.dart';

import 'dsp/generative_chain.dart';
import 'dsp/wav_encoder.dart';

/// Segmenti sese çeviren fonksiyon (üretimde `compute` ile ayrı isolate).
typedef SegmentRenderer = Future<Float32List> Function(SegmentRequest request);

// ignore: experimental_member_use
class GenerativeAudioSource extends StreamAudioSource {
  GenerativeAudioSource({
    required this.chain,
    required this.sampleRate,
    required this.render,
  });

  final LayerSegmentChain chain;
  final int sampleRate;
  final SegmentRenderer render;

  /// Akış kesildi mi (katman kaldırıldı / mikser kapandı).
  bool _closed = false;

  void close() => _closed = true;

  @override
  // ignore: experimental_member_use
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final from = start ?? 0;
    // ignore: experimental_member_use
    return StreamAudioResponse(
      // Uzunluk BİLİNMİYOR — akış kullanıcı durdurana kadar sürer.
      sourceLength: null,
      contentLength: null,
      offset: from,
      stream: _bytes(from),
      contentType: 'audio/wav',
    );
  }

  /// Baytlar: başlık (yalnız baştan okunuyorsa) + sonsuz PCM.
  ///
  /// **Arama (seek) desteklenmez ve bu bilinçli:** ambiyans akışında geri
  /// sarılacak bir "an" yok; zincirin durumu da geriye alınamaz (segment *k*'nin
  /// dikişi *k−1*'in kuyruğuna bağlı). Sıfırdan farklı bir başlangıç istenirse
  /// akış BULUNDUĞU yerden devam eder — çalar için bu, tamponun tazelenmesidir.
  Stream<List<int>> _bytes(int from) async* {
    if (from < wavHeaderBytes) {
      yield wavStreamHeader(sampleRate: sampleRate);
    }
    while (!_closed) {
      final full = await render(chain.planNext());
      if (_closed) return;
      yield encodePcm16(chain.accept(full));
    }
  }
}
