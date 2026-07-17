/// Gece dB zarfı — **eşik ayarı için fixture** (docs/04 §120).
///
/// ## Neden var
///
/// `AcousticEventDetector`'ın eşikleri **gerçek gece kayıtlarıyla ayarlanmadı** ve
/// ayarlanamıyor, çünkü ortada veri yok: kayıt bittiğinde geriye yalnızca bir SAYI
/// kalıyor (olay adedi). "12 olay saydım" bir eşiğin doğru olup olmadığını söylemez.
/// docs/04 §120 tam olarak bu fixture'ları istiyor; bu sınıf onları üretir.
///
/// ## Gizlilik: bu HAM SES DEĞİL ve konuşmayı geri getiremez
///
/// Saniyede **üç sayı** tutulur (min/ortalama/maks dBFS). Konuşma anlaşılırlığı
/// saniyede binlerce örnek ister; 1 Hz'lik bir genlik zarfından kelime çıkarmak
/// fiziksel olarak mümkün değil — "biri konuştu" bile denemez, yalnızca "ses vardı".
/// CLAUDE.md §6 ham sesin yüklenmesini yasaklar; bu, ölçümün kendisi.
///
/// Yine de **kullanıcının kendi cihazında kalır** ve yalnızca kendisi paylaşırsa
/// çıkar (otomatik gönderim YOK).
library;

import 'db_envelope.dart';

/// Bir saniyelik özet.
class EnvelopeSecond {
  const EnvelopeSecond({
    required this.second,
    required this.minDb,
    required this.meanDb,
    required this.maxDb,
    required this.frames,
  });

  final int second;
  final double minDb;
  final double meanDb;
  final double maxDb;
  final int frames;
}

/// Çerçeve dB'lerini saniyelik özetlere indirger.
///
/// **Neden min/ortalama/maks, neden tek sayı değil:** taban (oda sessizliği) ancak
/// min/ortalama ile görülür, olaylar ise maks'ta yaşar. Yalnızca ortalama tutsaydık
/// kısa bir olay ortalamada kaybolur ve eşik ayarı imkânsızlaşırdı.
class EnvelopeLog {
  EnvelopeLog({required this.sampleRate, required this.frameSamples})
      : assert(sampleRate > 0),
        assert(frameSamples > 0);

  final int sampleRate;
  final int frameSamples;

  /// Saniye başına kaç çerçeve gelir (16 kHz / 256 örnek ≈ 62.5).
  double get framesPerSecond => sampleRate / frameSamples;

  final List<EnvelopeSecond> _seconds = [];
  List<EnvelopeSecond> get seconds => List.unmodifiable(_seconds);

  int _frameIndex = 0;
  int _bucketStart = 0;
  double _min = double.infinity;
  double _max = double.negativeInfinity;
  double _sum = 0;
  int _count = 0;

  /// **BELLEK TAVANI:** 8 saatlik gece ≈ 28.800 saniye ≈ 28.800 kayıt (~1 MB).
  /// Sınırsız bırakmak, uyuyakalan bir kullanıcıda belleği şişirirdi. Tavan aşılırsa
  /// yeni saniyeler SESSİZCE düşmez — [truncated] işaretlenir (bkz. `toCsv`).
  static const int maxSeconds = 36000; // 10 saat

  bool _truncated = false;
  bool get truncated => _truncated;

  void addFrame(double db) {
    final second = (_frameIndex / framesPerSecond).floor();
    if (second != _bucketStart && _count > 0) {
      _flush();
      _bucketStart = second;
    }
    if (db < _min) _min = db;
    if (db > _max) _max = db;
    _sum += db;
    _count++;
    _frameIndex++;
  }

  /// Açık kalan saniyeyi kapatır — kayıt saniye ortasında bittiyse o veri kaybolmasın.
  void finish() {
    if (_count > 0) _flush();
  }

  void _flush() {
    if (_seconds.length >= maxSeconds) {
      _truncated = true;
    } else {
      _seconds.add(
        EnvelopeSecond(
          second: _bucketStart,
          minDb: _min,
          meanDb: _sum / _count,
          maxDb: _max,
          frames: _count,
        ),
      );
    }
    _min = double.infinity;
    _max = double.negativeInfinity;
    _sum = 0;
    _count = 0;
  }

  /// Fixture biçimi: CSV. Neden CSV — herhangi bir tabloya/scripte doğrudan girer;
  /// JSON aynı veriyi ~3× yer kaplardı ve okunması zorlaşırdı.
  String toCsv() {
    final b = StringBuffer()
      ..writeln('# NOCTA gece dB zarfı — eşik ayarı fixture\'ı (docs/04 §120)')
      ..writeln('# HAM SES DEĞİL: saniyede 3 sayı; konuşma geri getirilemez.')
      ..writeln('# sessizlik ≈ ${silenceDbfs.toStringAsFixed(0)} dBFS')
      ..writeln('# sampleRate=$sampleRate frameSamples=$frameSamples '
          'framesPerSecond=${framesPerSecond.toStringAsFixed(2)}');
    if (_truncated) {
      // Sessiz kırpma YASAK: eksik fixture, yanlış eşik demektir.
      b.writeln('# UYARI: $maxSeconds saniye tavanı aşıldı, sonrası KAYDEDİLMEDİ.');
    }
    b.writeln('second,minDb,meanDb,maxDb,frames');
    for (final s in _seconds) {
      b.writeln('${s.second},${s.minDb.toStringAsFixed(2)},'
          '${s.meanDb.toStringAsFixed(2)},${s.maxDb.toStringAsFixed(2)},${s.frames}');
    }
    return b.toString();
  }
}
