import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// **KULLANICIYA GİDEN APK'nın izinleri.**
///
/// ## Neden bu test var — beş iterasyonluk bir yalanı kapatıyor
///
/// `src/main/AndroidManifest.xml` INTERNET izni TAŞIMIYORDU. Flutter şablonu onu
/// yalnızca `src/debug/` ve `src/profile/` manifestlerine koyar (hot reload için).
/// Yani release APK'da yoktu ve:
///
/// - **Ses hiç çıkmıyordu:** `BytesAudioSource` bir `StreamAudioSource`; just_audio
///   bellekteki WAV'ı beslemek için yerel bir proxy HTTP sunucusu açar. İzin yoksa
///   `SocketException: Failed to create server socket (errno = 1)`. Mikser (#138) ve
///   alarm (#146) release'de SESSİZDİ.
/// - API istemcisi tamamen ölüydü.
///
/// Beş iterasyon boyunca "cihazda doğruladım" dedim — hepsi **debug** build'diydi ve
/// debug manifesti izni gizlice ekliyordu. 375 test yeşildi. Hiçbiri bunu göremezdi.
///
/// ## Neden Dart testi, neden CI'da `aapt2 dump` değil
///
/// Bu süiti CI zaten koşuyor: yeni iş, yeni araç, yeni bakım yok. Ayrıca lokalde de
/// anında kırmızı yanar ve APK build etmeyi gerektirmez (aapt2 yolu build şartı
/// koşardı → yavaş ve yalnızca CI'da).
///
/// **Sınır (dürüstlük):** bu test KAYNAK manifesti okur, üretilmiş APK'yı değil. Gradle
/// birleştirmesinde ters giden bir şeyi göremez. Yakaladığı şey gerçek hataydı:
/// iznin main'de hiç olmaması.
void main() {
  late String manifest;

  setUpAll(() {
    // Testler paket kökünden koşar.
    final file = File('android/app/src/main/AndroidManifest.xml');
    expect(file.existsSync(), isTrue, reason: 'ana manifest bulunamadı');
    manifest = file.readAsStringSync();
  });

  bool hasPermission(String name) =>
      manifest.contains('android.permission.$name');

  test('ÇEKİRDEK: INTERNET — release APK\'da ses ve API buna bağlı', () {
    // Bu satır silinirse: mikser ve alarm sessizleşir, API ölür — ve DEBUG'da
    // her şey çalışmaya devam ettiği için kimse fark etmez.
    expect(
      hasPermission('INTERNET'),
      isTrue,
      reason: 'INTERNET main manifestte OLMALI; src/debug/ SAYILMAZ '
          '(kullanıcıya giden APK debug manifestini içermez)',
    );
  });

  test('ÇEKİRDEK: mikrofon ve gece boyu kayıt izinleri', () {
    // RECORD_AUDIO yoksa uyku takibi hiç başlamaz.
    expect(hasPermission('RECORD_AUDIO'), isTrue);
    // Android 14+ arka planda mikrofonu foreground service olmadan ÖLDÜRÜR →
    // kullanıcı sabah boş raporla uyanır (#142).
    expect(hasPermission('FOREGROUND_SERVICE'), isTrue);
    expect(hasPermission('FOREGROUND_SERVICE_MICROPHONE'), isTrue);
    // Foreground service kalıcı bildirim göstermek ZORUNDA (Android kuralı).
    expect(hasPermission('POST_NOTIFICATIONS'), isTrue);
  });

  test('ÇEKİRDEK: süreç-ölümüne dayanıklı alarm izinleri (#169)', () {
    // In-app Timer alarmı süreç öldürülünce sessizce ölür; native AlarmManager
    // backstop bu izinlere bağlı. Biri düşerse backstop kurulamaz ve alarm yine
    // "cebinde uygulama ölürse çalmayan alarm"a döner — sessizce.
    expect(hasPermission('USE_EXACT_ALARM'), isTrue,
        reason: 'kesin alarm (Android 14+ alarm-saati uygulaması) OLMALI');
    expect(hasPermission('SCHEDULE_EXACT_ALARM'), isTrue,
        reason: 'kesin alarm (Android 12/13 karşılığı) OLMALI');
    // Ekran kilitliyken alarmı tam-ekran göstermek için.
    expect(hasPermission('USE_FULL_SCREEN_INTENT'), isTrue);
    // Cihaz gece yeniden başlarsa alarm yeniden zamanlanabilsin.
    expect(hasPermission('RECEIVE_BOOT_COMPLETED'), isTrue);
  });

  test('ÇEKİRDEK: reboot alarmı yeniden kuran BootReceiver kayıtlı (#175)', () {
    // AlarmManager kayıtları reboot'ta silinir; BootReceiver BOOT_COMPLETED'te alarmı
    // yeniden kurar. Bu satır silinirse: gece reboot atan telefonda alarm sessizce ölür.
    expect(manifest.contains('.BootReceiver'), isTrue,
        reason: 'BootReceiver manifestte kayıtlı OLMALI');
    expect(manifest.contains('android.intent.action.BOOT_COMPLETED'), isTrue,
        reason: 'BootReceiver BOOT_COMPLETED dinlemeli');
  });

  test('gizlilik: manifest ham ses/konum izni İSTEMİYOR', () {
    // Uyku takibi on-device (CLAUDE.md §6). Bu izinlerden biri sızarsa mağaza
    // incelemesinde ve kullanıcı güveninde bedeli olur.
    expect(hasPermission('ACCESS_FINE_LOCATION'), isFalse);
    expect(hasPermission('ACCESS_COARSE_LOCATION'), isFalse);
    expect(hasPermission('READ_EXTERNAL_STORAGE'), isFalse);
    expect(hasPermission('WRITE_EXTERNAL_STORAGE'), isFalse);
  });
}
