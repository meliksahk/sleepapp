import 'dart:async';

import '../../core/share/sharer.dart';
import '../../core/sleep_tracking/alarm_sound.dart';
import '../../core/sleep_tracking/envelope_log.dart';
import '../../core/sleep_tracking/night_alarm_scheduler.dart';
import '../../core/sleep_tracking/night_service.dart';
import '../../core/sleep_tracking/sleep_recorder.dart';
import '../../core/sleep_tracking/sleep_session_builder.dart';
import '../../core/sleep_tracking/sleep_session_queue.dart';
import '../../core/sleep_tracking/smart_alarm.dart';
import 'sleep_controller.dart';

/// Uyku modunun durumu — UI'ın gördüğü tek şey.
class SleepModeState {
  const SleepModeState({
    this.isRecording = false,
    this.startedAt,
    this.eventCount = 0,
    this.savedDraft,
    this.error,
    this.permissionDenied = false,
    this.serviceFailed = false,
    this.alarmAt,
    this.alarmRinging = false,
    this.alarmTrigger,
  });

  final bool isRecording;
  final DateTime? startedAt;
  final int eventCount;

  /// Kaydedilen oturum — gece raporuna geçiş için.
  final SleepSessionDraft? savedDraft;

  final String? error;

  /// Mikrofon izni reddedildi: bir hata DEĞİL, kullanıcının kararı — ayrı gösterilir.
  final bool permissionDenied;

  /// Foreground servis başlatılamadı → kayıt BAŞLATILMADI. İzin reddinden ayrı:
  /// bu bir sistem sorunu, kullanıcının seçimi değil.
  final bool serviceFailed;

  /// Kullanıcının "beni en geç şu saatte uyandır" dediği an. Null = alarm YOK.
  ///
  /// Alarm **opt-in**: varsayılan bir saat uydurmak, kullanıcıyı beklemediği bir anda
  /// uyandırmak olurdu — bir uyku uygulamasının yapabileceği en kötü şey.
  final DateTime? alarmAt;

  /// Alarm ŞU AN çalıyor.
  final bool alarmRinging;

  /// Alarm neden çaldı — kullanıcıya gösterilir (hafif uykuda mı, son tarihte mi).
  final AlarmTrigger? alarmTrigger;

  SleepModeState copyWith({
    bool? isRecording,
    DateTime? startedAt,
    int? eventCount,
    SleepSessionDraft? savedDraft,
    String? error,
    bool? permissionDenied,
    bool? serviceFailed,
    DateTime? alarmAt,
    bool clearAlarm = false,
    bool? alarmRinging,
    AlarmTrigger? alarmTrigger,
    bool clearError = false,
    bool clearDraft = false,
  }) {
    return SleepModeState(
      isRecording: isRecording ?? this.isRecording,
      startedAt: startedAt ?? this.startedAt,
      eventCount: eventCount ?? this.eventCount,
      savedDraft: clearDraft ? null : (savedDraft ?? this.savedDraft),
      error: clearError ? null : (error ?? this.error),
      permissionDenied: permissionDenied ?? this.permissionDenied,
      serviceFailed: serviceFailed ?? this.serviceFailed,
      alarmAt: clearAlarm ? null : (alarmAt ?? this.alarmAt),
      alarmRinging: alarmRinging ?? this.alarmRinging,
      alarmTrigger: clearAlarm ? null : (alarmTrigger ?? this.alarmTrigger),
    );
  }
}

