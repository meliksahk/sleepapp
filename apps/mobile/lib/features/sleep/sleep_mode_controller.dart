import '../../core/sleep_tracking/night_service.dart';
import '../../core/sleep_tracking/sleep_recorder.dart';
import '../../core/sleep_tracking/sleep_session_builder.dart';
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

  SleepModeState copyWith({
    bool? isRecording,
    DateTime? startedAt,
    int? eventCount,
    SleepSessionDraft? savedDraft,
    String? error,
    bool? permissionDenied,
    bool? serviceFailed,
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
  }) {
    recorder.onProgress = () {
      // Canlı sayaç: kullanıcı gece kalkarsa "çalışıyor mu?" sorusuna cevap görür.
      _emit(_state.copyWith(eventCount: recorder.eventCount));
    };
  }

  /// Kayıt motoru — test sahte mikrofonlu bir tane enjekte eder.
  final SleepRecorder recorder;

  /// Oturumu sunucuya yazan controller.
  final SleepController sleep;

  /// Gece boyu süreci hayatta tutan foreground servis (Android 14+ ZORUNLU).
  final NightService nightService;

  SleepModeState _state = const SleepModeState();
  SleepModeState get state => _state;

  void Function()? onChanged;

  void _emit(SleepModeState next) {
    _state = next;
    onChanged?.call();
  }

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
  }

  /// Kaydı bitirir ve oturumu SUNUCUYA yazar.
  ///
  /// Sunucuya giden: başlangıç/bitiş + iki sayı. **Ham ses değil** (CLAUDE.md §6);
  /// zaten hiçbir yerde ham ses tutulmuyor (bkz. `SleepRecorder`).
  Future<void> stopAndSave() async {
    // Servis ÖNCE durdurulur: kayıt bittiyse bildirimin bir an bile fazladan
    // durması "hâlâ dinliyorum" izlenimi verirdi.
    await nightService.stop();
    final draft = await recorder.stop();
    if (draft == null) {
      _emit(_state.copyWith(isRecording: false));
      return;
    }

    _emit(_state.copyWith(isRecording: false, savedDraft: draft));

    try {
      await sleep.recordSession(draft);
    } catch (e) {
      // Yutulmaz — ama kayıt YİNE de gösterilir: gece geçti, veri cihazda üretildi;
      // sunucuya yazılamaması kullanıcının gecesini yok saymayı gerektirmez.
      // (Çevrimdışı kuyruk ayrı bir iş — defterde.)
      _emit(_state.copyWith(error: e.toString()));
    }
  }
}
