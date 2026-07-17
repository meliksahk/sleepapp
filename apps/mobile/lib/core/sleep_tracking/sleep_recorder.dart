import 'dart:async';
import 'dart:typed_data';

import 'db_envelope.dart';
import 'envelope_log.dart';
import 'event_detector.dart';
import 'mic_source.dart';
import 'recent_activity.dart';
import 'sleep_session_builder.dart';

/// Uyku kaydı — mikrofondan gece raporuna giden **tek hat**.
///
/// #128–#132'de bu hattın parçaları tek tek yazıldı ve test edildi
/// (`db_envelope`, `event_detector`, `sleep_session_builder`) ama **hiçbiri
/// birbirine bağlanmadı**: `recordSession`'ın üretimde çağıranı yoktu, mikrofon
/// yakalama hiç yazılmamıştı. Beş iterasyonluk ölü kod. Burası o kodu yeteneğe
/// çeviren yer.
///
/// ## CLAUDE.md §6 — ham ses cihazdan ÇIKMAZ, üstelik hiç BİRİKMEZ
///
/// Akış şu: çerçeve gelir → **anında** `frameDbfs` ile tek bir `double`'a indirgenir →
/// dedektöre verilir → çerçeve DÜŞER. Hiçbir yerde `List<Float32List>` yok; ne bellekte
/// ne diskte ham ses tutuluyor. Yani "yanlışlıkla yükleme" için ortada veri yok —
/// kuralı yorum değil, **veri akışının şekli** zorluyor.
///
/// Sunucuya giden tek şey: başlangıç/bitiş zamanı + iki SAYI.
class SleepRecorder {
  SleepRecorder({
    required this.mic,
    AcousticEventDetector Function(double initialFloorDb)? detectorFactory,
    this.sampleRate = 16000,
    this.warmupFrames = 16,
    this.frameSamples = 256,
    this.logEnvelope = false,
    DateTime Function()? now,
  })  : _detectorFactory = detectorFactory ??
            ((floor) => AcousticEventDetector(initialFloorDb: floor)),
        _now = now ?? DateTime.now;

  /// Mikrofon kaynağı — test sahte enjekte eder, üretim `RecordMicSource` verir.
  final MicSource mic;
  final AcousticEventDetector Function(double initialFloorDb) _detectorFactory;
  final DateTime Function() _now;

  /// **ISINMA — HAYALET OLAY HATASI (testte yakalandı):** dedektörün uyarlanır tabanı
  /// `silenceDbfs` (-100 dB) yani MUTLAK sessizlikten başlıyor. Gerçek bir yatak odası
  /// ~-60 dB. Yani ilk çerçeveler tabanın 40 dB üstünde görünüyor ve eşiği (12 dB)
  /// aşıyor → **her gecenin başında uydurma bir olay** sayılırdı; kullanıcı hiç
  /// olmamış bir sesi raporunda görürdü.
  ///
  /// Çözüm: ilk [warmupFrames] çerçeve YALNIZCA tabanı ölçer, dedektöre girmez.
  /// 16 çerçeve ≈ 0.25 sn (16 kHz, 256 örnek) — odanın sessizliğini öğrenmeye yeter,
  /// kullanıcının fark edemeyeceği kadar kısa.
  final int warmupFrames;

  AcousticEventDetector? _detector;
  final List<double> _warmup = [];

  /// 16 kHz: konuşma/horlama bandı için fazlasıyla yeterli ve 48 kHz'in üçte biri
  /// kadar CPU/pil harcar. Gece boyunca çalışacak bir işte bu fark önemli.
  final int sampleRate;

  /// Çerçeve başına örnek — zarf günlüğünün saniye hesabı için.
  final int frameSamples;

  /// dB zarfını kaydet (docs/04 §120 fixture'ı). **Varsayılan KAPALI:** kullanıcının
  /// ihtiyacı olmayan bir veriyi varsayılan olarak toplamak, gerekmediği hâlde veri
  /// biriktirmek olurdu. Eşik ayarı için açılır.
  final bool logEnvelope;

  /// Gece zarfı — [logEnvelope] açıksa dolar.
  EnvelopeLog? envelope;

  StreamSubscription<Float32List>? _sub;
  DateTime? _startedAt;

  /// `stop()` çağrıldı: yolda olan çerçeveler artık sayılmaz.
  bool _stopped = false;

  /// Şu ana kadar sayılan olay — UI canlı gösterebilsin.
  int get eventCount => _detector?.events.length ?? 0;

  bool get isRecording => _startedAt != null;

  DateTime? get startedAt => _startedAt;

  /// Her çerçeve işlendiğinde tetiklenir (UI'ın canlı sayacı için).
  void Function()? onProgress;

  Future<bool> hasPermission() => mic.hasPermission();

