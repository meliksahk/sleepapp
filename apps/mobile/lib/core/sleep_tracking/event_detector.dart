import 'db_envelope.dart';

/// Tespit edilen akustik olay. Ham ses YOK — yalnızca türetilmiş sayılar
/// (CLAUDE.md §6: sunucuya yalnızca türetilmiş metrikler gider).
class AcousticEvent {
  const AcousticEvent({
    required this.startFrame,
    required this.durationFrames,
    required this.peakDb,
    required this.floorDb,
  });

  /// Olayın başladığı çerçeve indeksi (çağıran zamana çevirir).
  final int startFrame;
  final int durationFrames;

  /// Olay boyunca görülen en yüksek dBFS.
  final double peakDb;

  /// Olay başladığında geçerli olan gürültü tabanı — "neye göre yüksek?"
  final double floorDb;

  /// Tabanın ne kadar üstüne çıktı. Sınıflandırma (hareket/horlama/gürültü)
  /// buna bakacak; o AYRI bir iş (bkz. detector sınıf yorumu).
  double get prominenceDb => peakDb - floorDb;
}

/// Uyarlanabilir gürültü tabanı + eşik ile akustik olay tespiti
/// (docs/04 §85: "dB zarfı + basit olay sınıflandırması").
///
/// **ASIL TASARIM KARARI — UYARLANABİLİR TABAN:** sabit bir eşik (ör. "-40 dBFS
/// üstü olaydır") kâğıtta çalışır, gerçek gecede çöker. Kullanıcı klimayı/fanı
/// açtığında oda tabanı -55'ten -35'e çıkar ve sabit eşik SONSUZ olay üretir —
/// rapor "312 hareket" der, kullanıcı da haklı olarak uygulamayı siler. Taban
/// yavaş bir EMA ile sürüklenir; olay, tabanın ÜSTÜNE çıkan ANİ fark demektir.
///
/// **TABAN OLAY SIRASINDA DONDURULUR:** aksi halde uzun bir horlama kendi tabanını
/// yukarı çeker ve olay "biter" görünür — horlama 40 küçük olaya bölünürdü.
///
/// **AMA SONSUZA KADAR DEĞİL — [maxEventFrames]:** dondurma tek başına yazıldığında
/// fan gibi SÜREKLİ bir ses bitmeyen tek olaya dönüşüyor ve taban bir daha hiç uyum
/// sağlamıyordu (testte yakalandı). Ayrım şu: kısa aşım OLAYDIR, sürekli aşım bir
/// SEVİYE KAYMASIDIR. Bu süreyi aşan aşım bir kez olay sayılır, sonra taban yeni
/// seviyeye SIÇRATILIR — "fan artık odanın normali".
///
/// **REFRAKTER SÜRE:** tek bir dönme-hareketi genlikte birkaç kez salınır; refrakter
/// olmadan tek olay 3-4 kez sayılırdı.
///
/// **AYARLAR SÜRE CİNSİNDEN VERİLİR, ÇERÇEVE CİNSİNDEN DEĞİL.** Çerçeveye çevirme
/// [frameDuration] ile burada yapılır. Bu bir hata sınıfını kapatmak içindir:
/// sabitler daha önce çerçeve sayısıydı ve "~50 ms/çerçeve" varsayıyordu, ama
/// gerçek boru hattı 16 kHz/256 örnek = **16 ms/çerçeve** çalışıyor ve çağıran
/// çevirme yapmıyordu. Sonuç: her süre 3.1× kısaydı — [maxEventDuration] 5 sn
/// yerine 1.6 sn olduğu için 2-3 saniyelik horlama "olay" değil "seviye kayması"
/// sayılıyor, taban horlamanın seviyesine sıçrıyordu. Yani sınıf yorumunun tam da
/// önlemek için yazıldığı davranış gerçekleşiyordu. Birim süre olunca çağıranın
/// yanlış değer geçirmesi mümkün değil.
///
/// **UYARI — HÂLÂ AYARLANMADI:** 2026-08-03'te 45 dk'lık gerçek bir zarf kaydı
/// (docs/04 §120 fixture'ı) şunu DOĞRULADI: gürültü tabanı gerçekten sürükleniyor
/// (45 dk'da ~3 dB), yani uyarlanabilir taban kararı yerinde. Ama [thresholdDb]
/// AYARLANAMADI: kayıtta etiket yok (hangi saniye dönme, hangisi horlama, hangisi
/// dışarıdaki araba bilinmiyor). Etiketsiz veriyle sinyal karakterize edilir, eşik
/// ayarlanmaz. Sınıflandırma da bu yüzden hâlâ YOK — uydurmak, sayıyı yanlış
/// etiketleyip kullanıcıya güvenilir gibi sunmak olurdu.
class AcousticEventDetector {
  AcousticEventDetector({
    required this.frameDuration,
    this.thresholdDb = 12.0,
    Duration minDuration = const Duration(milliseconds: 100),
    Duration maxEventDuration = const Duration(seconds: 5),
    Duration refractory = const Duration(milliseconds: 500),
    Duration floorTimeConstant = const Duration(milliseconds: 2500),
    double? initialFloorDb,
  })  : assert(thresholdDb > 0),
        assert(frameDuration > Duration.zero),
        assert(maxEventDuration > minDuration),
        assert(refractory >= Duration.zero),
        assert(floorTimeConstant > Duration.zero),
        // En az 1 çerçeve: çerçeve süresi istenen süreden uzunsa aşağı yuvarlamak
        // 0 verir ve "her çerçeve olaydır" anlamına gelirdi.
        minDurationFrames = _frames(minDuration, frameDuration, min: 1),
        maxEventFrames = _frames(maxEventDuration, frameDuration, min: 2),
        refractoryFrames = _frames(refractory, frameDuration, min: 0),
        // τ = 1/attack çerçeve → attack = çerçeve süresi / τ. Üst sınır bir
        // çerçevede tam uyum (1.0) olurdu; taban sese anında yapışırdı.
        floorAttack = (frameDuration.inMicroseconds /
                floorTimeConstant.inMicroseconds)
            .clamp(1e-6, 0.5),
        _floorDb = initialFloorDb ?? silenceDbfs;