/// Uyku modu — mikrofon kaydından oturum kaydına.
///
/// **Bu sınıf, #128–#132'de yazılan beş iterasyonluk ölü kodu yeteneğe çeviren
/// son halka.** O iterasyonlarda `event_detector`, `smart_alarm`,
/// `sleep_session_builder` ve `recordSession` yazıldı, test edildi, yeşil geçti —
/// ve hiçbiri hiçbir yerden çağrılmadı.
class SleepModeController {
  SleepModeController({
    required this.recorder,
    required this.sleep,
    required this.nightService,
    this.sharer,
    this.alarmSound,
    this.alarmScheduler,
    this.sessionQueue,
    this.alarmWindow = const Duration(minutes: 30),
    this.alarmLookback = const Duration(minutes: 5),
    this.alarmTick = const Duration(seconds: 10),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    recorder.onProgress = () {
      // Canlı sayaç: kullanıcı gece kalkarsa "çalışıyor mu?" sorusuna cevap görür.
      _emit(_state.copyWith(eventCount: recorder.eventCount));
    };
    // CANLI DRAIN tetiği #1: açılışta bekleyen çevrimdışı geceleri boşaltmayı dene
    // (bağlantı geri gelmiş olabilir). Kuyruğa yazıp hiç boşaltmama tuzağını önler.
    unawaited(_drainQueue());
  }

  /// Kayıt motoru — test sahte mikrofonlu bir tane enjekte eder.
  final SleepRecorder recorder;

  /// Oturumu sunucuya yazan controller.
  final SleepController sleep;

  /// Gece boyu süreci hayatta tutan foreground servis (Android 14+ ZORUNLU).
  final NightService nightService;

  /// Fixture paylaşımı için (docs/04 §120). Test sahte enjekte eder.
  final Sharer? sharer;

  /// Alarmı duyulur yapan port. Null → alarm sessiz çalar (yalnızca UI değişir);
  /// testlerin çoğu bunu vermez.
  final AlarmSound? alarmSound;

  /// Süreç ölse bile son-tarihte uyandıran **sistem backstop** portu. Null →
  /// yalnızca in-app alarm (testlerin çoğu bunu vermez). EK güvence: in-app
  /// alarmın lifecycle'ıyla birebir kurulur/iptal edilir, onu regrese ETMEZ.
  final NightAlarmScheduler? alarmScheduler;

  /// Çevrimdışı biten gecelerin kayıp-önleyici kuyruğu (#177). Null → kuyruk yok
  /// (kayıt başarısızsa gece yalnızca gösterilir, eski davranış). Verilirse: kayıt
  /// başarısızsa geceyi kuyruğa alır, açılışta ve her başarılı kayıttan sonra boşaltır.
  final SleepSessionQueue? sessionQueue;

  /// Hedef saatten NE KADAR ÖNCE hafif uyku aranmaya başlanır.
  ///
  /// 30 dk kategori standardı: uyku döngüsü ~90 dk, hafif uyku evresi o döngünün
  /// sonunda. 30 dk'lık pencere en az bir hafif uyku fırsatı yakalamaya yeter ama
  /// kullanıcıyı "istediğimden yarım saat erken kalktım"dan fazla erken uyandırmaz.
  final Duration alarmWindow;

  /// "Son N dakikada ses" = hafif uyku sezgiseli. 5 dk: tek bir öksürük değil,
  /// süregelen bir hareketlenme aransın.
  final Duration alarmLookback;

  /// Alarm ne sıklıkla değerlendirilir. 10 sn: son tarih en fazla 10 sn gecikir
  /// (kullanıcı fark etmez), pil maliyeti ihmal edilebilir.
  final Duration alarmTick;

  final DateTime Function() _now;

  SmartAlarm? _alarm;
  Timer? _alarmTimer;

  /// Bitmiş gecenin dB zarfı — varsa "paylaş" düğmesi görünür.
  EnvelopeLog? _envelope;
  EnvelopeLog? get envelope => _envelope;

  SleepModeState _state = const SleepModeState();
  SleepModeState get state => _state;

  void Function()? onChanged;

  void _emit(SleepModeState next) {
    _state = next;
    onChanged?.call();
  }

  /// Kullanıcının "beni en geç şu saatte uyandır" seçimi. Null → alarm kapalı.
  ///
  /// Kayıt SIRASINDA da çağrılabilir (kullanıcı yatakta fikir değiştirebilir).
  void setAlarm(DateTime? at) {
    _emit(at == null
        ? _state.copyWith(clearAlarm: true)
        : _state.copyWith(alarmAt: at));
    if (_state.isRecording) _armAlarm();
  }

  /// Alarmı SUSTURUR. Kayıt devam eder — kullanıcı alarmı kapatıp uyumaya
  /// dönebilir; geceyi bitirmek ayrı bir eylemdir (`stopAndSave`).
  Future<void> dismissAlarm() async {
    await alarmSound?.stop();
    // Kullanıcı uyandı → bekleyen sistem backstop'u iptal et: aksi halde süreç
    // ölürse OS son-tarihte İKİNCİ kez çalardı (kullanıcı zaten ayakta).
    unawaited(alarmScheduler?.cancel());
    _emit(_state.copyWith(alarmRinging: false));
  }

  /// Pencereyi kurar ve tick'i başlatır. Alarm yoksa var olanı söker.
  void _armAlarm() {
    _alarmTimer?.cancel();
    _alarmTimer = null;

    final at = _state.alarmAt;
    if (at == null) {
      _alarm = null;
      // Alarm kaldırıldı → sistem backstop'u da sök (yoksa ölü süreçte hayalet
      // bir alarm son-tarihte çalardı).
      unawaited(alarmScheduler?.cancel());
      return;
    }

    // Sistem backstop SON-TARİHE (pencere sonuna) kurulur: in-app akıllı alarm
    // hafif uykuda daha erken çalabilir, ama süreç ölürse OS garanti son-tarihte
    // uyandırır. EK güvence — birincil in-app yolu değiştirmez.
    unawaited(alarmScheduler?.schedule(at));

    _alarm = SmartAlarm(
      // Pencere geceden önce başlamaz — geçmişe uzanan bir pencere anlamsız olurdu.
      //
      // **KABUL EDİLEN SINIR:** kullanıcı `alarmWindow`dan (30 dk) KISA bir alarm
      // kurarsa pencere sadece kısalır ve baştan açık olur; kullanıcı henüz
      // uyumadan kıpırdarsa alarm erken çalabilir. Kabul ediyoruz çünkü hata payı
      // tanım gereği 30 dk'dan küçük ve kullanıcı zaten "beni birazdan uyandır"
      // demiş. Gerçek gecede (8 saat) pencere sabaha kadar açılmaz, sorun oluşmaz.
      windowStart: _laterOf(at.subtract(alarmWindow), _now()),
      windowEnd: at,
    );

    // **TIMER, mikrofonun onProgress'i DEĞİL — bilinçli.** Alarmı çerçeve akışına
    // bağlasaydık mikrofon ölünce (izin çekilir, OS akışı keser, cihaz kısılır)
    // alarm da SESSİZCE ölürdü: kullanıcı işe geç kalır ve nedenini asla bilmez.
    // `SmartAlarm`'ın son tarih garantisi, onu tick'leyen şey kadar sağlamdır.
    _alarmTimer = Timer.periodic(alarmTick, (_) => _tickAlarm());
  }

  void _tickAlarm() {
    final alarm = _alarm;
    if (alarm == null || _state.alarmRinging) return;

    final decision = alarm.evaluate(
      now: _now(),
      hasRecentActivity: recorder.hasRecentActivityIn(alarmLookback),
    );
    if (!decision.shouldFire) return;

    _alarmTimer?.cancel();
    _alarmTimer = null;
    _emit(_state.copyWith(
      alarmRinging: true,
      alarmTrigger: decision.trigger,
    ));
    // Ses hatası alarmı "çalmadı" saymaz: UI zaten çalıyor gösteriyor ve kullanıcı
    // ekranı görürse uyanır. Yutulmaz ama akışı da kesmez.
    unawaited(alarmSound?.play().catchError((Object e) {
      _emit(_state.copyWith(error: e.toString()));
    }));
  }

  static DateTime _laterOf(DateTime a, DateTime b) => a.isAfter(b) ? a : b;

  /// Bildirim metinleri PARAMETRE: i18n `BuildContext` ister, provider'ın context'i
  /// yok. Metni ekran (l10n'u olan taraf) verir — controller çeviri bilmez.
  Future<void> start({
    required String notificationTitle,
    required String notificationBody,
  }) async {
    _emit(
      _state.copyWith(
        clearError: true,
        clearDraft: true,
        permissionDenied: false,
        serviceFailed: false,
      ),
    );

    // SIRA ÖNEMLİ: önce mikrofon izni. Servis bildirimi gösterip sonra "aslında
    // mikrofon iznin yok" demek, kullanıcıya boş bir bildirim bırakırdı.
    final ok = await recorder.start();
    if (!ok) {
      // İzin reddi hata değil: kullanıcı bilinçli bir seçim yaptı, ekran bunu
      // "bir şeyler ters gitti" gibi göstermemeli.
      _emit(_state.copyWith(permissionDenied: true));
      return;
    }

    // **SERVİS BAŞLAMAZSA KAYIT DA BAŞLAMAZ.** Android 14+ arka planda mikrofonu
    // foreground service olmadan öldürür: kullanıcı "dinliyorum" ekranını görüp
    // sabah BOŞ raporla uyanırdı. Yarım çalışan bir gece takibi, hiç çalışmayandan
    // beter — çünkü kullanıcı ona güvenip uyur.
    final serviceOk = await nightService.start(
      title: notificationTitle,
      body: notificationBody,
    );
    if (!serviceOk) {
      await recorder.stop(); // mikrofonu bırak: boşuna açık kalmasın
      _emit(_state.copyWith(serviceFailed: true, isRecording: false));
      return;
    }
    _emit(
      _state.copyWith(
        isRecording: true,
        startedAt: recorder.startedAt,
        eventCount: 0,
      ),
    );
    // Alarm kayıt BAŞLADIKTAN sonra kurulur: kayıt başlamazsa (izin/servis) alarm
    // da kurulmamalı — çalan ama hiçbir şey kaydetmeyen bir alarm yalan olurdu.
    _armAlarm();
  }

  /// Kaydı bitirir ve oturumu SUNUCUYA yazar.
  ///
  /// Sunucuya giden: başlangıç/bitiş + iki sayı. **Ham ses değil** (CLAUDE.md §6);
  /// zaten hiçbir yerde ham ses tutulmuyor (bkz. `SleepRecorder`).
  Future<void> stopAndSave() async {
    // Alarm gece BİTİNCE susar: kullanıcı çalarken "geceyi bitir"e basmış olabilir
    // ve alarmın ekran kapandıktan sonra çalmaya devam etmesi kabul edilemez.
    _alarmTimer?.cancel();
    _alarmTimer = null;
    _alarm = null;
    await alarmSound?.stop();
    // Gece bitti → kurulu sistem backstop'u da sök: ekran kapandıktan sonra OS'un
    // son-tarihte alarmı çalması kabul edilemez.
    unawaited(alarmScheduler?.cancel());

    // Servis ÖNCE durdurulur: kayıt bittiyse bildirimin bir an bile fazladan
    // durması "hâlâ dinliyorum" izlenimi verirdi.
    await nightService.stop();
    final draft = await recorder.stop();
    if (draft == null) {
      _emit(_state.copyWith(isRecording: false));
      return;
    }

    // Zarf kaydedilir: kullanıcı isterse paylaşabilsin (otomatik gönderim YOK).
    _envelope = recorder.envelope;
    _emit(_state.copyWith(isRecording: false, alarmRinging: false, savedDraft: draft));

    try {
      await sleep.recordSession(draft);
      // CANLI DRAIN tetiği #2: kayıt başarılı → bağlantı var; bekleyen çevrimdışı
      // geceleri de şimdi boşaltmayı dene.
      await _drainQueue();
    } catch (e) {
      // Sunucuya yazılamadı → geceyi KAYBETME: çevrimdışı kuyruğa al (bağlantı gelince
      // boşaltılır). Kuyruk yoksa eski davranış: yalnızca hata gösterilir.
      // Yutulmaz — kayıt YİNE gösterilir: gece geçti, veri cihazda üretildi.
      await sessionQueue?.enqueue(draft);
      _emit(_state.copyWith(error: e.toString()));
    }
  }

  /// Bekleyen çevrimdışı geceleri sunucuya boşaltmayı dener. Controller kurulunca ve
  /// her başarılı kayıttan sonra çağrılır — "kuyruğa yaz ama hiç boşaltma" (ölü kod)
  /// tuzağını engeller. Uygulama ön plana dönünce de çağrılabilir (public).
  Future<void> drainPending() => _drainQueue();

  Future<void> _drainQueue() async {
    final queue = sessionQueue;
    if (queue == null) return;
    try {
      await queue.drain((draft) async {
        await sleep.recordSession(draft);
      });
    } catch (_) {
      // Drain hatası akışı KESMEZ: kalanlar kuyrukta korunur, bir sonraki tetikte
      // (açılış / sonraki başarılı kayıt) tekrar denenir.
    }
  }

  /// Gece zarfını CSV olarak paylaşır (docs/04 §120 fixture'ı).
  ///
  /// **YALNIZCA kullanıcı isterse.** Otomatik gönderim yok: bu veri onun cihazında
  /// üretildi ve orada kalır. Ham ses değil (saniyede 3 sayı) ama yine de onun.
  Future<void> shareEnvelope({required String text}) async {
    final env = _envelope;
    final s = sharer;
    if (env == null || s == null) return;

    await s.share(
      ShareContent(
        text: text,
        url: '',
        // CSV olarak paylaşılır: `codeUnits` yerine `ShareFile.csv` UTF-8 kodlar —
        // Türkçe karakter içeren başlık satırları bozulmasın.
        file: ShareFile.csv(text: env.toCsv(), filename: 'nocta-night-envelope.csv'),
      ),
    );
  }
}
