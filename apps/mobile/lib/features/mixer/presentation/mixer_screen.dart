import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ambient/ambient.dart';
import '../../../core/audio_engine/dsp/mix_render.dart';
import '../../../core/design_system/design_system.dart';
import '../../../core/share/sharer.dart';
import '../../../l10n/app_localizations.dart';
import '../../archetype/archetype_gradient.dart';
import '../../archetype/archetype_providers.dart';
import '../mixer_controller.dart';

/// Mikser **PLAYER'ı** — uygulamanın ses çıkardığı ekran.
///
/// ## Neden düz listeden player'a
///
/// Ekran, üst üste dizilmiş 7 sürgüden ibaretti: bir ses uygulamasından çok bir
/// ayarlar sayfasına benziyordu. Kullanıcı gece boyu bu ekrana bakıyor; baktığı
/// şeyin "çalan bir şey" olduğunu söylemesi gerekiyor. Üç bölge:
///
/// 1. **Arka plan** — [AmbientBackdrop]. Ekranın tamamını kaplar, AppBar'ın da
///    ardında yaşar (`extendBodyBehindAppBar`). Kullanıcının arketip gradyanıyla
///    renklenir ve kabaran hareketi ses motorunun modülasyon fazından gelir.
/// 2. **Hero** — çalan şeyin ADI + durumu, [kPlayerScrimAlpha] zemin üzerinde.
///
///    Burada scrim ÖNCE YOKTU ve gerekçesi ("orası zaten en koyu bölge: taban
///    gradyanı bgBase'e %74 karartılmış") YANLIŞTI: yalnızca TABAN katmanını
///    hesaba katıyor, painter'ın kendi `BlendMode.plus` ışımalarını unutuyordu.
///    Işıma merkezleri tam da hero metinlerinin bulunduğu banda düşüyor. İki
///    bağımsız denetim, GERÇEK render edilmiş piksellerden ölçtü: küçük metinler
///    (11-13pt, inkSecondary) dört arketipte de 1.10–2.15 kontrast veriyordu —
///    WCAG AA eşiği 4.5'in üç-dört katı altında; dawn-chaser'da 34pt başlık bile
///    büyük-metin eşiği 3.0'ı geçemiyordu (2.49). CLAUDE.md §7 ihlali.
/// 3. **Kontrol sayfası** — katman sürgüleri KAYDIRILIR, taşıma kontrolleri
///    SABİT. Katman sayısı 3→7 olduğunda çal butonu ekranın altına düşmüştü
///    (#213); burada butonların erişilebilirliği katman sayısından yapısal
///    olarak bağımsız.
///
/// ## Dikey bütçe: neden `Expanded(flex: 3/5)` DEĞİL
///
/// İlk player düzeni hero'ya `Expanded(flex: 3)`, kontrollere `flex: 5`
/// veriyordu. Emülatörde iki kusur birden çıktı ve ikisinin de sebebi buydu:
///
/// - Hero, içeriğinin (~126 px) **iki-üç katı** yer kaplıyordu (869 px'lik gövdede
///   325 px) ve içerik `reverse: true` ile alta yaslandığı için artan ~200 px
///   ekranın TEPESİNDE boş duruyordu. Üstelik o boşluğun üstü scrim'in EN KOYU
///   ucuydu (0.86) — yani ambiyans da görünmüyordu: ölü alan.
/// - Kontrol sayfasına kalan %62.5'ten önce ~250 px sabit kabuk (tutamaç, başlık,
///   taşıma çubuğu) düşülüyor, kaydırılan katman alanına ARTAN kalıyordu. Ölçüm:
///   411×869'da 223 px (3 sürgü), 390×844'te 207 px (2 sürgü), 320×568'de
///   **35 px** (tek bir sürgünün etiketi). Yedi katmanlı bir mikserin tek katman
///   göstermesi bu aritmetiğin sonucuydu.
///
/// Şimdi hero **içeriği kadar** yer kaplıyor (ekran yüksekliğinin %34'ü ile
/// sınırlı; aşarsa kendi içinde kaydırılır), artan HER piksel katman listesine
/// gidiyor. Ölçüm `mixer_player_test.dart`'ta kilitli.
///
/// ## Scrim: TEK sürekli örtü, iki ayrı kutu değil
///
/// Önceki düzende hero'nun scrim'i altta 0.0'a sönüyor, hemen ardından kontrol
/// sayfası 0.72 ile başlıyordu: aradaki **0.72'lik alfa basamağı** ekranda düz,
/// keskin bir yatay çizgi olarak görünüyordu (emülatör görüntüsünde üst üçte bir).
/// Yuvarlatılmış köşeler ve "tutamaç" bu kenarı tasarım gibi göstermeye
/// çalışıyordu ama gördüğümüz şey bir panel değil, bir dikişti.
///
/// Çözüm basamağı kaldırmak: yukarıdan aşağı **monoton** tek bir profil —
/// 0.0 → (yumuşama bandı) → [kPlayerScrimAlpha] → aynı değerde ekran sonuna
/// kadar. Hero ile kontrol bölgesi artık AYNI rengi paylaştığı için aralarında
/// çizilecek bir kenar yok. Ambiyans, üstteki yumuşama bandında (AppBar'ın da
/// yaşadığı yer) net görünür; aşağıda ise scrim'in içinden %20 geçer.
///
/// ## Hareket YALNIZCA ses çalarken (bilinçli, iki gerekçe)
///
/// Arka plan `TickerMode(enabled: isPlaying)` içinde. Duraklatınca animasyon
/// donar, çalınca devam eder.
/// - **Dürüstlük:** görsel kabarma ses zarfıyla aynı matematikten geliyor. Ses
///   yokken kabarmaya devam etmek, olmayan bir şeyi varmış gibi göstermek olurdu.
/// - **Pil:** ekran açık ama ses duraklatılmışken kare üretimi tam SIFIR.
///
/// Duraklarken **saat de donar** — devam edilince faz sıçramaz. Gerekçesi ve
/// ölçümü `AmbientBackdrop`'ta.
///
/// ## Uyku sayacı NEREDE
///
/// Bu ekranda İKİNCİ bir sayaç YOK. Süren gece, uygulama kabuğundaki
/// `SleepSessionStrip`'te (çevrimdışı bandıyla aynı katman) zaten her ekranda
/// görünüyor — mikser dahil. Buraya bir kopya koymak, uyku modu ekranında
/// bilinçli olarak kaçınılan çift gösterimi mikserde geri getirirdi. Kanıt:
/// `test/app/sleep_session_strip_test.dart` ve `mixer_player_test.dart`.
/// Player scrim'inin **tek** alfası: hero metin bandı da kontrol bölgesi de bunu
/// kullanır (iki farklı değer = aralarında görünür bir basamak = dikiş).
///
/// Değer TAHMİN DEĞİL, ölçüm: `player_contrast_test.dart` üretimdeki painter'ı
/// gerçekten piksellere render edip en kötü (en parlak) zemin üzerinde
/// `inkSecondary` kontrastını hesaplıyor. Düz scrim taraması:
///
/// | alfa | en kötü kontrast |
/// |------|------------------|
/// | 0.72 | 4.45 ❌ (AA 4.5) |
/// | 0.78 | 5.14             |
/// | 0.80 | **5.35**         |
/// | 0.86 | 6.20             |
///
/// 0.80 seçildi: AA'yı ~%19 marjla geçiyor ve ambiyansın %20'si hâlâ geçiyor.
/// Yükseltmek okunabilirliği değil yalnızca ambiyansı etkiler.
///
/// ⚠️ Eski değer 0.72 idi ve AA eşiğinin ALTINDA kalıyordu (4.45) — kontrast
/// testi bunu yakalayamıyordu çünkü test, üretimdeki scrim'i kopyalamıştı ve
/// kopya üretimden farklıydı (bkz. rapor). Artık test bu sabiti import ediyor.
const double kPlayerScrimAlpha = 0.80;