  static int _frames(Duration d, Duration frame, {required int min}) {
    final n = (d.inMicroseconds / frame.inMicroseconds).round();
    return n < min ? min : n;
  }

  /// Bir çerçevenin kapsadığı süre — tüm süre→çerçeve çevrimlerinin dayanağı.
  final Duration frameDuration;

  /// Olay sayılması için tabanın kaç dB üstüne çıkılmalı.
  final double thresholdDb;

  /// `minDuration`'ın çerçeve karşılığı. Bundan kısa aşımlar YOK SAYILIR (tek
  /// örneklik tıklama, ADC parazitini olay saymamak için).
  final int minDurationFrames;

  /// `maxEventDuration`'ın çerçeve karşılığı. Bundan uzun süren aşım artık OLAY
  /// değil SEVİYE KAYMASIDIR: bir kez sayılır, sonra taban yeni seviyeye
  /// sıçratılır (bkz. sınıf yorumu).
  final int maxEventFrames;

  /// `refractory`'nin çerçeve karşılığı — olay bittikten sonra yeni olay
  /// sayılmayan süre.
  final int refractoryFrames;

  /// `floorTimeConstant`'tan türetilen EMA uyum hızı. YAVAŞ olmalı: hızlı taban,
  /// horlamanın kendisini "yeni normal" sayıp olayı yutardı.
  final double floorAttack;

  double _floorDb;
  int _frame = 0;

  // Süregelen olayın durumu (null = olay yok).
  int? _eventStart;
  double _eventPeak = silenceDbfs;
  double _eventFloor = silenceDbfs;

  int _refractoryUntil = -1;

  final List<AcousticEvent> _events = [];

  /// Şu ana kadar tespit edilenler (salt okunur).
  List<AcousticEvent> get events => List.unmodifiable(_events);

  /// Güncel gürültü tabanı — test/teşhis için.
  double get floorDb => _floorDb;

  /// İşlenen çerçeve sayısı = dedektörün "şimdi"si.
  ///
  /// **Neden dışarı açık:** `hasRecentActivity` "son N dakikada ses var mıydı?"
  /// sorusunu çerçeve biriminde soruyor ve referans noktası olarak GÜNCEL çerçeveyi
  /// istiyor. Bunu çağıranın kendi sayacıyla tahmin etmesi, iki sayacın gece boyunca
  /// birbirinden kaymasına açık olurdu.
  int get frameCount => _frame;

  /// Bir dB zarfı çerçevesi işler. Çağıran `frameDbfs` ile üretir.
  void addFrame(double db) {
    final isLoud = db > _floorDb + thresholdDb;

    if (_eventStart == null) {
      // Olay yok: taban serbestçe sürüklenir (sessizleşmeye de uyum sağlar).
      _floorDb = _floorDb + floorAttack * (db - _floorDb);

      if (isLoud && _frame > _refractoryUntil) {
        _eventStart = _frame;
        _eventPeak = db;
        _eventFloor = _floorDb; // olay boyunca DONDURULUR
      }
    } else {
      // Olay sürüyor: taban DONDURULMUŞ (yukarıdaki yorum).
      if (db > _eventPeak) _eventPeak = db;

      if (!isLoud) {
        _closeEvent();
      } else if (_frame - _eventStart! >= maxEventFrames) {
        // Sürekli aşım = seviye kayması. Olayı kapat ve tabanı yeni seviyeye
        // SIÇRAT (EMA ile sürünmek dakikalar sürerdi; o süre boyunca her şey
        // "olay" görünürdü).
        _closeEvent();
        _floorDb = db;
      }
    }

    _frame++;
  }

  /// Akış bitti — sonuna kadar süren bir olay varsa kapatılır.
  ///
  /// Olmasaydı gecenin son sesi (ör. çalar saatle uyanma) SESSİZCE kaybolurdu:
  /// "raporda görünmüyor" diye bir hata sınıfı.
  void finish() {
    if (_eventStart != null) _closeEvent();
  }

  void _closeEvent() {
    final start = _eventStart!;
    final duration = _frame - start;
    _eventStart = null;

    if (duration >= minDurationFrames) {
      _events.add(AcousticEvent(
        startFrame: start,
        durationFrames: duration,
        peakDb: _eventPeak,
        floorDb: _eventFloor,
      ));
      _refractoryUntil = _frame + refractoryFrames;
    }
    // Kısa aşım: olay değil ama taban da onu görmemeli (tıklama tabanı bozmasın).
  }
}
