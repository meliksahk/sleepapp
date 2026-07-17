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
  });

  final bool isRecording;
  final DateTime? startedAt;
  final int eventCount;

  /// Kaydedilen oturum — gece raporuna geçiş için.
  final SleepSessionDraft? savedDraft;

  final String? error;

  /// Mikrofon izni reddedildi: bir hata DEĞİL, kullanıcının kararı — ayrı gösterilir.
  final bool permissionDenied;

  SleepModeState copyWith({
    bool? isRecording,
    DateTime? startedAt,
    int? eventCount,
    SleepSessionDraft? savedDraft,
    String? error,
    bool? permissionDenied,
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
  SleepModeController({required this.recorder, required this.sleep}) {
    recorder.onProgress = () {
      // Canlı sayaç: kullanıcı gece kalkarsa "çalışıyor mu?" sorusuna cevap görür.
      _emit(_state.copyWith(eventCount: recorder.eventCount));
    };
  }

  /// Kayıt motoru — test sahte mikrofonlu bir tane enjekte eder.
  final SleepRecorder recorder;

  /// Oturumu sunucuya yazan controller.
  final SleepController sleep;

  SleepModeState _state = const SleepModeState();
  SleepModeState get state => _state;

  void Function()? onChanged;

  void _emit(SleepModeState next) {
    _state = next;
    onChanged?.call();
  }

  Future<void> start() async {
    _emit(
      _state.copyWith(
        clearError: true,
        clearDraft: true,
        permissionDenied: false,
      ),
    );

    final ok = await recorder.start();
    if (!ok) {
      // İzin reddi hata değil: kullanıcı bilinçli bir seçim yaptı, ekran bunu
      // "bir şeyler ters gitti" gibi göstermemeli.
      _emit(_state.copyWith(permissionDenied: true));
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
