import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';
import '../sleep_providers.dart';
import '../sleep_session_beacon.dart';

/// Süren geceyi **her ekranda** gösteren ince kabuk şeridi.
///
/// ## Neden kabukta, neden her ekrana tek tek değil
///
/// Sayaç yalnızca uyku modu ekranındaydı. Kullanıcı gece ritüelini başlatıp
/// mikser'e ya da kütüphaneye geçtiğinde oturumun SÜRDÜĞÜNÜ göremiyordu — bir
/// uyku uygulamasında "kayıt gerçekten çalışıyor mu?" en pahalı belirsizliktir
/// (cevabı ancak sabah öğrenilir). Şerit, çevrimdışı bandıyla aynı katmanda
/// (`MaterialApp.router`'ın `builder`'ı) yaşar: ekran başına eklemek gerekmez,
/// yeni bir ekran eklendiğinde unutulamaz.
///
/// ## Çift gösterim çözümü
///
/// Uyku modu ekranında zaten büyük bir sayaç var; şerit orada gizlenir. Karar
/// **rota** üzerinden verilir (bkz. [_StripGate]) — ekranın kendini haber
/// vermesiyle değil: ekran `initState`'te haber verseydi, kendisinden ÖNCE
/// çizilmiş bir atayı build sırasında kirletmiş olurdu.
class SleepSessionStrip extends ConsumerWidget {
  const SleepSessionStrip({super.key, required this.router, this.now});

  /// Rotayı okuduğumuz router. Enjekte ediliyor çünkü kabuğun `builder`
  /// context'i Router'ın ÜSTÜNDEDİR — `GoRouter.of(context)` orada çalışmaz.
  final GoRouter router;

  /// Şimdi. Enjekte edilebilir çünkü widget testinde saat SAHTE değildir:
  /// `tester.pump(1sn)` zamanlayıcıyı tetikler ama `DateTime.now()` yerinde
  /// sayar — sayacın gerçekten ilerlediğini ancak saati biz sürersek kanıtlarız.
  final DateTime Function()? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _StripGate(
      router: router,
      beacon: ref.watch(sleepSessionBeaconProvider),
      now: now ?? DateTime.now,
    );
  }
}

/// Şeridin görünüp görünmeyeceğine karar veren katman.
///
/// ## Neden elle dinleme, neden `ListenableBuilder` değil
///
/// İki kaynağı dinliyoruz: ilan tahtası (gece başladı/bitti) ve router'ın
/// delegesi (rota değişti). Router'ın bildirimi **build sırasında da gelebilir**
/// — ilk karede `Router` rotayı çözerken delegesini bildirir ve biz o Router'ın
/// ATASIYIZ. Zaten çizilmiş bir atayı build sırasında kirletmek Flutter'da
/// hatadır (`markNeedsBuild() called during build`); `ListenableBuilder` bunu
/// doğrudan yapıyor ve testler kırmızı yanıyordu. Bu yüzden bildirim geldiğinde
/// hangi fazda olduğumuza bakıp, gerekirse tazelemeyi kareden SONRAYA erteliyoruz.
///
/// **Kabul edilen sınır (dürüstlük):** rota değişimi build sırasında geldiğinde
/// şerit BİR kare geç gizlenir. Uyku moduna geçiş bir sayfa animasyonuyla olur,
/// yani o karede hedef ekranın büyük sayacı henüz yerine oturmamıştır — pratikte
/// görünmez. Alternatif (build sırasında zorla tazeleme) çalışmıyor.
class _StripGate extends StatefulWidget {
  const _StripGate({
    required this.router,
    required this.beacon,
    required this.now,
  });

  final GoRouter router;
  final SleepSessionBeacon beacon;
  final DateTime Function() now;

  @override
  State<_StripGate> createState() => _StripGateState();
}

class _StripGateState extends State<_StripGate> {
  Listenable? _sources;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant _StripGate old) {
    super.didUpdateWidget(old);
    if (old.beacon != widget.beacon || old.router != widget.router) {
      _sources?.removeListener(_onSourceChanged);
      _subscribe();
    }
  }

  void _subscribe() {
    _sources = Listenable.merge(
      <Listenable>[widget.beacon, widget.router.routerDelegate],
    )..addListener(_onSourceChanged);
  }

  void _onSourceChanged() {
    if (!mounted) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    final duringFrame = phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks;
    if (duringFrame) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
      return;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _sources?.removeListener(_onSourceChanged);
    super.dispose();
  }

  /// `push` ile açılan rotalar `RouteMatchList.uri`'ye YANSIMAZ (go_router
  /// belgesi: uri yalnızca imperative olmayan eşleşmeleri yansıtır). Bu yüzden
  /// `delegate.state.matchedLocation` okunur — o, imperative eşleşmenin kendi
  /// listesinden üretilir ve `push('/sleep-mode')` sonrası doğru cevabı verir.
  bool get _isOnSleepMode {
    final delegate = widget.router.routerDelegate;
    // İlk kare: henüz hiçbir eşleşme yok. `state` boş listede patlardı.
    if (delegate.currentConfiguration.isEmpty) return false;
    return delegate.state.matchedLocation == sleepModeRoutePath;
  }

  @override
  Widget build(BuildContext context) {
    final startedAt = widget.beacon.startedAt;
    // Gece yoksa hiçbir şey: sıfır boyut, sıfır timer, sıfır maliyet.
    if (startedAt == null) return const SizedBox.shrink();
    if (_isOnSleepMode) return const SizedBox.shrink();
    return _StripBar(
      startedAt: startedAt,
      now: widget.now,
      onTap: () => widget.router.push(sleepModeRoutePath),
    );
  }
}