/// Scrim'in 0'dan [kPlayerScrimAlpha]'ya çıktığı yumuşama bandının yüksekliği.
///
/// Ekran uzunken kullanılan değer; kısa ekranda oransal olarak (en az 48 px'e
/// kadar) kısalır. 48'in altı görünür bir kenar demektir — dikişi geri getirir.
const double kPlayerScrimFadeHeight = 88;

/// Kontrol bölgesinin (katman başlığı + taşıma çubuğu) **ölçülmüş** asgari
/// yüksekliği. Katman listesi tamamen kaybolduğunda geriye kalan budur.
///
/// Ölçüm (varsayılan yazı ölçeği): başlık bloğu 36 + taşıma çubuğu
/// (8 + çal 52 + 12 + video 48 + 12 + erken-sürüm notu + 20).
/// - **EN**: not 2 satır → toplam 230
/// - **TR**: not 320 px genişlikte 3 satıra sarıyor → toplam 244
///
/// 252 seçildi: ölçülen en kötü dilin 8 px üstü.
///
/// **Ne işe yarıyor:** kısa ekranda yer BİTTİĞİNDE önce hero geri adım atsın
/// diye. Denetimde 320×568'de çevrimdışı bandı + gece şeridi birlikteyken düzen
/// 43 px taşıyordu; taşan taraf her zaman taşıma çubuğuydu, çünkü hero sabit
/// payını korurken sıkışan hep en alttaki (ve en önemli) kontroldü.
///
/// ⚠️ **Bu sabit ÖLÇÜLMÜŞ bir sayıdır, türetilmiş değil.** Yeni bir dil, daha
/// uzun bir çeviri veya yeni bir taşıma öğesi onu geçersiz kılar; o durumda
/// düzen yine taşar. Bekçisi `mixer_small_screen_test.dart`: en dar ekran ×
/// dört kabuk kombinasyonu × iki dil. Yazı ölçeği büyütüldüğünde (a11y)
/// KAPSANMADI — bkz. rapor.
const double kPlayerControlsMinHeight = 252;

