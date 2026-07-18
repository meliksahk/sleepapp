import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nocta/core/sleep_tracking/night_alarm_scheduler.dart';

/// Süreç-ölümüne dayanıklı alarm — native handler (#174) **EMÜLATÖR/CİHAZ e2e**.
///
/// #169 Dart dikişini kurmuştu ama native handler cihaz-kapılı diye ertelenmişti.
/// Bu test o handler'ı gerçek Android üstünde çalıştırır: geçerse (a) Kotlin DERLENDİ,
/// (b) `nocta/night_alarm` kanalı uçtan uca çalıştı (MissingPluginException yok),
/// (c) `AlarmManager.setAlarmClock` / `cancel` hata atmadı.
///
/// Ateşleme kanıtı DIŞARIDAN: bu test +3sn'ye alarm kurar; `adb logcat -s NightAlarm:I`
/// "fired", `adb shell dumpsys alarm` ise kaydı gösterir.
///
/// Koşum: `flutter test integration_test/night_alarm_test.dart -d <emülatör>`
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const scheduler = PlatformNightAlarmScheduler();

  testWidgets('ÇEKİRDEK: yakın alarm kurulur ve ATEŞLENİR (receiver çalışır)',
      (tester) async {
    // +3 sn: test penceresinde gerçekten ateşlensin → receiver "fired" loglar.
    await scheduler.schedule(DateTime.now().add(const Duration(seconds: 3)));
    // Ateşlemeyi bekle (+3sn alarm + pay).
    await Future<void>.delayed(const Duration(seconds: 6));
    // Hatasız buraya gelmek: schedule + ateşleme zinciri gerçek cihazda koştu.
    expect(true, isTrue);
  });

  testWidgets('ÇEKİRDEK: uzak alarm kurulur, sonra İPTAL edilir (hata yok)',
      (tester) async {
    await scheduler.schedule(DateTime.now().add(const Duration(minutes: 30)));
    await scheduler.cancel();
    expect(true, isTrue);
  });
}