/// Şeridin görünen gövdesi — canlı sayaç BURADA, dar bir kapsamda tazelenir.
class _StripBar extends StatefulWidget {
  const _StripBar({
    required this.startedAt,
    required this.now,
    required this.onTap,
  });

  final DateTime startedAt;
  final DateTime Function() now;
  final VoidCallback onTap;

  @override
  State<_StripBar> createState() => _StripBarState();
}

class _StripBarState extends State<_StripBar> {
  /// **Saniyelik tazeleme `setState` DEĞİL.** `setState` bu şeridin tamamını
  /// (Material + SafeArea + InkWell + Row + ikon) her saniye yeniden kurardı —
  /// ve şerit kabuğun içinde olduğu için ağacın tepesine yakın bir yerde.
  /// Değişen tek şey rakamlar; bu yüzden süre bir `ValueNotifier`'da tutulur ve
  /// yalnızca onu saran `ValueListenableBuilder` — tek bir `Text` — yeniden
  /// çizilir. Kabuk ve altındaki EKRAN AĞACI bundan hiç etkilenmez: notifier bu
  /// State'in içindedir, yukarı doğru hiçbir şeyi kirletmez.
  late final ValueNotifier<Duration> _elapsed;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _elapsed = ValueNotifier<Duration>(_since());
    _tick = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _elapsed.value = _since(),
    );
  }

  Duration _since() => widget.now().difference(widget.startedAt);

  @override
  void didUpdateWidget(covariant _StripBar old) {
    super.didUpdateWidget(old);
    if (old.startedAt != widget.startedAt) _elapsed.value = _since();
  }

  @override
  void dispose() {
    // Gece bitince şerit ağaçtan düşer → timer da düşer. "Ekranda yok ama hâlâ
    // saniyede bir uyanan" bir zamanlayıcı bırakmak pil sızıntısı olurdu.
    _tick?.cancel();
    _elapsed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Material(
      color: NoctaColors.bgOverlay,
      child: SafeArea(
        bottom: false,
        child: Semantics(
          button: true,
          label: l10n.sleepStripOpen,
          child: InkWell(
            key: const Key('sleep-strip'),
            onTap: widget.onTap,
            child: ConstrainedBox(
              // Dokunma hedefi ≥44px (CLAUDE.md §7) — şerit ince ama basılabilir.
              constraints: const BoxConstraints(minHeight: 44),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: NoctaSpace.s4,
                  vertical: NoctaSpace.s2,
                ),
                child: Row(
                  children: [
                    // **Sabit nokta, nabız animasyonu DEĞİL.** Yanıp sönen bir
                    // gösterge her karede bir ticker uyandırırdı — gece boyu
                    // açık duran bir şeritte bu, saniyelik sayaçtan da pahalı.
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: NoctaColors.accentAurora,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: NoctaSpace.s3),
                    Expanded(
                      child: Text(
                        // "Dinliyor…" TEK BAŞINA yetmezdi: mikser ekranında
                        // kullanıcı bunu çalan sesle karıştırırdı. Metin geceyi
                        // takip ettiğimizi açıkça söyler.
                        l10n.sleepStripActive,
                        key: const Key('sleep-strip-status'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: NoctaFontSize.caption,
                          color: NoctaColors.inkSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: NoctaSpace.s3),
                    ValueListenableBuilder<Duration>(
                      valueListenable: _elapsed,
                      builder: (context, value, _) => Text(
                        formatElapsed(value),
                        key: const Key('sleep-strip-elapsed'),
                        style: const TextStyle(
                          fontSize: NoctaFontSize.caption,
                          color: NoctaColors.inkPrimary,
                          // Rakamlar eşit genişlikte: sayaç her saniye
                          // sağa-sola oynamasın (gece boyu duran bir şerit).
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    const SizedBox(width: NoctaSpace.s1),
                    const Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: NoctaColors.inkFaint,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
