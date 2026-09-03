/// **Saf ton** — kullanıcının seçtiği frekansta tek sinüs.
///
/// Mikserin sekizinci jeneratif kaynağı (`mix_render.dart` `LayerSource.tone`).
/// Pad'in aksine TEK kısmi tondur: harmonik YOK, zarf YOK, rastgelelik YOK —
/// "istenilen frekansta temel bir uğultu" isteğinin en dürüst cevabı.
///
/// ## SAĞLIK İDDİASI YOK (CLAUDE.md §1.1)
/// Frekans aralığı [toneMinHz]–[toneMaxHz] ve varsayılan değerler MÜZİKAL/akustik
/// gerekçeyle seçildi; hiçbir değerin "tedavi", "beyin dalgası" ya da benzer bir
/// iddiası yoktur. Arayüz de böyle konuşur (bkz. `mixer_add_tone_sheet.dart`).
///
/// ## DÖNGÜ KİLİDİ — pad ile aynı pazarlıksız kural
///
/// Saf sinüs TONALDIR: frekansı döngü ızgarasına oturmazsa dikişte faz sıçrar ve
/// kullanıcı her 30 saniyede bir "tık" duyar. Çözüm `meditative.dart`'ın
/// [loopLockedHz] mekanizmasıdır: istenen frekans, döngüde TAM SAYIDA periyot
/// tamamlayan en yakın ızgara değerine oturtulur. Izgara adımı
/// `1/loopSeconds` Hz'dir (30 sn → ~0.033 Hz) — 110 Hz isteyen kullanıcıya
/// 110.000, 440.01 isteyene 440.0000 döner; algısal fark ölçülemez.
///
/// Kilidin sonucu: kaynak **döngü-periyodiktir** (`isLoopPeriodic(tone)` true),
/// yani `renderSeamlessLoop` crossfade'i ATLAYIP ham kopyalar — +3 dB kabarma
/// riski yapısal olarak yoktur (pad için #213'te kanıtlanan aynı akıl yürütme).
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'meditative.dart' show loopLockedHz;

/// Kabul edilen en düşük frekans. ~20 Hz işitme eşiğinin alt sınırıdır; altına
/// inmek kullanıcının duyamayacağı bir sürgü demektir.
const double toneMinHz = 20.0;

/// Kabul edilen en yüksek frekans. Uyku bağlamında 2 kHz üstü saf ton serttir
/// (işitme eğrisinin en hassas bantta kalıcı dikkat çeker); üstü zaten
/// "uğultu" değil "bip" olurdu. Estetik/akustik seçim — tıbbi değil.
const double toneMaxHz = 2000.0;

/// Binaural vuru aralığı (Hz/saniye). **SAĞLIK İDDİASI YOK (§1.1):** bu sayı
/// "beyin dalgası" DEĞİL, akustik bir olgudur — iki kulakta hafif farklı perde,
/// beyinde tek titreşen bir vuru olarak algılanır. Aralık seçimi algısaldır:
/// ~0.5 Hz altı yavaşça nefes alan bir ton gibi duyulur (yine de geçerli),
/// ~20 Hz üstü artık "vuru" değil titrek/kaba bir doku olurdu. Delta/theta/alfa
/// gibi EEG adları bilinçli olarak ARAYÜZDE VE KODDA KULLANILMAZ.
const double toneBeatMinHz = 0.5;
const double toneBeatMaxHz = 20.0;

/// Tepe genliği. **|çıkış| ≤ [tonePeakAmp] < 1** — kapalı formda ispat:
/// |sin| ≤ 1 olduğundan |x[i]| ≤ [tonePeakAmp]. Clamp YOKTUR; kaynak zincirinin
/// "kırpma yapısal olarak imkânsız" sözleşmesi (meditative.dart) burada da geçerli.
///
/// Neden 0.50: saf sinüsün tepe faktörü gürültüye göre yüksektir (RMS/tepe = 1/√2),
/// yani aynı tepe genliğinde gürültüden DAHA BASKIN duyulur. 0.50, sürgü %100'de
/// bile diğer katmanların üstüne çıkmayan ama tek başına net işitilen bir seviyedir.
/// Estetik karar — ölçülebilir karşılığı testte raporlanır.
const double tonePeakAmp = 0.50;

