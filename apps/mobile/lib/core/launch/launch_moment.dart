import 'dart:async';
import 'package:flutter/material.dart';

import '../design_system/design_system.dart';
import 'launch_phase.dart';
import 'moon_painter.dart';

/// **Açılış anı kapısı** — dalgalanan ay, sonra mikroanimasyonla içeriğe geçiş.
///
/// Uygulamanın kökünü sarar ve açılış bitene kadar içeriğin ÜSTÜNDE durur.
/// Bittikten sonra tamamen şeffaftır (`build` doğrudan [child] döner), yani
/// çalışma zamanı maliyeti sıfırdır.
///
/// ## Kullanıcıyı BEKLETMEME sözleşmesi (üç kapı)
///
/// 1. **Üst sınır [launchCapSeconds]:** oturum kurulumu ne kadar sürerse sürsün
///    açılış anı 2.2 sn'de biter. Ağ ölüyse bile kullanıcı içeri girer —
///    "sonsuz splash" durumu YAPISAL olarak imkânsız.
/// 2. **Dokunuşla atlama:** ekrana dokunmak alt sınırı da bekletmeden geçişi
///    başlatır. Ses kesilmez (arka planda devam eder), yalnızca görsel kapı kalkar.
/// 3. **Alt sınır [launchHoldSeconds]:** içerik erken hazırsa bile 1.1 sn durulur.
///    Bu tek "bekletme" bilinçli: oturum önbellekten gelince bootstrap ~50 ms'de
///    biter ve alt sınır olmasaydı kullanıcı ayı HİÇ görmez, yalnızca bir kare
///    titreme görürdü. Gerekçesi ve süresi `launch_phase.dart`'ta.
///
/// ## Hareketi azalt
///
/// `MediaQuery.disableAnimations` açıkken hiç kare üretilmez ve HİÇBİR bekleme
/// uygulanmaz: içerik hazır olur olmaz doğrudan gösterilir (`AmbientBackdrop`
/// ile aynı kural). İçerik henüz hazır değilse durağan tek kare gösterilir —
/// siyah ekran değil ama animasyon da değil.
///
/// ## Dikiş: native splash → Flutter
///
/// İlk karenin zemini [NoctaColors.bgBase] (#0A0E1A) ve `flutter_native_splash`
/// rengi de aynı sabit. Farklı olsalardı açılışta görünür bir renk sıçraması
/// olurdu; `test/app/native_splash_seam_test.dart` bu eşleşmeyi kilitler.
class LaunchMoment extends StatefulWidget {
  const LaunchMoment({
    super.key,
    required this.ready,
    required this.child,
    this.onFinished,
  });

  /// Ana içerik gösterilebilir durumda mı (oturum/onboarding kapısı çözüldü mü).
  ///
  /// `false` iken [child] AĞACA HİÇ EKLENMEZ — yani açılış anı boyunca router
  /// kurulmaz, gereksiz iş yapılmaz.
  final bool ready;

  /// Açılış bitince gösterilecek uygulama kökü.
  final Widget child;

  /// Geçiş tamamlandığında bir kez çağrılır (test/telemetri gözlem noktası).
  final VoidCallback? onFinished;

  @override
  State<LaunchMoment> createState() => _LaunchMomentState();
}

enum _Stage { hold, exit, done }

