import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Gece boyu kaydın hayatta kalmasını sağlayan foreground servis.
///
/// ## Neden ZORUNLU (isteğe bağlı bir iyileştirme değil)
///
/// `targetSdk = 36` → Android 14+ kuralları. Android 14'ten beri **mikrofonu arka
/// planda kullanmak için `foregroundServiceType="microphone"` olan bir foreground
/// service ŞART**; yoksa ekran kapanınca sistem kaydı öldürür ve kullanıcı sabah
/// **boş bir raporla** uyanır — üstelik uygulama "dinliyorum" demiş olur. Bu, bir
/// özellik eksiği değil, kullanıcıya söylenmiş bir yalan olurdu.
///
/// `record` paketinin kendi dokümanı da bunu söylüyor: *"Background recording: this
/// behaviour is not supported by the plugin itself... use flutter_foreground_task."*
///
/// ## Kalıcı bildirim bir bedel değil, DÜRÜSTLÜK
///
/// Android foreground servisin bildirim göstermesini zorunlu kılar. Bu iyi: kullanıcı
/// mikrofonun açık olduğunu gece boyunca **görür**. Gizlemeye çalışmak (kural izin
/// verse bile) yanlış olurdu.
///
/// ## Port — neden doğrudan çağırmıyoruz
///
/// Widget testi gerçek bir Android servisi başlatamaz. Bu arayüz sayesinde
/// `SleepModeController` test edilebilir ve "servis gerçekten başlatıldı mı?"
/// iddiası doğrulanabilir.
abstract class NightService {
  /// Servisi başlatır. `false` → başlatılamadı (izin yok / sistem reddetti).
  ///
  /// **Çağıran bunu YOK SAYMAMALI:** servis yoksa kayıt gece yarısı sessizce ölür.
  Future<bool> start({required String title, required String body});

  Future<void> stop();

  Future<bool> get isRunning;
}

/// Gerçek uygulama (`flutter_foreground_task`, MIT).
class ForegroundNightService implements NightService {
  @override
  Future<bool> start({required String title, required String body}) async {
    // Bildirim izni Android 13+ için gerekli. Reddedilirse servis başlatılamaz →
    // sessizce devam etmek yerine false dönüp çağıranın karar vermesini sağlıyoruz.
    final permission = await FlutterForegroundTask.checkNotificationPermission();
    if (permission != NotificationPermission.granted) {
      final requested = await FlutterForegroundTask.requestNotificationPermission();
      if (requested != NotificationPermission.granted) return false;
    }

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'nocta_night',
        channelName: 'Sleep tracking',
        // LOW: gece boyunca duracak bir bildirim ses/titreşim çıkarmamalı —
        // uykuyu ölçen uygulamanın uykuyu bölmesi saçma olurdu.
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        playSound: false,
        enableVibration: false,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        // Kayıt ANA izolatta sürüyor; servisin işi yalnızca süreci hayatta tutmak.
        // Bu yüzden sık tetiklenen bir görev yok — 15 dk yalnızca servisin canlı
        // kaldığını sisteme göstermeye yeter ve pil harcamaz.
        eventAction: ForegroundTaskEventAction.repeat(900000),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );

    final result = await FlutterForegroundTask.startService(
      notificationTitle: title,
      notificationText: body,
    );
    return result is ServiceRequestSuccess;
  }

  @override
  Future<void> stop() async {
    // Sonucu YOK SAYIYORUZ: servis zaten çalışmıyorsa hata döner ve bu bir sorun
    // değil. Ama mikrofonu bırakmak `SleepRecorder.stop()`un işi — o ayrı ve kritik.
    await FlutterForegroundTask.stopService();
  }

  @override
  Future<bool> get isRunning => FlutterForegroundTask.isRunningService;
}

/// Test sahtesi.
class FakeNightService implements NightService {
  FakeNightService({this.canStart = true});

  final bool canStart;
  bool started = false;
  int startCalls = 0;
  int stopCalls = 0;
  String? lastTitle;

  @override
  Future<bool> start({required String title, required String body}) async {
    startCalls++;
    lastTitle = title;
    if (!canStart) return false;
    started = true;
    return true;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    started = false;
  }

  @override
  Future<bool> get isRunning async => started;
}