/// Binaural kanalların her biri AYRI tonPeakAmp ile üretilir → kanal başına
/// |x| ≤ 0.50. İki kanal ASLA toplanmaz (stereo WAV'ta yan yana yaşar), yani
/// toplam genlik sınırları kanal başına geçerlidir.
const double toneStereoPeakBound = tonePeakAmp;

/// [frequencyHz]'i döngü ızgarasına oturtup [samples] örneklik saf sinüs üretir.
///
/// `seed` ALMAZ — kasıtlı: sinüsün içinde rastgelelik yoktur, seed parametresi
/// almak "belki determinizm bozulur" şüphesi yaratırdı. Aynı frekans + aynı
/// sample rate → birebir aynı buffer, her çağrıda.
Float32List toneSource(
  int samples, {
  required double frequencyHz,
  required int sampleRate,
  required int loopSamples,
}) {
  assert(samples >= 0);
  assert(sampleRate > 0 && loopSamples > 0);
  assert(
    frequencyHz >= toneMinHz && frequencyHz <= toneMaxHz,
    'ton frekansı [$toneMinHz, $toneMaxHz] Hz arasında olmalı; gelen: $frequencyHz',
  );

  // Izgara kilidi: döngüde tam sayıda periyot. (Pad ile aynı fonksiyon.)
  final f = loopLockedHz(frequencyHz, loopSamples / sampleRate);

  final out = Float32List(samples);
  final twoPiOverSr = 2 * math.pi / sampleRate;
  final omega = twoPiOverSr * f;
  for (var i = 0; i < samples; i++) {
    out[i] = tonePeakAmp * math.sin(omega * i);
  }
  return out;
}

/// [beatHz]'i vuru ızgarasına oturtur: döngüde TAM SAYIDA vuru çevrimi.
///
/// Pad'in detune kuralının aynısı (meditative.dart): adım en az BİR ızgara
/// hücresi olmalı ki çok kısa döngülerde vuru kaybolmasın. Örn. 30 sn'de
/// istenen 10 Hz → tam 300 çevrim → 10.000 Hz.
double toneGridBeat(double desiredBeatHz, double loopSeconds) {
  assert(desiredBeatHz > 0 && loopSeconds > 0);
  var cycles = (desiredBeatHz * loopSeconds).round();
  if (cycles < 1) cycles = 1;
  return cycles / loopSeconds;
}

/// **Binaural stereo ton** — sol kanal [baseHz], sağ kanal `baseHz + [beatHz]`.
///
/// Dönüş INTERLEAVED stereo'dur: `[L0, R0, L1, R1, ...]`, uzunluk `2 × samples`.
/// `encodeWav(channels: 2)` doğrudan bu buffer'ı alır (wav_encoder zaten
/// kanal-sayılı başlık yazar).
///
/// Her iki frekans da ızgaraya kilitlidir → her kanal kendi içinde
/// döngü-periyodiktir → crossfade GEREKMEZ (pad/tone-mono ile aynı akıl).
/// Kanal genlikleri AYRI [toneStereoPeakBound] ile sınırlıdır; iki kanal hiçbir
/// yerde toplanmaz.
///
/// Neden tek fonksiyon: L ve R fazları BAĞIMSIZDIR (farklı frekans) ama aynı
/// t=0'dan başlar; böylece "vuru" tam olarak |R−L| = beat hızında algılanır.
Float32List toneBinauralSource(
  int samples, {
  required double baseHz,
  required double beatHz,
  required int sampleRate,
  required int loopSamples,
}) {
  assert(samples >= 0);
  assert(sampleRate > 0 && loopSamples > 0);
  assert(baseHz >= toneMinHz && baseHz <= toneMaxHz, 'taban: $baseHz');
  assert(
    beatHz >= toneBeatMinHz && beatHz <= toneBeatMaxHz,
    'vuru [$toneBeatMinHz, $toneBeatMaxHz] arasında olmalı; gelen: $beatHz',
  );

  final loopSeconds = loopSamples / sampleRate;
  final fL = loopLockedHz(baseHz, loopSeconds);
  final fR = loopLockedHz(baseHz + toneGridBeat(beatHz, loopSeconds), loopSeconds);

  final out = Float32List(samples * 2);
  final twoPiOverSr = 2 * math.pi / sampleRate;
  final omegaL = twoPiOverSr * fL;
  final omegaR = twoPiOverSr * fR;
  for (var i = 0; i < samples; i++) {
    out[2 * i] = tonePeakAmp * math.sin(omegaL * i); // SOL
    out[2 * i + 1] = tonePeakAmp * math.sin(omegaR * i); // SAĞ
  }
  return out;
}

