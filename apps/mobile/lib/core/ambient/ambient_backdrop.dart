import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../design_system/design_system.dart';
import 'ambient_painter.dart';
import 'ambient_phase.dart';

/// Kodla üretilen, döngüsel, meditatif arka plan animasyonu.
///
/// Video/GIF/Lottie **yok**: her kare `AmbientPainter` tarafından çizilir. Bunun
/// üç somut karşılığı var — (1) APK'ya tek bayt varlık eklenmez, (2) animasyon
/// kullanıcının arketip gradyanıyla renklenebilir (video bunu yapamaz), (3) faz,
/// ses motorunun modülasyon fazıyla aynı matematikten gelir (bkz. `ambient_phase.dart`).
///
/// ## PİL — bu widget gece boyu açık kalabilir
///
/// Üç kapı var, üçü de testle kanıtlanıyor:
/// 1. **Uygulama arka plana geçince tick DURUR** ([didChangeAppLifecycleState]).
/// 2. **Ekranda değilken kare üretilmez**: `Ticker` `TickerMode` ile susturulur
///    (başka bir route üstteyken Flutter bunu otomatik yapar).
/// 3. **Kare hızı sınırlı** ([framesPerSecond], varsayılan 12). Ticker vsync'te
///    (60–120 Hz) uyanır ama bir çıkarma + bir karşılaştırma yapıp döner; `paint`
///    yalnızca kova değiştiğinde çalışır. 12 fps seçimi meditatif hareket için
///    yeterli: en hızlı büyüklük 10 saniyede bir tam çevrim yapıyor, yani kare
///    başına ~3°'lik faz değişimi — 60 fps'te de aynı görüntü, 5× maliyetle.
///
/// ## FAZ SÜREKLİLİĞİ — saat, çizimle BİRLİKTE donar
///
/// Burada önce "saat durmaz, yalnızca çizim durur" deniyordu; gerekçe *"ses arka
/// planda çalmaya devam ettiği için dönüldüğünde animasyon sesin fazına oturur"*
/// idi. Ölçüm bu gerekçenin bedelini gösterdi: duraklat/devam ettir'de faz,
/// duraklama süresi kadar SIÇRIYOR ve ekranın ortalama parlaklığı **tek karede
/// ~%78** değişebiliyordu (12 fps'te normal kare başına değişimin ~41 katı).
/// Karanlık bir odada uykuya dalmakta olan kullanıcı için bu bir "devam etme"
/// değil, bir flaştır.
///
/// Gerekçe zaten sağlam değildi: `ambient_phase.dart`'ın belgelediği gibi faz
/// kilidi **periyottadır, playhead'de değil** — animasyon ile ses arasında
/// başlangıçtan gelen SABİT bir ofset zaten var ve kimse onu ölçmüyor. Yani
/// "sesin fazına oturmak" hiçbir zaman gerçekleşmiyordu; sıçrama ise gerçekti.
///
/// Bu yüzden duraklarken [_pausedOffset] biriktirilir: devam edildiğinde ilk kare
/// son kareyle BİREBİR aynıdır (ölçüm: `ambient_resume_test.dart`). Periyot
/// kilidi bozulmaz, yalnızca ofset büyür.
class AmbientBackdrop extends StatefulWidget {
  const AmbientBackdrop({
    super.key,
    this.gradient,
    this.gains = const <String, double>{},
    this.framesPerSecond = 12,
    this.clock,
    this.onFrame,
    this.child,
  }) : assert(framesPerSecond > 0, 'kare hızı pozitif olmalı');

  /// Kullanıcının kimlik gradyanı (`archetypeGradientForSlug(...)`).
  ///
  /// **Neden slug değil gradyan:** `core/` katmanı `features/`'a bağımlı olamaz
  /// (CLAUDE.md §3.1 bağımlılık yönü). Arketip → gradyan çevirisini çağıran yapar;
  /// kullanıcı henüz test yapmadıysa null geçilir ve [brandGradient] kullanılır.
  final LinearGradient? gradient;

  /// `MixerState.gains` — mikserdeki denge görselin karakterini sürer.
  final Map<String, double> gains;

  /// Üretilecek azami kare/saniye. Görsel etkiyi değiştirmeden pili korur.
  final int framesPerSecond;

  /// Geçen süreyi veren saat. Üretimde null (dahili `Stopwatch` kullanılır);
  /// testler zamanı deterministik ilerletmek için buradan enjekte eder.
  final Duration Function()? clock;

  /// Üretilen kare sayısı (kümülatif). Test ve telemetri için gözlem noktası.
  final void Function(int frames)? onFrame;

  /// Arka planın ÜSTÜNE çizilecek içerik.
  final Widget? child;

  /// Kimlik yokken kullanılan marka gradyanı (token'lardan; hard-code hex yok).
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[NoctaColors.accentAurora, NoctaColors.accentDeep],
  );

  @override
  State<AmbientBackdrop> createState() => _AmbientBackdropState();
}

