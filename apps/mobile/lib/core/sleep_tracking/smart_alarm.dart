/// Akıllı alarm penceresi mantığı (docs/04 §86).
///
/// Kural: "alarm penceresi (ör. 06:30–07:00) içinde hafif uyku sinyali (hareket/ses
/// aktivitesi artışı) görülünce local notification + ses motoru 'sunrise' rampası."
///
/// **SAF MANTIK, YAN ETKİSİZ:** bildirim gönderme, ses çalma, zamanlayıcı kurma
/// BURADA YOK. Bu sınıf yalnızca "şimdi çalmalı mı?" sorusuna cevap verir. Sebep:
/// alarmın doğruluğu insanların işe yetişmesi demektir ve bunu platform kodu
/// olmadan, saniyesi saniyesine test edebilmek gerekir.
library;

/// Alarmın neden çaldığı — kullanıcıya değil, teşhise ve teste.
enum AlarmTrigger {
  /// Pencere içinde hafif uyku sinyali görüldü (istenen durum).
  lightSleep,

  /// Pencere sonu geldi; hafif uyku hiç görülmedi ama uyandırmak ZORUNLU.
  deadline,
}

class AlarmDecision {
  const AlarmDecision.fire(this.trigger) : shouldFire = true;
  const AlarmDecision.wait()
      : shouldFire = false,
        trigger = null;

  final bool shouldFire;
  final AlarmTrigger? trigger;
}

/// Pencere içinde hafif uyku ararken, pencere sonunda KESİNLİKLE uyandıran alarm.
///
/// **EN KRİTİK KURAL — SON TARİH:** hafif uyku sinyali hiç görülmezse bile pencere
/// sonunda çalar. "Akıllı" kısmı bir OPTİMİZASYONDUR; alarmın kendisi bir SÖZDÜR.
/// Sinyal beklerken sessiz kalmak, kullanıcının işe geç kalması demektir — bu
/// sınıftaki tek gerçekten tehlikeli hata budur.
///
/// **BİR KEZ ÇALAR:** ateşlendikten sonra hep `wait` döner. Aksi halde çağıran her
/// tick'te yeniden bildirim gönderirdi.
///
/// **HAFİF UYKU SEZGİSELDİR:** "son N dakikada akustik aktivite" = hafif uyku
/// varsayımı, uyku evrelemesiyle (polisomnografi) DOĞRULANMADI. Kategori standardı
/// bu; ama iddia edilebilecek şey "hareketlendiğinde uyandırırız", "REM'i biliriz"
/// değil. Ürün metni de bunu aşmamalı (CLAUDE.md §1.1 sağlık iddiası yasağı).
class SmartAlarm {
  SmartAlarm({required this.windowStart, required this.windowEnd})
      : assert(!windowEnd.isBefore(windowStart), 'Pencere sonu başlangıçtan önce olamaz');

  /// Hafif uyku aramaya başlanan an (bundan önce asla çalmaz).
  final DateTime windowStart;

  /// Son tarih — bu ana gelindiğinde sinyal olsun olmasın çalar.
  final DateTime windowEnd;

  bool _fired = false;

  /// Alarm çaldı mı?
  bool get hasFired => _fired;

  /// [now] anında, [hasRecentActivity] son dakikalarda akustik aktivite olup
  /// olmadığını söyler (çağıran `AcousticEventDetector` çıktısından türetir).
  AlarmDecision evaluate({required DateTime now, required bool hasRecentActivity}) {
    if (_fired) return const AlarmDecision.wait();

    // SON TARİH önce kontrol edilir: pencere sonunda aktivite YOKSA bile çalmalı.
    // Sıra ters olsaydı ("önce aktiviteye bak") sonuç aynı olurdu ama niyet
    // okunmazdı; burada kastımız "son tarih pazarlıksız".
    if (!now.isBefore(windowEnd)) {
      _fired = true;
      return const AlarmDecision.fire(AlarmTrigger.deadline);
    }

    if (now.isBefore(windowStart)) {
      // Pencere açılmadan çalmak, kullanıcıya söz verdiğimizden ERKEN uyandırmaktır.
      return const AlarmDecision.wait();
    }

    if (hasRecentActivity) {
      _fired = true;
      return const AlarmDecision.fire(AlarmTrigger.lightSleep);
    }

    return const AlarmDecision.wait();
  }
}
