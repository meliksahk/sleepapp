import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio_engine/dsp/mix_render.dart';
import '../../content/content_providers.dart';
import '../mixer_controller.dart' show MixerController;
import '../soundscape_mix.dart';
import 'mixer_screen.dart';

/// `/mixer` rotasının gövdesi: slug varsa mikseri O TARİFLE kurar.
///
/// **Neden query parametresi, neden go_router `extra` değil:** `extra` derin
/// linkte ve uygulama yeniden başlarken kaybolur; slug URL'de yaşar.
///
/// **Neden ayrı bir widget:** [MixerScreen] controller'ını `initState`'te bir kez
/// kurar. Tarif çözülmeden ekranı kurarsak yanlış tarifle kurulur ve sonradan
/// gelen doğru tarif yok sayılır. Bu sarmalayıcı, tarif belli olana kadar ekranı
/// KURMAZ — ama sonsuza kadar da beklemez (aşağı bak).
class MixerRoute extends ConsumerStatefulWidget {
  const MixerRoute({
    super.key,
    this.soundscapeSlug,
    this.resolveBudget = _budget,
    this.controllerFactory,
  });

  /// null/boş → doğrudan varsayılan mikser (ağ isteği YOK).
  final String? soundscapeSlug;

  /// Tarifin gelmesi için tanınan azami süre.
  ///
  /// Bu bütçe olmasaydı: API istemcisinde timeout YOK, yani ölü bir bağlantıda
  /// (kaptif portal, çok yavaş hat) kullanıcı çalan bir mikser yerine sonsuz
  /// spinner görürdü — CLAUDE.md §3.1'in "mikser internetsiz TAM çalışır"
  /// sözünün tam tersi. Süre dolunca varsayılan tarifle açılır.
  final Duration resolveBudget;

  /// Çözülen tariften controller kurar. Yalnızca test için ([MixerScreen]'in
  /// `controller` parametresiyle aynı gerekçe): cihazsız testte sahte
  /// `AudioPlayer` enjekte edilip "varsayılan tarifle GERÇEKTEN çalıyor"
  /// kanıtlanabilsin. Üretimde null → [MixerScreen] kendi controller'ını kurar.
  final MixerController Function(MixSpec spec)? controllerFactory;

  static const Duration _budget = Duration(seconds: 3);

  @override
  ConsumerState<MixerRoute> createState() => _MixerRouteState();
}

class _MixerRouteState extends ConsumerState<MixerRoute> {
  bool _budgetSpent = false;
  Timer? _timer;

  /// Bir kez kurulur: `build` her çalıştığında yeni controller üretmek, çalan
  /// sesin sahibini değiştirip eskisini sızdırırdı.
  MixerController? _controller;

  /// Varsayılan tarife düşüldü mü? Bir kez true olduysa geri dönmez (bkz. [build]).
  bool _fellBackForGood = false;

  @override
  void initState() {
    super.initState();
    if (widget.soundscapeSlug?.isNotEmpty ?? false) {
      _timer = Timer(widget.resolveBudget, () {
        if (mounted) setState(() => _budgetSpent = true);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slug = widget.soundscapeSlug;
    if (slug == null || slug.isEmpty) return const MixerScreen();

    final detail = ref.watch(soundscapeDetailProvider(slug));

    // Yalnızca ilk yükleme bekletir. Hata da, null da (bilinmeyen slug) beklemez:
    // ikisi de "tarif yok" demektir ve mikser varsayılanla AÇILIR.
    if (detail.isLoading && !detail.hasValue && !detail.hasError && !_budgetSpent) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(key: Key('mixer-resolving')),
        ),
      );
    }

    final resolved = resolveSoundscapeMix(detail.valueOrNull);

    // MANDAL (latch): bir kez varsayılana düştüysek bu KALICIDIR.
    //
    // NEDEN: `MixerScreen` tarifi yalnızca `initState`'te okur (çalan sesi kesmemek
    // için bilinçli). Bütçe dolup varsayılanla açıldıktan SONRA ağ yanıtı geç
    // gelirse, `resolved.usedFallback` false olur ve dipnot ekrandan SESSİZCE
    // silinirdi — ama ses hâlâ varsayılan mix. Kullanıcı seçtiği sesi duymadığı
    // hâlde bunu söyleyen tek işaret kaybolurdu; tam olarak Dürüstlük Protokolü'nün
    // yasakladığı şey. Üç ayrı denetim merceği bu yolu bağımsız olarak yakaladı.
    _fellBackForGood = _fellBackForGood || resolved.usedFallback;

    _controller ??= widget.controllerFactory?.call(resolved.spec);
    // Başlık: açılan sesin ADI (kullanıcının seçtiği şey). Tarif çözülemediyse
    // null kalır ve ekran jenerik başlığa düşer — var olmayan bir sesin adını
    // yazmaktansa "Mikser" demek dürüst olanı.
    final locale = Localizations.localeOf(context).languageCode;
    final title = detail.valueOrNull?.soundscape.title(locale);
    return MixerScreen(
      controller: _controller,
      spec: resolved.spec,
      recipeUnavailable: _fellBackForGood,
      title: title,
    );
  }
}