class _AmbientBackdropState extends State<AmbientBackdrop>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker;
  final ValueNotifier<AmbientPhase> _phase =
      ValueNotifier<AmbientPhase>(AmbientPhase.zero);

  /// Duvar saati. Kendisi durmaz; duraklamalar [_pausedOffset] ile düşülür —
  /// böylece enjekte edilen test saati de üretimdeki saatle AYNI yolu izler
  /// (freeze mantığı deterministik olarak test edilebilir).
  final Stopwatch _stopwatch = Stopwatch();

  /// Duraklamalarda geçen toplam süre. Görsel zaman = ham saat − bu.
  Duration _pausedOffset = Duration.zero;

  /// Duraklamanın başladığı ham an; koşarken null.
  Duration? _pausedAt;

  int _bucket = -1;
  int _frames = 0;

  /// Erişilebilirlik: "hareketi azalt" açıkken hiç kare üretilmez.
  bool _reduceMotion = false;

  /// Uygulama ön planda mı (`resumed`).
  bool _appResumed = true;

  /// Bu alt ağaçta animasyon açık mı (`TickerMode`). Mikser player'da bu
  /// doğrudan "ses çalıyor mu" demektir.
  bool _tickerModeEnabled = true;

  /// Üçü de doğruysa kare üretilir; biri bile düşerse zaman DA durur.
  bool get _shouldRun => _appResumed && _tickerModeEnabled && !_reduceMotion;

  /// Ham (durdurulmamış) saat.
  Duration get _rawElapsed => widget.clock?.call() ?? _stopwatch.elapsed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _stopwatch.start();
    _ticker = createTicker(_onTick);
    _ticker.start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // `TickerMode.valuesOf` bir bağımlılık kurar: kapatıldığında bu metot yeniden
    // çağrılır. Ticker'ın kendisini `SingleTickerProviderStateMixin` zaten
    // susturuyor; bizim buradaki işimiz SAATİ de durdurmak (faz sürekliliği).
    // (`TickerMode.of` 3.35'te deprecated.)
    _tickerModeEnabled = TickerMode.valuesOf(context).enabled;
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final reduceTurnedOn = reduce && !_reduceMotion;
    _reduceMotion = reduce;
    _applyRunState();
    if (reduceTurnedOn) {
      // Durağan ama ölü olmayan bir kare: zarfların tepesinin yarısı.
      _phase.value = ambientPhaseAt(
        Duration(milliseconds: (ambientSwellPeriod() * 250).round()),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // `resumed` DIŞINDAKİ her durumda (inactive/paused/hidden/detached) tick durur.
    // Beyaz liste değil kara liste kullanmak, ileride eklenecek bir durumda
    // sessizce "açık kalma" tarafına düşmemizi engeller.
    _appResumed = state == AppLifecycleState.resumed;
    _applyRunState();
  }

  /// Tek karar noktası: koşmalı mıyız, koşmamalı mıyız.
  ///
  /// Üç kapının (yaşam döngüsü, TickerMode, hareketi azalt) AYRI ayrı start/stop
  /// çağırması, biri kapalıyken diğerinin saati çözmesine yol açardı — o da tam
  /// olarak düzeltmeye çalıştığımız faz sıçramasını geri getirirdi.
  void _applyRunState() {
    if (_shouldRun) {
      final pausedAt = _pausedAt;
      if (pausedAt != null) {
        _pausedOffset += _rawElapsed - pausedAt;
        _pausedAt = null;
      }
      if (!_ticker.isActive) _ticker.start();
    } else {
      _pausedAt ??= _rawElapsed;
      if (_ticker.isActive) _ticker.stop();
    }
  }

  /// Vsync'te çağrılır (60–120 Hz) ama işin neredeyse tamamı burada elenir.
  void _onTick(Duration _) {
    final elapsed = _rawElapsed - _pausedOffset;
    // Kare kovası: aynı kovadaysak boya YOK.
    final bucket =
        elapsed.inMicroseconds * widget.framesPerSecond ~/ Duration.microsecondsPerSecond;
    if (bucket == _bucket) return;
    _bucket = bucket;
    _frames++;
    // `setState` YOK: yalnızca notifier güncellenir → build/layout atlanır,
    // sadece `AmbientPainter.paint` çalışır.
    _phase.value = ambientPhaseAt(elapsed);
    widget.onFrame?.call(_frames);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _phase.dispose();
    _stopwatch.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        key: const Key('ambient-backdrop'),
        painter: AmbientPainter(
          phase: _phase,
          gradient: widget.gradient ?? AmbientBackdrop.brandGradient,
          drive: AmbientDrive.fromGains(widget.gains),
        ),
        // `child` kendi RepaintBoundary'sinde: arka planın her karesi üstteki UI'ı
        // yeniden boyamaya ZORLAMASIN. Bu olmadan 12 fps'lik arka plan, tüm
        // player ekranını saniyede 12 kez yeniden boyatırdı.
        child: RepaintBoundary(
          child: widget.child ?? const SizedBox.expand(),
        ),
      ),
    );
  }
}
