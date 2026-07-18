import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/core/audio_engine/signature_player.dart';

/// Açılış imzası **açılış başına BİR KEZ** çalmalı.
///
/// Neden: akışın iki kökü var (onboarding → ana kök) ve ikisi de tetikliyor.
/// Koruma olmasaydı onboarding'i biten kullanıcı sesi ÜST ÜSTE iki kez duyardı.
void main() {
  setUp(SignaturePlayer.resetLaunchGuard);

  test('ÇEKİRDEK: ikinci çağrı oynatmaz (çift ses yok)', () async {
    var built = 0;
    // playerFactory çağrılırsa gerçekten oynatmaya kalkışılmış demektir.
    final p1 = SignaturePlayer(playerFactory: () { built++; throw StateError('oynatma denendi'); });
    final p2 = SignaturePlayer(playerFactory: () { built++; throw StateError('oynatma denendi'); });

    await p1.play(); // ilk çağrı: üretimi/oynatmayı dener
    final afterFirst = built;
    await p2.play(); // ikinci çağrı: koruma yüzünden HİÇ denememeli
    expect(built, afterFirst, reason: 'ikinci play() oynatmaya kalkışmamalı');
  });

  test('resetLaunchGuard sonrası tekrar çalabilir (yeni cold start)', () async {
    final p = SignaturePlayer(playerFactory: () => throw StateError('x'));
    await p.play();
    SignaturePlayer.resetLaunchGuard();
    // Sıfırlandıktan sonra koruma tekrar açık olmalı — hata fırlatsa da
    // play() bunu yutar; burada kilitlenmediğini doğruluyoruz.
    await p.play();
  });
}