  /// Kaydı başlatır. İzin yoksa **false** döner (hata fırlatmaz: izin reddi bir
  /// program hatası değil, kullanıcının kararıdır).
  Future<bool> start() async {
    if (_startedAt != null) return true;
    if (!await mic.hasPermission()) return false;

    _startedAt = _now();
    _stopped = false;
    _warmup.clear();
    _detector = null;
    envelope = logEnvelope
        ? EnvelopeLog(sampleRate: sampleRate, frameSamples: frameSamples)
        : null;
    _sub = mic.start(sampleRate: sampleRate).listen(
      (frame) {
        // Durdurulduktan sonra yolda kalan çerçeveler SAYILMAZ: kullanıcı "bitir"e
        // bastıktan sonra gelen bir ses onun gecesine yazılmamalı.
        if (_stopped) return;
        // TEK SATIRLIK GİZLİLİK GARANTİSİ: çerçeve burada bir sayıya iner ve düşer.
        final db = frameDbfs(frame);
        // Zarf günlüğü de yalnızca bu SAYIYI görür — ham çerçeveye erişmez.
        envelope?.addFrame(db);
        _feed(db);
        onProgress?.call();
      },
      onError: (Object e) {
        // Yutulmaz: kayıt sessizce ölürse kullanıcı sabah boş bir raporla karşılaşır.
        _lastError = e;
      },
    );
    return true;
  }

  Object? _lastError;
  Object? get lastError => _lastError;

  /// Bir çerçevenin kapsadığı süre — çerçeve indeksi ile duvar saati arasındaki köprü.
  Duration get frameDuration =>
      Duration(microseconds: frameSamples * 1000000 ~/ sampleRate);

  /// Son [lookback] süresinde akustik aktivite oldu mu — akıllı alarmın girdisi.
  ///
  /// **Neden burada:** çerçeve saatini ve dedektörü bu sınıf tutuyor. Alarmın
  /// dedektöre doğrudan uzanması, iki sınıfı birbirine bağlar ve alarmı çerçeve
  /// kavramına bulaştırırdı (alarm duvar saatiyle çalışır, bkz. `recent_activity`).
  ///
  /// Isınma bitmeden (dedektör yokken) **false**: taban henüz bilinmiyor, "aktivite
  /// var" demek uydurma olurdu.
  bool hasRecentActivityIn(Duration lookback) {
    final detector = _detector;
    if (detector == null) return false;
    return hasRecentActivity(
      events: detector.events,
      currentFrame: detector.frameCount,
      lookback: lookback,
      frameDuration: frameDuration,
    );
  }

  /// Isınma bitene kadar taban ölçülür; sonra dedektör O TABANLA kurulur.
  void _feed(double db) {
    final detector = _detector;
    if (detector != null) {
      detector.addFrame(db);
      return;
    }
    _warmup.add(db);
    if (_warmup.length < warmupFrames) return;

    // Medyan: tek bir gürültü patlaması (kapı çarpması) ortalamayı bozar, medyanı bozmaz.
    final sorted = List<double>.from(_warmup)..sort();
    final floor = sorted[sorted.length ~/ 2];
    _detector = _detectorFactory(floor);
  }

  /// Kaydı bitirir ve **taslak** döner (kaydetmez — o çağıranın işi).
  ///
  /// Hiç başlamamışsa null döner.
  Future<SleepSessionDraft?> stop() async {
    final started = _startedAt;
    if (started == null) return null;

    // **`cancel()` BEKLENMEZ:** widget testinin sahte zaman bölgesinde akış
    // aboneliğini iptal etmek, pump olmadan tamamlanmıyor → `stop()` sonsuza kadar
    // asılı kalıyordu (test sessizce dondu, saatlerce aradım). `_stopped` bayrağı
    // zaten yolda kalan çerçeveleri kesiyor, yani iptali beklemenin bir faydası yok.
    _stopped = true;
    unawaited(_sub?.cancel());
    _sub = null;
    // `mic.stop()` BEKLENİR: gerçek mikrofonu bırakmak gece boyu pil/gizlilik
    // açısından kritik ve gerçek implementasyonda anında döner.
    await mic.stop();

    // `finish()` ŞART: son olay hâlâ açıksa (kayıt tam bir ses sırasında bitti)
    // dedektör onu kapatmalı, yoksa o olay sessizce kaybolurdu.
    final detector = _detector;
    detector?.finish();
    // Açık kalan saniye kapatılır: kayıt saniye ortasında bittiyse o veri kaybolmasın.
    envelope?.finish();
    _startedAt = null;

    // Isınma bile bitmediyse (çok kısa kayıt) dedektör hiç kurulmadı → sıfır olay.
    // Uydurmak yerine sıfır: 0.25 sn'lik bir "gece"de zaten ölçecek bir şey yok.
    final events = detector?.events ?? const <AcousticEvent>[];
    return SleepSessionDraft(
      startedAt: started,
      endedAt: _now(),
      // **DÜRÜSTLÜK:** "hareket" ile "ses" ayrımı gerçek gece kayıtlarıyla
      // DOĞRULANMADI (docs/04 §120 fixture'ları yok, bkz. event_detector yorumu).
      // Ayrımı uydurmak yerine ölçtüğümüz tek şeyi — akustik olay sayısını —
      // `soundEvents`'e koyuyoruz; `movementEvents` 0 kalıyor çünkü ölçmüyoruz.
      // Sıfır yazmak, ölçmediğimiz bir sayıyı uydurmaktan dürüsttür (DECISIONS D-10).
      movementEvents: 0,
      soundEvents: events.length,
    );
  }
}