/// Yumuşama bandının gradyanı — **üretim ve test aynı fonksiyonu çağırır.**
///
/// Duraklar `smoothstep`e (3t²−2t³) yakınsıyor: iki uçta da eğim sıfıra yaklaşır.
/// Doğrusal bir rampa hem başladığı hem bittiği yerde bir "kırık" bırakır ve koyu
/// bir zeminde bu kırık Mach bandı olarak görünür — yani dikişi bir yerden
/// kaldırıp iki yerde daha zayıf hâlde geri getirirdi.
LinearGradient playerScrimFade() {
  const ease = <double>[0.0, 0.15625, 0.5, 0.84375, 1.0];
  return LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[
      for (final e in ease)
        NoctaColors.bgBase.withValues(alpha: kPlayerScrimAlpha * e),
    ],
    stops: const <double>[0.0, 0.25, 0.5, 0.75, 1.0],
  );
}

class MixerScreen extends ConsumerStatefulWidget {
  const MixerScreen({
    super.key,
    this.controller,
    this.sharer,
    this.canExportVideo,
    this.spec,
    this.recipeUnavailable = false,
    this.title,
  });

  /// Çalan sesin ADI — player'ın hero başlığı.
  ///
  /// **Neden:** kullanıcı kütüphaneden belirli bir soundscape'e dokunup mikseri
  /// açıyordu ama başlık jenerik "Mikser" olarak kalıyordu; hangi sesin çaldığını
  /// söyleyen tek işaret yoktu. null → jenerik başlık (doğrudan `/mixer`, yani
  /// gerçekten bir ses seçilmemiş).
  final String? title;

  /// Test sahte controller enjekte edebilsin diye (cihazsız widget testi).
  final MixerController? controller;

  /// Çalınacak tarif — kütüphaneden gelen soundscape'in tarifi.
  ///
  /// `initState`'te BİR KEZ okunur ([controller] verilmişse hiç okunmaz): sonradan
  /// değişen bir spec, çalan sesi kesip yeniden render etmek anlamına gelirdi.
  /// null → [defaultMixSpec].
  final MixSpec? spec;

  /// Sesin kendi tarifi çözülemedi, varsayılanla açıldı — kullanıcıya söylenir.
  /// Ses YİNE DE çalar; bu bir hata ekranı değil, bir dipnottur.
  final bool recipeUnavailable;