class _LaunchMomentState extends State<LaunchMoment>
    with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: Duration(microseconds: (launchCapSeconds * 1e6).round()),
  );
  late final AnimationController _exit = AnimationController(
    vsync: this,
    duration: launchExitDuration,
  );

  /// Faz kaynağı: `setState` YERİNE notifier → kare başına build/layout yok,
  /// yalnızca `MoonPainter.paint` çalışır (ambient ile aynı desen).
  final ValueNotifier<LaunchPhase> _phase = ValueNotifier<LaunchPhase>(
    LaunchPhase.zero,
  );

  _Stage _stage = _Stage.hold;
  bool _reduceMotion = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _intro.addListener(_onTick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ??
        WidgetsBinding
            .instance
            .platformDispatcher
            .accessibilityFeatures
            .disableAnimations;
    if (_reduceMotion) {
      // Animasyon YOK. İçerik hazırsa hiç splash görünmez; değilse durağan kare.
      if (widget.ready) {
        _stage = _Stage.done;
      } else {
        _phase.value = launchPhaseAt(const Duration(milliseconds: 900));
        // ÜST SINIR BU YOLDA DA GEÇERLİ. Önceden yalnızca `_onTick` içinde
        // kontrol ediliyordu ve hareketi-azalt yolunda ticker hiç çalışmadığı
        // için sınır DEĞERLENDİRİLMİYORDU: bootstrap asılı kalırsa kullanıcı
        // durağan ayda SONSUZA KADAR bekliyordu (denetimde ölçüldü: 10 sn sonra
        // hâlâ splash). Sınıf notu bunun imkânsız olduğunu iddia ediyordu —
        // yanlıştı. Zamanlayıcı ticker'dan bağımsız çalışır.
        _capTimer = Timer(
          Duration(milliseconds: (launchCapSeconds * 1000).round()),
          () {
            if (mounted && _stage == _Stage.hold) _finish();
          },
        );
      }
      return;
    }
    _intro.forward();
  }

  @override
  void didUpdateWidget(LaunchMoment old) {
    super.didUpdateWidget(old);
    if (!widget.ready || _stage != _Stage.hold) return;
    if (_reduceMotion) {
      // Hareketi azalt: bekleme yok, geçiş animasyonu da yok.
      _finish();
      return;
    }
    // Normal yolda `_onTick` zaten her karede bakıyor; bu yalnızca alt sınır
    // DOLMUŞken içeriğin geç hazırlandığı durumu anında yakalamak için.
    if (_elapsedSeconds >= launchHoldSeconds) _beginExit();
  }

  Timer? _capTimer;

  double get _elapsedSeconds => _intro.value * launchCapSeconds;

  void _onTick() {
    final elapsed = Duration(microseconds: (_elapsedSeconds * 1e6).round());
    _phase.value = launchPhaseAt(elapsed);
    if (_stage != _Stage.hold) return;
    final t = _elapsedSeconds;
    // Üst sınır dolduysa içerik hazır OLMASA da geçilir (bkz. sınıf notu).
    if (t >= launchCapSeconds || (widget.ready && t >= launchHoldSeconds)) {
      _beginExit();
    }
  }

  /// Mikroanimasyonu başlatır: ay küçülüp sönerken içerik yükselerek girer.
  void _beginExit() {
    if (_stage != _Stage.hold) return;
    setState(() => _stage = _Stage.exit);
    // `_intro` DURDURULMAZ: ay geçiş boyunca donmasın, sönerken de yaşasın.
    _exit.forward().whenComplete(_finish);
  }

  void _finish() {
    if (!mounted || _stage == _Stage.done) return;
    // Ay artık ağaçta değil: saati de durdur. Yoksa `_intro` üst sınıra kadar
    // boşuna kare planlamaya devam eder (pil + testlerde gereksiz bekleme).
    _intro.stop();
    setState(() => _stage = _Stage.done);
    widget.onFinished?.call();
  }

  @override
  void dispose() {
    _capTimer?.cancel();
    _intro.removeListener(_onTick);
    _intro.dispose();
    _exit.dispose();
    _phase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_stage == _Stage.done) return widget.child;
    return _rootScaffolding(
      context,
      Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // Dikiş rengi: native splash ile AYNI sabit.
          const ColoredBox(color: NoctaColors.bgBase),
          if (_stage == _Stage.exit) _enteringContent(),
          _splashLayer(),
        ],
      ),
    );
  }

  /// Geçiş sırasında ana ekran: **yükselerek ve soluklaşarak** girer.
  ///
  /// 14 px'lik yükselme bilinçli olarak küçük — daha büyüğü "kaydırma" gibi
  /// okunur ve mikroanimasyon olmaktan çıkar.
  Widget _enteringContent() {
    return AnimatedBuilder(
      animation: _exit,
      builder: (context, child) {
        final v = Curves.easeOutCubic.transform(_exit.value);
        return Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 14 * (1 - v)),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }

  Widget _splashLayer() {
    final moon = RepaintBoundary(
      child: CustomPaint(
        key: const Key('launch-moon'),
        painter: MoonPainter(phase: _phase),
        child: const SizedBox.expand(),
      ),
    );

    if (_stage == _Stage.exit) {
      return IgnorePointer(
        child: AnimatedBuilder(
          animation: _exit,
          builder: (context, child) {
            final v = Curves.easeIn.transform(_exit.value);
            return Opacity(
              opacity: (1 - v).clamp(0.0, 1.0),
              // Ay hafifçe küçülür: "içeri çekilme" hissi. 0.88'in altında
              // geçiş bir animasyon değil, bir kaybolma gibi görünüyordu.
              child: Transform.scale(scale: 1 - 0.12 * v, child: child),
            );
          },
          child: moon,
        ),
      );
    }

    // Bekleme aşaması: her yerden dokunuşla atlanabilir.
    return GestureDetector(
      key: const Key('launch-skip'),
      behavior: HitTestBehavior.opaque,
      onTap: _beginExit,
      // Dekoratif ve metinsiz: ekran okuyucuya verilecek anlamlı bilgi yok.
      child: ExcludeSemantics(child: moon),
    );
  }

  /// Splash kendi kökünde yaşıyor (henüz `MaterialApp` yok) — `Stack` ve
  /// `Transform` için gereken en küçük iskele. Test bir `MediaQuery` sağladıysa
  /// ONA saygı gösterilir (hareketi-azalt testi bunun üstünde duruyor).
  Widget _rootScaffolding(BuildContext context, Widget child) {
    final Widget directional = Directionality(
      textDirection: TextDirection.ltr,
      child: child,
    );
    if (MediaQuery.maybeOf(context) != null) return directional;
    return MediaQuery.fromView(view: View.of(context), child: directional);
  }
}
