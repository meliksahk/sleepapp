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
/// **BİRİM ÇERÇEVEDİR, SANİYE DEĞİL:** dedektör çerçeve süresini BİLMEZ (çağıranın
/// kararı). Varsayılanlar ~50 ms/çerçeve varsayar: [maxEventFrames]=100 ≈ 5 sn —
/// horlama (2-3 sn) olay kalır, fan uğultusu (dakikalar) seviye kayması sayılır.
/// Çağıran farklı bir çerçeve süresi kullanıyorsa BU DEĞERLERİ ÇEVİRMELİDİR.
///
/// **UYARI — AYARLANMADI:** eşikler makul başlangıç değerleridir, GERÇEK GECE
/// KAYITLARIYLA AYARLANMADI (docs/04 §120 fixture'ları henüz yok). Sınıflandırma
/// (hareket/horlama/gürültü ayrımı) da bilinçli olarak YOK: mikrofonla bunları
/// ayırmak süre/periyodiklik analizi ister ve gerçek veriyle doğrulanmalıdır —
/// uydurmak, sayıyı yanlış etiketleyip kullanıcıya güvenilir gibi sunmak olurdu.
class AcousticEventDetector {
  AcousticEventDetector({
    this.thresholdDb = 12.0,
    this.minDurationFrames = 2,
    this.maxEventFrames = 100,
    this.refractoryFrames = 10,
    this.floorAttack = 0.02,
    double? initialFloorDb,
  })  : assert(thresholdDb > 0),
        assert(minDurationFrames >= 1),
        assert(maxEventFrames > minDurationFrames),
        assert(refractoryFrames >= 0),
        assert(floorAttack > 0 && floorAttack < 1),
        _floorDb = initialFloorDb ?? silenceDbfs;

  /// Olay sayılması için tabanın kaç dB üstüne çıkılmalı.
  final double thresholdDb;

  /// Bu kadar çerçeveden kısa süren aşımlar YOK SAYILIR (tek örneklik tıklama,
  /// ADC parazitini olay saymamak için).
  final int minDurationFrames;

  /// Bundan uzun süren aşım artık OLAY değil SEVİYE KAYMASIDIR: bir kez sayılır,
  /// sonra taban yeni seviyeye sıçratılır (bkz. sınıf yorumu).
  final int maxEventFrames;

  /// Olay bittikten sonra yeni olay sayılmayan süre.
  final int refractoryFrames;

  /// Taban EMA'sının uyum hızı. YAVAŞ olmalı: hızlı taban, horlamanın kendisini
  /// "yeni normal" sayıp olayı yutardı.
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
