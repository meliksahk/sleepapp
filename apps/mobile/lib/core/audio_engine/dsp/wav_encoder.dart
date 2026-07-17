/// Float32 PCM → WAV (RIFF, 16-bit, mono) baytları.
///
/// **NEDEN VAR:** `renderMix` Float32 örnekler üretiyordu ve zincir orada BİTİYORDU —
/// üretilen ses hiçbir zaman çalınmadı (#95'ten beri ölü kod). Eksik halka native ses
/// grafı DEĞİL, sadece şu: örnekleri her ses paketinin anladığı bir kabın içine koymak.
/// Bu dosya o kap. ~60 satır ve bayt seviyesinde doğrulanabilir.
///
/// **16-bit neden:** WAV float32 (IEEE) de taşıyabilir ama 16-bit PCM her yerde çalar;
/// float32 WAV'ı bazı çözücüler reddeder. Uyku sesi için 16-bit (96 dB dinamik aralık)
/// fazlasıyla yeterli — kayıp, tabandaki gürültünün çok altında.
///
/// **Mono neden:** katmanlar bugün mono üretiliyor (`renderMix` tek kanal döner).
/// Stereo/uzamsallaştırma native motorun işi (docs/04).
library;

import 'dart:typed_data';

/// RIFF başlığı sabit 44 bayt (fmt 16 + standart chunk'lar).
const int wavHeaderBytes = 44;

/// [samples] (Float32, [-1, 1]) → çalınmaya hazır WAV baytları.
///
/// [-1, 1] dışındaki örnekler **kırpılır** (sarmalanmaz): int16'ya taşan bir örnek
/// sarmalanırsa +1.2 değeri en negatif değere döner ve **sesli bir tık** olur.
/// Kırpma bozar ama tık kadar bozmaz. `renderMix` zaten kırpma raporluyor (#95).
Uint8List encodeWav(
  Float32List samples, {
  int sampleRate = 48000,
  int channels = 1,
}) {
  assert(sampleRate > 0);
  assert(channels > 0);

  const bitsPerSample = 16;
  final bytesPerSample = bitsPerSample ~/ 8;
  final dataBytes = samples.length * bytesPerSample;

  final out = ByteData(wavHeaderBytes + dataBytes);
  var pos = 0;

  void writeAscii(String s) {
    for (final c in s.codeUnits) {
      out.setUint8(pos++, c);
    }
  }

  void writeUint32(int v) {
    out.setUint32(pos, v, Endian.little);
    pos += 4;
  }

  void writeUint16(int v) {
    out.setUint16(pos, v, Endian.little);
    pos += 2;
  }

  // RIFF chunk. Boyut alanı "bu alandan SONRAKİ bayt sayısı" = toplam - 8.
  writeAscii('RIFF');
  writeUint32(wavHeaderBytes - 8 + dataBytes);
  writeAscii('WAVE');

  // fmt alt-chunk'ı.
  writeAscii('fmt ');
  writeUint32(16); // PCM için fmt gövdesi 16 bayt
  writeUint16(1); // 1 = PCM (sıkıştırmasız)
  writeUint16(channels);
  writeUint32(sampleRate);
  writeUint32(sampleRate * channels * bytesPerSample); // byteRate
  writeUint16(channels * bytesPerSample); // blockAlign
  writeUint16(bitsPerSample);

  // data alt-chunk'ı.
  writeAscii('data');
  writeUint32(dataBytes);

  for (var i = 0; i < samples.length; i++) {
    out.setInt16(pos, _toInt16(samples[i]), Endian.little);
    pos += 2;
  }

  return out.buffer.asUint8List();
}

/// Float [-1, 1] → int16.
///
/// **32767 ile çarpılır, 32768 ile DEĞİL:** -1.0 → -32767 (min olan -32768 değil).
/// Simetriyi korumak, -1.0'ın sessizce en uç değere yapışmasını önler; asimetrik
/// ölçekleme DC ofseti sokar ve tam da #95/#96'da temizlediğimiz şey buydu.
int _toInt16(double sample) {
  if (sample.isNaN) return 0; // NaN sessizliğe düşer; int16'ya çevrilirse çöp olurdu
  final clamped = sample.clamp(-1.0, 1.0);
  return (clamped * 32767).round();
}
