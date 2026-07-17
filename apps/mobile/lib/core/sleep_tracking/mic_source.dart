import 'dart:async';
import 'dart:typed_data';

/// Mikrofon çerçeve kaynağı — uyku takibinin GİRDİSİ.
///
/// ## Neden bir PORT (doğrudan `record` çağırmıyoruz)
///
/// 1. **Test:** gerçek mikrofonla otomatik test edilemez; sahte kaynak enjekte edilir.
/// 2. **Kural zorlaması (CLAUDE.md §6):** *"mikrofon verisi ASLA ham yüklenmez — uyku
///    takibi analizi on-device yapılır, sunucuya yalnızca türetilmiş metrikler gider."*
///    Bu port `Stream<Float32List>` verir ve tüketicisi (`SleepRecorder`) her çerçeveyi
///    anında bir `double` dB değerine indirger. **Ham ses hiçbir yerde biriktirilmez** —
///    ne bellekte, ne diskte. Yani "yanlışlıkla yüklemek" için ortada veri yok:
///    kuralı yorum değil, veri akışının şekli zorluyor.
///
/// Uygulamalar çerçeveleri [-1, 1] aralığında mono örnekler olarak vermelidir.
abstract class MicSource {
  /// Kayda başlar ve çerçeve akışı döner.
  ///
  /// Akış YALNIZCA [stop] çağrılana kadar sürer. İzin reddedilirse hata fırlatır —
  /// sessizce boş akış dönmek, kullanıcıya "kaydediyorum" derken hiçbir şey
  /// kaydetmemek olurdu (en kötü hata: sabahı yalanla karşılamak).
  Stream<Float32List> start({required int sampleRate});

  /// Kaydı durdurur ve kaynakları bırakır.
  Future<void> stop();

  /// Mikrofon izni var mı / verildi mi.
  Future<bool> hasPermission();
}

/// Test/geliştirme için sahte kaynak: verilen çerçeveleri sırayla yayınlar.
///
/// **`StreamController`, `async*` DEĞİL** — ve bu bilinçli bir düzeltme:
/// `async*` üreteci widget testinin SAHTE ZAMAN bölgesinde `cancel()` beklerken
/// KİLİTLENİYOR (üretecin bir sonraki askıya alma noktasına ilerlemesi gerekiyor,
/// o da pump olmadan gelmiyor). Sonuç: `stop()` hiç dönmüyor ve test sessizce asılı
/// kalıyordu. Üstelik `StreamController` gerçek dünyaya da daha yakın: `record`
/// paketi de olay-güdümlü bir akış verir, üreteç değil.
class FakeMicSource implements MicSource {
  FakeMicSource(this.frames, {this.permission = true});

  final List<Float32List> frames;
  final bool permission;
  bool stopped = false;

  StreamController<Float32List>? _controller;

  @override
  Future<bool> hasPermission() async => permission;

  @override
  Stream<Float32List> start({required int sampleRate}) {
    final controller = StreamController<Float32List>();
    _controller = controller;
    // Dinleyici bağlanır bağlanmaz tüm çerçeveleri gönder, sonra kapat: gerçek
    // mikrofonun aksine bekleyecek bir şey yok.
    controller.onListen = () {
      for (final f in frames) {
        if (stopped) break;
        controller.add(f);
      }
      controller.close();
    };
    return controller.stream;
  }

  @override
  Future<void> stop() async {
    stopped = true;
    final c = _controller;
    _controller = null;
    // **`close()` BEKLENMEZ — kilitlenme:** `close()`ın döndüğü future "done olayı
    // teslim edildiğinde" tamamlanır. Abonelik ZATEN iptal edilmişse (çağıran önce
    // `cancel()` yapar) done kimseye teslim edilemez → future ASLA tamamlanmaz ve
    // `stop()` sonsuza kadar asılı kalır. Bu tam olarak oldu: test sessizce dondu.
    if (c != null && !c.isClosed) {
      unawaited(c.close());
    }
  }
}