/// Binaural tonun MONO indirgemeşi — video export'un (`renderMix`) göreceği hâl.
///
/// Kapalı-form eşdeğer: `(sin(a)+sin(b))/2 = sin((a+b)/2·t)·cos((a−b)/2·t)` —
/// yani ortalama frekansta bir taşıyıcı + beat/2 hızında tremolo. Kulaklıkla
/// duyulan uzamsal vuru burada GENLİK titreşimine dönüşür: farklıdır ama
/// temsildir (asset katmanlarının videodan TAMAMEN düşmesinden daha dürüst).
/// Bu fark bilinçli kabul edilmiştir ve gizlenmez (bkz. mix_render yorumu).
Float32List toneMonoFromBinaural(
  int samples, {
  required double baseHz,
  required double beatHz,
  required int sampleRate,
  required int loopSamples,
}) {
  final left = toneSource(samples,
      frequencyHz: baseHz, sampleRate: sampleRate, loopSamples: loopSamples);
  // Sağ kanal = taban + ızgarada oturmuş vuru (binaural üretimle BİREBİR aynı
  // hesap; aksi hâlde mono önizleme ile stereo çalma farklı perdede olurdu).
  final gridBeat = toneGridBeat(beatHz, loopSamples / sampleRate);
  final right = toneSource(samples,
      frequencyHz: baseHz + gridBeat,
      sampleRate: sampleRate,
      loopSamples: loopSamples);
  final out = Float32List(samples);
  for (var i = 0; i < samples; i++) {
    out[i] = (left[i] + right[i]) * 0.5;
  }
  return out;
}
/// UI'ın göstereceği etiket frekansı: ızgaraya oturmuş GERÇEK değer.
///
/// Sürgü serbest değer verir (ör. 440.01); motor onu 440.0'a oturtur. Ekranda
/// isteneni değil DUYULANI yazmak gerekir — aksi hâlde "440.01 Hz yazıyor,
/// neden başka bir şey çalıyor" sorusu doğar. (Fark algısal olarak sıfırdır
/// ama sayılar farklıdır; dürüstlük göstergeyi gerçeğe bağlar.)
double toneGridHz(double desiredHz, double loopSeconds) {
  assert(desiredHz > 0 && loopSeconds > 0);
  return loopLockedHz(desiredHz, loopSeconds);
}
/// [toneGridHz] sonucunu ETİKET metnine çevirir: gereksiz ondalık yok.
///
/// "440" düz sayı; "130.8" tek ondalık. Ekran ile seçici sheet AYNI fonksiyonu
/// çağırır — ikisi ayrı biçimlendirseydi aynı ton iki yerde farklı yazılırdı.
String toneHzText(double hz) {
  final s = hz.toStringAsFixed(2);
  if (s.endsWith('.00')) return s.substring(0, s.length - 3);
  if (s.endsWith('0')) return s.substring(0, s.length - 1);
  return s;
}
