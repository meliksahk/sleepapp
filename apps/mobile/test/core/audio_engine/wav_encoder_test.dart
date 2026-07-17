import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/core/audio_engine/dsp/wav_encoder.dart';

/// WAV kodlayıcı — BAYT SEVİYESİNDE doğrulama.
///
/// Burada "çalıyor mu" test edilemez (o emülatör/cihaz işi). Test edilebilen şey
/// **kabın doğruluğu**: bir bayt kayarsa ses paketi dosyayı ya reddeder ya da gürültü
/// olarak çalar. Beklentiler RIFF/WAVE spesifikasyonundan alındı — benim uydurduğum
/// değerler değil.
void main() {
  Float32List sig(List<double> v) => Float32List.fromList(v);

  /// Little-endian okuma yardımcıları (kodlayıcının kendi kodunu KULLANMAZ —
  /// aynı hatayı iki kez yapıp testi kandırmamak için bağımsız okuma).
  int u32(Uint8List b, int i) =>
      b[i] | (b[i + 1] << 8) | (b[i + 2] << 16) | (b[i + 3] << 24);
  int u16(Uint8List b, int i) => b[i] | (b[i + 1] << 8);
  String ascii(Uint8List b, int i, int n) =>
      String.fromCharCodes(b.sublist(i, i + n));
  int i16(Uint8List b, int i) =>
      ByteData.sublistView(b, i, i + 2).getInt16(0, Endian.little);

  group('RIFF başlığı (spesifikasyona göre)', () {
    test('sihirli değerler doğru yerlerde', () {
      final w = encodeWav(sig([0.0, 0.0]));

      expect(ascii(w, 0, 4), 'RIFF');
      expect(ascii(w, 8, 4), 'WAVE');
      expect(ascii(w, 12, 4), 'fmt ');
      expect(ascii(w, 36, 4), 'data');
    });

    test('RIFF boyutu = toplam - 8 (bu alandan SONRAKİ baytlar)', () {
      final w = encodeWav(sig([0.0, 0.0, 0.0]));
      expect(u32(w, 4), w.length - 8);
    });

    test('fmt: PCM(1), mono, 48kHz, 16-bit', () {
      final w = encodeWav(sig([0.0]));

      expect(u32(w, 16), 16, reason: 'PCM fmt gövdesi 16 bayt');
      expect(u16(w, 20), 1, reason: '1 = PCM sıkıştırmasız');
      expect(u16(w, 22), 1, reason: 'mono');
      expect(u32(w, 24), 48000);
      expect(u16(w, 34), 16, reason: 'bitsPerSample');
    });

    test('byteRate ve blockAlign türetilmiş alanlar — tutarlı olmalı', () {
      // Çözücüler bu alanlara GÜVENİR; tutmazsa ses hızlı/yavaş çalar.
      final w = encodeWav(sig([0.0]), sampleRate: 44100);
      expect(u32(w, 28), 44100 * 1 * 2, reason: 'byteRate = rate*kanal*baytPerSample');
      expect(u16(w, 32), 1 * 2, reason: 'blockAlign = kanal*baytPerSample');
    });

    test('data boyutu = örnek sayısı × 2', () {
      final w = encodeWav(sig([0.1, 0.2, 0.3, 0.4, 0.5]));
      expect(u32(w, 40), 5 * 2);
      expect(w.length, wavHeaderBytes + 5 * 2);
    });

    test('sampleRate parametresi başlığa yansır', () {
      expect(u32(encodeWav(sig([0.0]), sampleRate: 22050), 24), 22050);
    });
  });

  group('örnek dönüşümü', () {
    test('0.0 → 0 (sessizlik gerçekten sessiz)', () {
      final w = encodeWav(sig([0.0]));
      expect(i16(w, 44), 0);
    });

    test('+1.0 → 32767, -1.0 → -32767 (SİMETRİK)', () {
      final w = encodeWav(sig([1.0, -1.0]));
      expect(i16(w, 44), 32767);
      // -32768 DEĞİL: asimetrik ölçekleme DC ofseti sokar (#95/#96'da temizlenen şey).
      expect(i16(w, 46), -32767);
    });

    test('ÇEKİRDEK: [-1,1] dışı KIRPILIR, sarmalanmaz', () {
      // Sarmalama olsaydı +1.2 en negatif değere döner ve SESLİ BİR TIK olurdu.
      final w = encodeWav(sig([1.5, -1.5, 2.0, -99.0]));
      expect(i16(w, 44), 32767);
      expect(i16(w, 46), -32767);
      expect(i16(w, 48), 32767);
      expect(i16(w, 50), -32767);
    });

    test('NaN sessizliğe düşer (çöp örnek üretmez)', () {
      final w = encodeWav(sig([double.nan]));
      expect(i16(w, 44), 0);
    });

    test('sonsuz değerler kırpılır', () {
      final w = encodeWav(sig([double.infinity, double.negativeInfinity]));
      expect(i16(w, 44), 32767);
      expect(i16(w, 46), -32767);
    });

    test('yarım genlik ≈ yarım int16 (ölçek doğrusal)', () {
      final w = encodeWav(sig([0.5, -0.5]));
      expect(i16(w, 44), closeTo(16384, 2));
      expect(i16(w, 46), closeTo(-16384, 2));
    });

    test('örnek SIRASI korunur (kanallar/örnekler karışmaz)', () {
      final w = encodeWav(sig([0.1, 0.2, 0.3]));
      expect(i16(w, 44), lessThan(i16(w, 46)));
      expect(i16(w, 46), lessThan(i16(w, 48)));
    });
  });

  group('sınır durumları', () {
    test('boş sinyal → geçerli, veri içermeyen WAV', () {
      // Çökmemeli: sıfır uzunluklu bir katman geçerli bir "sessiz" kaptır.
      final w = encodeWav(sig([]));
      expect(w.length, wavHeaderBytes);
      expect(u32(w, 40), 0);
      expect(ascii(w, 0, 4), 'RIFF');
    });

    test('gerçekçi boyut: 30 sn @48kHz ≈ 2.8 MB (bellekte tutulabilir)', () {
      // Döngü buffer'ı RAM'de yaşayacak; büyüklüğün farkında olalım.
      final w = encodeWav(Float32List(48000 * 30));
      expect(w.length, wavHeaderBytes + 48000 * 30 * 2);
      expect(w.length / (1024 * 1024), closeTo(2.75, 0.1));
    });
  });
}