  final Sharer? sharer;

  /// Video export'u bu platformda mümkün mü.
  ///
  /// **Varsayılan `Platform.isAndroid` DEĞİL, `defaultTargetPlatform`:** ilki testte
  /// host'u (Windows) görür ve butonu her zaman gizlerdi. Null → gerçek platform.
  final bool? canExportVideo;

  @override
  ConsumerState<MixerScreen> createState() => _MixerScreenState();
}

class _MixerScreenState extends ConsumerState<MixerScreen> {
  late final MixerController _c;
  late final Sharer _sharer = widget.sharer ?? PlatformSharer();

  /// iOS'ta native kodlayıcı YOK (D-13/D-14: `AVAssetWriter` Mac olmadan yazılamadı).
  /// Butonu göstermek, basınca `MissingPluginException` atan bir buton olurdu.
  bool get _canExportVideo =>
      widget.canExportVideo ?? defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    _c = widget.controller ?? MixerController(spec: widget.spec);
    _c.onChanged = () {
      if (mounted) setState(() {});
    };
  }

  @override
  void dispose() {
    _c.onChanged = null;
    _c.dispose();
    super.dispose();
  }

  String _layerLabel(AppL10n l10n, LayerSource type) {
    switch (type) {
      case LayerSource.white:
        return l10n.mixerLayerWhite;
      case LayerSource.pink:
        return l10n.mixerLayerPink;
      case LayerSource.brown:
        return l10n.mixerLayerBrown;
      case LayerSource.waves:
        return l10n.mixerLayerWaves;
      case LayerSource.fire:
        return l10n.mixerLayerFire;
      case LayerSource.rain:
        return l10n.mixerLayerRain;
      case LayerSource.pad:
        return l10n.mixerLayerPad;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final s = _c.state;

    // Arka plan kullanıcının KENDİ kimliğiyle renklenir (#178 ile aynı tek kaynak).
    // Sonuç yoksa/hata varsa null → `archetypeGradientForSlug` nötr varsayılana düşer;
    // ekran arketip servisine BAĞIMLI değil (mikser çevrimdışı tam çalışır, §3.1).
    final slug = ref
        .watch(latestArchetypeResultProvider)
        .maybeWhen(data: (r) => r?.archetypeSlug, orElse: () => null);

    return Scaffold(
      backgroundColor: NoctaColors.bgBase,
      // Arka plan AppBar'ın da ARDINDA: player tam ekran olmalı, üstte koyu bir
      // şerit kalırsa "arka plan" değil "başlık altındaki resim" gibi görünür.
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: NoctaColors.inkPrimary,
      ),
      body: TickerMode(
        enabled: s.isPlaying,
        child: AmbientBackdrop(
          gradient: archetypeGradientForSlug(slug),
          gains: s.gains,
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final height = constraints.maxHeight;
                // Yumuşama bandı küçük ekranda oransal olarak kısalır — ama bir
                // tabanın altına inmez: çok kısa bir rampa yeniden görünür bir
                // kenar demektir (dikişi geri getirirdi).
                //
                // AppBar'ın altına inme derdi YOK: `extendBodyBehindAppBar`
                // gövdeyi y=0'dan başlatır ama Scaffold, `MediaQuery.padding.top`
                // değerine AppBar yüksekliğini ekler; buradaki `SafeArea` onu
                // tüketir. Yani bant zaten geri butonunun ALTINDA başlar ve
                // AppBar'ın arkası tamamen scrim'siz kalır (ambiyans en net orada).
                final fade = math.min(
                  kPlayerScrimFadeHeight,
                  math.max(48.0, height * 0.12),
                );
                return Column(
                  // ŞART: bu olmadan `SizedBox`/`ConstrainedBox` çocukları gevşek
                  // genişlik alır ve içeriklerinin genişliğine büzülür — ÖLÇÜLDÜ:
                  // yumuşama bandı 0 px genişliğe düşüp hiç boyanmıyordu, hero
                  // scrim'i ise metin kutusu kadar kalıp ORTALANIYORDU (tam olarak
                  // sınıf yorumundaki "yüzen dikdörtgen" hatasının kendisi).
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    SizedBox(
                      key: const Key('mixer-scrim-fade'),
                      height: fade,
                      child: DecoratedBox(
                        decoration: BoxDecoration(gradient: playerScrimFade()),
                      ),
                    ),
                    // Hero esnek DEĞİL: içeriği kadar yer kaplar, artan her
                    // piksel aşağıdaki `Expanded`'a gider. İki tavanı var:
                    // (a) ekranın %34'ü — uzun bir soundscape adı ekranın
                    //     yarısını yutmasın;
                    // (b) kontrollere [kPlayerControlsMinHeight] kaldıktan sonra
                    //     ARTAN — yer bittiğinde geri adım atan taraf hero olsun.
                    // İkisini de aşarsa hero KENDİ İÇİNDE kaydırılır, taşmaz.
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: math.max(
                          0.0,
                          math.min(
                            height * 0.34,
                            height - fade - kPlayerControlsMinHeight,
                          ),
                        ),
                      ),
                      child: _hero(l10n, s),
                    ),
                    Expanded(child: _controlSheet(l10n, s)),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Üst bölge: ÇALAN ŞEYİN ADI + durumu.
  ///
  /// Kutu içeriği kadar yüksektir; scrim'in "sönmesi" burada DEĞİL, üstteki
  /// yumuşama bandında olur (bkz. [playerScrimFade]). Bu yüzden metnin altındaki
  /// zemin sabit [kPlayerScrimAlpha]'dır: kontrast ekranın neresinde olursa olsun
  /// aynı ve ölçülmüş değerdedir.
  ///
  /// `SingleChildScrollView` (artık `reverse: false`): içerik tavanı aşarsa —
  /// iki satırlık uzun bir soundscape adı, TR'nin uzun metinleri, büyük yazı
  /// ölçeği — taşma hatası yerine kaydırılır.
  Widget _hero(AppL10n l10n, MixerState s) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: NoctaColors.bgBase.withValues(alpha: kPlayerScrimAlpha),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            NoctaSpace.s6,
            NoctaSpace.s2,
            NoctaSpace.s6,
            NoctaSpace.s5,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                l10n.mixerSoundLabel,
                style: TextStyle(
                  fontSize: NoctaFontSize.micro,
                  letterSpacing: 1.2,
                  color: NoctaColors.inkSecondary,
                ),
              ),
              const SizedBox(height: NoctaSpace.s2),
              Text(
                widget.title?.isNotEmpty == true
                    ? widget.title!
                    : l10n.mixerTitle,
                key: const Key('mixer-title'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: NoctaFontSize.display,
                  color: NoctaColors.inkPrimary,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: NoctaSpace.s3),
              _statusLine(l10n, s),
            ],
          ),
        ),
      ),
    );
  }

  /// Durum satırı: nokta + metin. Nokta ANİMASYONSUZ — nabız atan bir gösterge
  /// gece boyu açık duran bir ekranda her karede ticker uyandırırdı (şeritteki
  /// kararın aynısı).
  Widget _statusLine(AppL10n l10n, MixerState s) {
    final String text;
    final Color dot;
    if (s.isPreparing) {
      text = l10n.mixerPreparing;
      dot = NoctaColors.accentDawn;
    } else if (s.isPlaying) {
      text = l10n.mixerStatusPlaying;
      dot = NoctaColors.accentAurora;
    } else {
      text = l10n.mixerStatusPaused;
      dot = NoctaColors.inkFaint;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        ),
        const SizedBox(width: NoctaSpace.s2),
        Text(
          text,
          key: const Key('mixer-status'),
          style: TextStyle(
            fontSize: NoctaFontSize.caption,
            color: NoctaColors.inkSecondary,
          ),
        ),
      ],
    );
  }

  /// Alt bölge: KONTRAST ZEMİNİ + katmanlar + taşıma.
  ///
  /// **Scrim, hero ile AYNI [kPlayerScrimAlpha]** — burada 11–13 punto etiketler,
  /// yüzdeler ve sürgü rayları var; ince öğeler hareketli bir gradyanın üstünde
  /// okunmaz. Değer artık ölçülmüş (bkz. [kPlayerScrimAlpha] tablosu); eski 0.72
  /// AA eşiğinin altındaydı.
  ///
  /// **Yuvarlatılmış köşe ve tutamaç KALDIRILDI.** İkisi de "burası ayrı bir
  /// panel" demek içindi; ama panelin kenarı, hero'nun sönen scrim'iyle
  /// buluştuğunda ekrandaki o keskin yatay çizgiyi üretiyordu. Tutamaç ayrıca
  /// sürüklenebilirlik VAAT EDİYORDU — sürüklenmiyordu. Bölgeyi ayıran işaret
  /// artık `mixerLayersLabel` başlığı; kazanılan ~28 px katman listesine gitti.
  Widget _controlSheet(AppL10n l10n, MixerState s) {
    return Container(
      key: const Key('mixer-sheet'),
      decoration: BoxDecoration(
        color: NoctaColors.bgBase.withValues(alpha: kPlayerScrimAlpha),
      ),
      child: Column(
        children: <Widget>[
          // ── Dipnotlar: SABİT, kaydırma alanının DIŞINDA ──
          // Kaydırılan listenin içinde olsalardı 7 katmanlı bir mikste kullanıcı
          // hata mesajını görmek için kaydırmak zorunda kalırdı.
          if (widget.recipeUnavailable)
            _notice(
              // Dürüstlük: kullanıcı istediği sesi seçti ama başka bir mix duyuyor.
              // Ses çalmaya devam eder (offline-first); bu bir dipnottur.
              text: l10n.mixerRecipeUnavailable,
              color: NoctaColors.inkSecondary,
              noticeKey: const Key('mixer-recipe-fallback'),
            ),
          if (s.error != null)
            _notice(
              // Ses hatası mı export hatası mı — kullanıcıya doğru olanı söyle.
              text: s.errorKind == MixerErrorKind.export
                  ? l10n.mixerExportFailed
                  : l10n.mixerFailed,
              color: NoctaColors.danger,
              noticeKey: const Key('mixer-error'),
            ),

          Padding(
            padding: const EdgeInsets.fromLTRB(
              NoctaSpace.s6,
              NoctaSpace.s3,
              NoctaSpace.s6,
              NoctaSpace.s2,
            ),
            child: Row(
              children: <Widget>[
                Text(
                  l10n.mixerLayersLabel,
                  key: const Key('mixer-layers-label'),
                  style: TextStyle(
                    fontSize: NoctaFontSize.micro,
                    letterSpacing: 1.2,
                    color: NoctaColors.inkFaint,
                  ),
                ),
              ],
            ),
          ),

          // ── KAYDIRILAN bölge: yalnızca katmanlar ──
          // `SingleChildScrollView + Column` (ListView DEĞİL): sürgüler ekran dışına
          // taşsa bile hepsi ağaçta kurulur. Tembel bir liste, görünmeyen katmanın
          // durumunu ağaçtan düşürürdü.
          Expanded(
            child: SingleChildScrollView(
              key: const Key('mixer-layers-scroll'),
              padding: const EdgeInsets.fromLTRB(
                NoctaSpace.s6,
                0,
                NoctaSpace.s6,
                NoctaSpace.s4,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (final layer in s.layers) _layerRow(l10n, s, layer),
                ],
              ),
            ),
          ),

          // ── SABİT taşıma çubuğu: katman sayısından bağımsız erişilebilir ──
          _transport(l10n, s),
        ],
      ),
    );
  }

  Widget _notice({
    required String text,
    required Color color,
    required Key noticeKey,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        NoctaSpace.s6,
        NoctaSpace.s3,
        NoctaSpace.s6,
        0,
      ),
      child: Text(
        text,
        key: noticeKey,
        style: TextStyle(fontSize: NoctaFontSize.caption, color: color),
      ),
    );
  }

  Widget _layerRow(AppL10n l10n, MixerState s, MixLayer layer) {
    final gain = s.gains[layer.id] ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: NoctaSpace.s2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  _layerLabel(l10n, layer.type),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: NoctaFontSize.caption,
                    color: NoctaColors.inkPrimary,
                  ),
                ),
              ),
              Text(
                l10n.mixerGainPercent((gain * 100).round()),
                style: TextStyle(
                  fontSize: NoctaFontSize.micro,
                  color: NoctaColors.inkSecondary,
                  // Sürgü oynarken yüzde her adımda sağa-sola zıplamasın.
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
            ],
          ),
          Slider(
            key: Key('gain-${layer.id}'),
            value: gain,
            onChanged: (v) => _c.setGain(layer.id, v),
            // Erişilebilirlik: ekran okuyucu "pembe gürültü, %30" desin.
            // Yüzde biçimi yerele bağlı (EN "30%", TR "%30") → i18n'den.
            label: l10n.mixerGainPercent((gain * 100).round()),
            divisions: 20,
            activeColor: NoctaColors.accentAurora,
            inactiveColor: NoctaColors.inkFaint.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }

  Widget _transport(AppL10n l10n, MixerState s) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        NoctaSpace.s6,
        NoctaSpace.s2,
        NoctaSpace.s6,
        NoctaSpace.s5,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('mixer-toggle'),
              // Hazırlanırken buton KİLİTLİ: render sırasında ikinci kez
              // basmak ikinci bir render tetiklerdi.
              onPressed: s.isPreparing ? null : () => _c.toggle(),
              // Dokunma hedefi ≥44px (CLAUDE.md §7) — ekranın birincil eylemi.
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              icon: Icon(s.isPlaying ? Icons.pause : Icons.play_arrow),
              label: Text(
                s.isPreparing
                    ? l10n.mixerPreparing
                    : (s.isPlaying ? l10n.mixerPause : l10n.mixerPlay),
              ),
            ),
          ),

          // Viral kanca #3 (docs/04 §131). iOS'ta gizli: native kodlayıcı yok.
          if (_canExportVideo) ...<Widget>[
            const SizedBox(height: NoctaSpace.s3),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const Key('mixer-export-video'),
                onPressed: s.isExporting ? null : _exportVideo,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  foregroundColor: NoctaColors.inkPrimary,
                  side: BorderSide(
                    color: NoctaColors.inkFaint.withValues(alpha: 0.5),
                  ),
                ),
                icon: const Icon(Icons.movie_creation_outlined),
                label: Text(
                  s.isExporting
                      ? l10n.mixerExporting((s.exportProgress! * 100).round())
                      : l10n.mixerExportVideo,
                ),
              ),
            ),
            if (s.isExporting)
              Padding(
                padding: const EdgeInsets.only(top: NoctaSpace.s3),
                child: LinearProgressIndicator(
                  key: const Key('mixer-export-progress'),
                  value: s.exportProgress,
                ),
              ),
          ],

          const SizedBox(height: NoctaSpace.s3),
          // Dürüstlük: kullanıcı duyduğu şeyin nihai kalite olmadığını BİLMELİ.
          // Bunu saklamak, erken sürümde "ses kötü" izlenimini kalıcılaştırırdı.
          Text(
            l10n.mixerStopgapNotice,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: NoctaFontSize.micro,
              color: NoctaColors.inkFaint,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportVideo() async {
    final l10n = AppL10n.of(context);
    // Viral kanca #3: export edilen video kullanıcının KENDİ arketip gradyanını
    // taşır (#178). Sonuç henüz yüklenmemişse/test yapılmamışsa slug null → nötr
    // varsayılan. `read` (watch değil): export tek seferlik bir eylem, o anki değer yeter.
    final slug = ref
        .read(latestArchetypeResultProvider)
        .maybeWhen(data: (r) => r?.archetypeSlug, orElse: () => null);
    final path = await _c.exportVideo(
      title: l10n.mixerVideoTitle,
      gradient: archetypeGradientForSlug(slug),
    );
    // Hata state'e yazıldı ve ekranda gösteriliyor; burada paylaşacak bir şey yok.
    if (path == null || !mounted) return;

    await _sharer.share(
      ShareContent(
        text: l10n.mixerExportShareText,
        url: 'https://nocta.app',
        file: ShareFile.mp4(path: path, filename: 'nocta-mix.mp4'),
      ),
    );
  }
}
