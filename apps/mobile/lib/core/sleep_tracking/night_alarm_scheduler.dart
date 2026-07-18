import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Süreç ölse bile alarmı garanti eden **sistem-zamanlı backstop** portu.
///
/// ## Neden var — in-app alarmın tek zayıf noktası
///
/// Akıllı alarm (`SmartAlarm`) ana izolatta `Timer.periodic` ile tick'lenir
/// (`SleepModeController._armAlarm`). Foreground servis süreci gece boyu ayakta
/// tutar; ama OS süreci gerçekten öldürürse (Doze, OEM pil katili, OOM, kullanıcı
/// uygulamayı kaydırıp kapatır) **Timer da ölür ve alarm sessizce hiç çalmaz** —
/// bir uyku uygulamasının yapabileceği en pahalı hata (kullanıcı işe geç kalır).
///
/// Bu port son-tarih anını İŞLETİM SİSTEMİNE kaydeder: uygulama ölü olsa bile OS
/// kullanıcıyı uyandırır. In-app akıllı alarm BİRİNCİL yoldur (hafif uykuda erken
/// çalar, daha iyi UX); bu yalnızca EK güvence — birincil yolu asla regrese etmez.
///
/// Soyutlama şart: "alarm ölü süreçte de kurulur mu?" cihazsız test edilemez, ama
/// controller'ın onu DOĞRU anda kurup/iptal ettiği bir sahte ile test edilebilir.
abstract class NightAlarmScheduler {
  /// [at] anına sistemde kesin (Doze'da bile) uyandırma alarmı kurar.
  /// Bir gecede tek alarm — ikinci çağrı öncekini üzerine yazar.
  Future<void> schedule(DateTime at);

  /// Kurulu sistem alarmını iptal eder (alarm susunca / gece bitince / alarm
  /// kaldırılınca). Zaten yoksa sorun değil.
  Future<void> cancel();
}

/// Native `AlarmManager` (Android) uygulaması — `MethodChannel` üzerinden.
///
/// **DÜRÜSTLÜK SINIRI — native handler henüz yok (cihaz-kapılı).** Kanal sözleşmesi
/// (`schedule`/`cancel` + `epochMillis`) burada tanımlı ve testli; ama `AlarmManager`'ı
/// gerçekten kuran Kotlin tarafı (`setExactAndAllowWhileIdle` + full-screen bildirimi)
/// yazılmadı — o kod ancak Gradle/cihaz build'iyle derlenip doğrulanabilir (Flutter
/// CI yalnızca `analyze`+`test` koşar, APK derlemez). O gelene kadar `schedule`/`cancel`
/// `MissingPluginException` alır ve **EN İYİ ÇABA** ile yutulur: eksik native taraf,
/// çalışan in-app alarmı ASLA bozmaz. Kanal adı/anahtarları Kotlin tarafıyla eşleşmeli.
class PlatformNightAlarmScheduler implements NightAlarmScheduler {
  const PlatformNightAlarmScheduler();

  static const MethodChannel channel = MethodChannel('nocta/night_alarm');

  @override
  Future<void> schedule(DateTime at) => _bestEffort(
        () => channel.invokeMethod<void>('schedule', <String, Object>{
          'epochMillis': at.millisecondsSinceEpoch,
        }),
      );

  @override
  Future<void> cancel() => _bestEffort(() => channel.invokeMethod<void>('cancel'));

  /// Backstop en iyi çabadır: native handler yoksa (iOS — henüz yazılmadı; eski
  /// Android) ya da OS reddederse in-app alarm birincil kalır, akış BOZULMAZ.
  /// Hata yutulur ama loglanır — sessiz değil, engelleyici değil (CLAUDE.md §4).
  static Future<void> _bestEffort(Future<void> Function() op) async {
    try {
      await op();
    } on MissingPluginException {
      // Native taraf yok (iOS / native handler henüz yazılmadı) → in-app alarm
      // birincil yol, sistem backstop'u devre dışı. Beklenen durum, hata değil.
      debugPrint('[night_alarm] native handler yok — sistem backstop atlandı');
    } on PlatformException catch (e) {
      debugPrint('[night_alarm] sistem alarmı kurulamadı: ${e.message}');
    }
  }
}
