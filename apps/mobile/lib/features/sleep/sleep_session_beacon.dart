import 'package:flutter/foundation.dart';

/// Aktif uyku oturumunun **kabuk-düzeyi ilan tahtası**.
///
/// ## Neden ayrı bir nesne, neden doğrudan `SleepModeController` değil
///
/// Sayaç şeridi uygulama kabuğunda (`MaterialApp.router`'ın `builder`'ı) yaşıyor —
/// yani AÇILIŞTA kurulur ve hiç sökülmez. Kabuk doğrudan
/// `sleepModeControllerProvider`'ı izleseydi, uygulama her açılışta gerçek
/// mikrofon adaptörünü, foreground servisi, alarm sesini ve güvenli depoyu
/// kurardı — kullanıcı uyku moduna hiç girmese bile. Bir uyku uygulamasında bu
/// hem pil hem gizlilik açısından savunulamaz.
///
/// Bu yüzden kabuk YALNIZCA bu hafif nesneyi izler: içinde tek bir tarih var,
/// hiçbir platform kanalı yok. Controller (varsa) buraya yazar; kabuk okur.
///
/// `ChangeNotifier` bilinçli: `notifyListeners` yalnızca gece BAŞLARKEN ve
/// BİTERKEN çağrılır (saniyede bir değil) — şeridin canlı sayacı kendi içinde,
/// çok daha dar bir kapsamda tazelenir (bkz. `SleepSessionStrip`).
class SleepSessionBeacon extends ChangeNotifier {
  DateTime? _startedAt;

  /// Süren oturumun başlangıcı; null ise oturum YOK.
  DateTime? get startedAt => _startedAt;

  bool get isActive => _startedAt != null;

  /// Oturum başladı. Aynı başlangıçla tekrar çağrılırsa dinleyiciler
  /// UYANDIRILMAZ — controller her durum değişiminde (olay sayacı dahil) bunu
  /// çağırır ve gereksiz kabuk rebuild'i pil demektir.
  void begin(DateTime at) {
    if (_startedAt == at) return;
    _startedAt = at;
    notifyListeners();
  }

  /// Oturum bitti. Zaten bitmişse dinleyiciler uyandırılmaz.
  void end() {
    if (_startedAt == null) return;
    _startedAt = null;
    notifyListeners();
  }
}

/// Geçen süreyi `sa:dk:sn` olarak biçimler.
///
/// Uyku modu ekranındaki büyük sayaç ile kabuk şeridi AYNI biçimi kullanmalı:
/// kullanıcı şeritten ekrana geçtiğinde iki farklı sayı görürse hangisine
/// güveneceğini bilemez. Bu yüzden biçimleyici tek yerde yaşar.
String formatElapsed(Duration d) {
  final safe = d.isNegative ? Duration.zero : d;
  final h = safe.inHours.toString().padLeft(2, '0');
  final m = (safe.inMinutes % 60).toString().padLeft(2, '0');
  final s = (safe.inSeconds % 60).toString().padLeft(2, '0');
  return '$h:$m:$s';
}
