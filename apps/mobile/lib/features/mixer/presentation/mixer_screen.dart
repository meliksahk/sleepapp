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
import 'asset_catalog_sheet.dart';

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
///    dibe sabitlenir. Katman sayısı 3→7 olduğunda çal butonu ekranın altına
///    düşmüştü (#213); burada butonların erişilebilirliği katman sayısından
///    yapısal olarak bağımsız.
///
///    ⚠️ "Sabit" mutlak DEĞİL: taşıma çubuğunun tavanı kontrol bölgesinin
///    tamamı ve sığmadığında kendi içinde kaydırılır (büyük yazı ölçeği).
///    Çal butonu o listenin ilk çocuğu olduğu için her koşulda görünür kalır;
///    teslim eden taraf video butonu ve erken-sürüm notudur. Gerekçe ve ölçüm:
///    [playerControlsReserve].
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

/// Çal butonunun asgari yüksekliği — §7 dokunma hedefi (≥44) değil, ondan
/// BÜYÜK bir değer: ekranın birincil eylemi parmakla aranmamalı.
///
/// Tek kaynak: hem butonun kendi `minimumSize`'ı hem de
/// [playerControlsReserve] bunu kullanır. İkisi ayrışırsa rezervasyon yalan
/// söyler ve buton ekrandan taşar.
const double kPlayerPlayButtonMinHeight = 52;

/// Material 3 `labelLarge` punto — buton etiketlerinin varsayılanı.
///
/// Tema (`buildNoctaDarkTheme`) buton tipografisini EZMİYOR, yalnızca renk ve
/// font ailesi veriyor; dolayısıyla etiket punto kaynağı Material'ın kendisi.
/// Tema bir gün buton textStyle'ı ezerse bu değer de güncellenmeli.
const double _kButtonLabelFontSize = 14;

/// Kontrol bölgesine **her koşulda** ayrılan yükseklik: taşıma çubuğunun
/// teslim EDEMEYECEĞİ tek parçası — çal butonu + kendi dikey boşluğu.
///
/// ## Neden sabit bir sayı DEĞİL (bu bir gerileme düzeltmesi)
///
/// Buradaki değer eskiden `kPlayerControlsMinHeight = 280` idi: varsayılan yazı
/// ölçeğinde, İngilizce ve Türkçe metinlerle **ölçülmüş** bir sayı. Ölçüm
/// doğruydu ama sayı, ölçüldüğü koşulun dışında geçersizdi — kodun kendi uyarısı
/// da bunu söylüyordu. Yazı ölçeği büyüyünce başlık satırı, dipnotlar ve taşıma
/// çubuğunun sarmalı metinleri hep birlikte büyüyor; 280 px'lik pay onları
/// tutmuyor ve düzen taşıyordu. Ölçülen taşma (320×568, iki kabuk bandı, EN):
///
/// | yazı ölçeği | taşma |
/// |-------------|-------|
/// | 1.0 | yok |
/// | 1.3 | 9 px |
/// | 1.6 | 148 px |
/// | 2.0 | çal butonu ekranın 33 px ALTINDA (hiç dokunulamıyor) |
///
/// Sayıyı ölçekle çarpmak aynı hatanın katsayılı hâli olurdu: bir metnin kaç
/// satıra saracağı dile, ekran genişliğine ve punto yuvarlamasına bağlı —
/// çarpanla kestirilemez. Bu yüzden **düzen artık bir tahmine dayanmıyor**:
///
/// 1. Kontrol bölgesinin içindeki HER ŞEY (dipnotlar, katman başlığı, sürgüler,
///    video butonu, erken-sürüm notu) yer daralınca kaydırılabilir hâle gelir —
///    yani hiçbiri sabit bir maliyet değildir. Bkz. `_controlSheet`.
/// 2. Geriye teslim edilemeyen tek parça kalır: çal butonu. Yüksekliği tahmin
///    değil hesap — [kPlayerPlayButtonMinHeight] ile etiketin o ölçekteki
///    yüksekliğinin büyüğü.
///
/// Böylece rezervasyon O(bir buton) olur; dil, çeviri uzunluğu veya yeni bir
/// dipnot onu GEÇERSİZ KILAMAZ, çünkü hiçbiri bu paya girmiyor.
///
/// Metni kırpmak veya dokunma hedefini küçültmek alternatifleri reddedildi:
/// ilki dürüstlük dipnotlarını, ikincisi §7'yi başka yerden çiğnerdi.
///
/// Bekçisi: `mixer_small_screen_test.dart` — 320×568 × 4 yazı ölçeği ×
/// 4 kabuk kombinasyonu × 2 dil.
double playerControlsReserve(BuildContext context) {
  // Etiketin satır yüksekliği: punto × tipik satır aralığı. Buton etiketi TEK
  // satırdır (sarmaz), o yüzden burada satır sayısı tahmini YOK.
  final labelHeight =
      MediaQuery.textScalerOf(context).scale(_kButtonLabelFontSize) * 1.45;
  final buttonHeight = math.max(
    kPlayerPlayButtonMinHeight,
    labelHeight + NoctaSpace.s2,
  );
  // `_transport`'un kendi dikey padding'i — buton o kutunun içinde yaşıyor.
  return NoctaSpace.s2 + buttonHeight + NoctaSpace.s4;
}

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
                // Kontrol bölgesine AYRILAN pay — düzenin tek dokunulmaz
                // parçası. Aşağıdaki iki tavan da bunu çıkararak hesaplanır,
                // yani `fade + hero ≤ height - reserve`: `Expanded` her zaman
                // en az `reserve` kadar alır ve çal butonu ekranda kalır.
                final reserve = playerControlsReserve(context);

                // Yumuşama bandı küçük ekranda oransal olarak kısalır — ama bir
                // tabanın altına inmez: çok kısa bir rampa yeniden görünür bir
                // kenar demektir (dikişi geri getirirdi).
                //
                // AppBar'ın altına inme derdi YOK: `extendBodyBehindAppBar`
                // gövdeyi y=0'dan başlatır ama Scaffold, `MediaQuery.padding.top`
                // değerine AppBar yüksekliğini ekler; buradaki `SafeArea` onu
                // tüketir. Yani bant zaten geri butonunun ALTINDA başlar ve
                // AppBar'ın arkası tamamen scrim'siz kalır (ambiyans en net orada).
                final rawFade = math.min(
                  kPlayerScrimFadeHeight,
                  math.max(48.0, height * 0.12),
                );
                // 48 px'lik TABAN da teslim olur — ama en son. Gövde 2.0 yazı
                // ölçeğinde (kabuk bantları büyüyünce) 123 px'e kadar iniyor;
                // orada 48 px'i bir gradyana harcamak, ekranın %39'unu süse
                // verip birincil eylemi ekran dışına itmek demekti. Dikişin
                // görünürlüğü bir cila sorunu, çal butonuna ulaşamamak §7 ihlali:
                // çakıştıklarında §7 kazanır.
                final fade = math.max(0.0, math.min(rawFade, height - reserve));
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
                    // (b) kontrollere [playerControlsReserve] kaldıktan sonra
                    //     ARTAN — yer bittiğinde geri adım atan taraf hero olsun.
                    // İkisini de aşarsa hero KENDİ İÇİNDE kaydırılır, taşmaz.
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: math.max(
                          0.0,
                          math.min(height * 0.34, height - fade - reserve),
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
        // `Flexible` — metin SARAR, kırpılmaz.
        //
        // Esnek DEĞİLDİ ve 2.0 yazı ölçeğinde 320 px'te yatayda 59 px taşıyordu
        // (TR "Duraklatıldı" 26 punto → 315 px, kullanılabilir genişlik 272).
        // `ellipsis` alternatifi reddedildi: durum metni ekranın "ne oluyor"
        // cevabı; "Duraklat…" diye kesilmesi bilgiyi yok eder. Sarmak hero'yu
        // uzatır, hero da zaten kendi içinde kaydırılabilir.
        Flexible(
          child: Text(
            text,
            key: const Key('mixer-status'),
            style: TextStyle(
              fontSize: NoctaFontSize.caption,
              color: NoctaColors.inkSecondary,
            ),
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
      // Kendi yüksekliğini ÖLÇER: aşağıdaki taşıma çubuğunun tavanı bu.
      // Sabit bir sayı olamaz — bkz. [playerControlsReserve].
      child: LayoutBuilder(
        builder: (context, sheet) {
          final budget = sheet.maxHeight;
          return Column(
            children: <Widget>[
              // ── KAYDIRILAN bölge ──
              //
              // Dipnotlar ve katman başlığı artık kaydırma alanının İÇİNDE.
              // Önceden dışındaydılar ("kullanıcı hatayı görmek için
              // kaydırmasın" diye) ama bu onları SABİT maliyet yapıyordu:
              // yazı ölçeği 1.3'ten sonra üç dipnot + başlık satırı tek
              // başına bütçeyi yiyip düzeni taşırıyordu.
              //
              // Amaç kaybolmuyor: liste dinlenme konumunda offset 0'dadır,
              // yani dipnotlar hâlâ İLK görünen şeydir. Yalnızca "her zaman
              // ekranda" garantisi "açılışta ekranda"ya iniyor — ve karşılığı,
              // aynı garantiyi ekranın birincil eylemine verebilmek.
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
                      if (widget.recipeUnavailable)
                        _notice(
                          // Dürüstlük: kullanıcı istediği sesi seçti ama başka
                          // bir mix duyuyor. Ses çalmaya devam eder
                          // (offline-first); bu bir dipnottur.
                          text: l10n.mixerRecipeUnavailable,
                          color: NoctaColors.inkSecondary,
                          noticeKey: const Key('mixer-recipe-fallback'),
                        ),
                      if (s.assetsUnavailable)
                        _notice(
                          // Dosya katmanı yüklenemedi ama mix ÇALIYOR. `danger`
                          // değil `inkSecondary`: bu bir arıza değil, eksik bir
                          // katman.
                          text: l10n.mixerAssetUnavailable,
                          color: NoctaColors.inkSecondary,
                          noticeKey: const Key('mixer-asset-unavailable'),
                        ),
                      if (s.error != null)
                        _notice(
                          // Hangi iş patladı — kullanıcıya doğru olanı söyle.
                          // Üç ayrı hâl var ve üçü de farklı şey demek: ses hiç
                          // başlamadı / video üretilemedi / eklenmek istenen
                          // dosya gelmedi (mix çalıyor).
                          text: switch (s.errorKind) {
                            MixerErrorKind.export => l10n.mixerExportFailed,
                            MixerErrorKind.assetAdd => l10n.mixerAssetAddFailed,
                            MixerErrorKind.assetDuplicate =>
                              l10n.mixerAssetAlreadyInMix,
                            _ => l10n.mixerFailed,
                          },
                          // Çift ekleme bir ARIZA değil: kırmızı yerine ikincil
                          // renk. Kullanıcıyı bir şeyin bozulduğuna inandırmak
                          // istemiyoruz, yalnızca ne olduğunu söylüyoruz.
                          color: s.errorKind == MixerErrorKind.assetDuplicate
                              ? NoctaColors.inkSecondary
                              : NoctaColors.danger,
                          noticeKey: const Key('mixer-error'),
                        ),

                      // Katman listesinin başlığı. Yatay padding YOK: artık
                      // kaydırma alanının kendi padding'inin içinde yaşıyor.
                      //
                      // **`Row` DEĞİL `Wrap`** — ölçülmüş bir taşma düzeltmesi.
                      // `Row`'da esnek olmayan çocuk SINIRSIZ genişlik alır:
                      // "Ses ekle" düğmesi 2.0 yazı ölçeğinde 299 px'e çıkıyor,
                      // kullanılabilir genişlik ise 272 — yatayda 27 px taşma
                      // (etiket `Expanded` olduğu için 0 px'e ezilmişti bile).
                      //
                      // `Wrap` sığmadığında düğmeyi ALT SATIRA alır ve orada
                      // tam genişliği verir; düğmenin kendi etiketi de o sınır
                      // içinde sarar. Yani ne metin kırpılıyor ne dokunma
                      // hedefi küçülüyor — ikisi de §7'yi çiğnerdi.
                      // Sığdığı sürece (varsayılan ölçek, iki dil) davranış
                      // eskisiyle aynı: etiket solda, düğme sağda.
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        // Tek satıra sığdığında aradaki boşluk; alt satıra
                        // düştüğünde satır arası.
                        spacing: NoctaSpace.s2,
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
                          // "Ses ekle" — katman listesinin BAŞLIĞINDA, çünkü
                          // yaptığı şey tam olarak bu listeye bir satır
                          // eklemek. Taşıma çubuğuna koymak onu çal/paylaş ile
                          // aynı ağırlıkta gösterirdi.
                          TextButton.icon(
                            key: const Key('mixer-add-sound'),
                            onPressed: _addSound,
                            style: TextButton.styleFrom(
                              // Dokunma hedefi ≥44px (CLAUDE.md §7).
                              minimumSize: const Size(44, 44),
                              foregroundColor: NoctaColors.accentAurora,
                              padding: const EdgeInsets.symmetric(
                                horizontal: NoctaSpace.s3,
                              ),
                            ),
                            icon: const Icon(Icons.add, size: 18),
                            label: Text(l10n.mixerAddSound),
                          ),
                        ],
                      ),

                      for (final layer in s.layers)
                        _gainRow(
                          label: _layerLabel(l10n, layer.type),
                          id: layer.id,
                          l10n: l10n,
                          s: s,
                        ),
                      // DOSYA katmanları sentezin ALTINDA, aynı sürgü bileşeniyle:
                      // kullanıcı için ikisi de "bir katman"dır. Etiket i18n'den
                      // GELMEZ — içerik adıdır (sunucudaki başlık).
                      for (final asset in s.assets)
                        _gainRow(
                          label: asset.title,
                          id: asset.id,
                          l10n: l10n,
                          s: s,
                          // YALNIZCA dosya katmanları kaldırılabilir: sentez
                          // katmanları tarifin kendisi (sürgüsü 0'a çekilebilir).
                          // Ekleyip vazgeçememek kabul edilemezdi.
                          onRemove: () => _c.removeAsset(asset.id),
                        ),
                      // ── Master limitleyici göstergesi ──
                      //
                      // **Neden sessiz olamaz:** limitleyici devreye girdiğinde
                      // kullanıcı sürgüyü yukarı iter ve ses YÜKSELMEZ (hatta
                      // diğer katmanlar kısılır). Açıklamasız bu, "uygulama
                      // sürgümü dinlemiyor" demektir. Söylenen üç şey: limit
                      // devrede / ne kadar kısıldı / SÜRGÜLERİN DEĞİŞMEDİ.
                      //
                      // **Neden burada, dipnot bloğunun içinde değil:** uyarı hemen
                      // üstündeki sürgülerle ilgili — kullanıcı sebebe bakarken
                      // sonucu da görüyor. (Dipnotlar da artık bu kaydırma alanının
                      // içinde; ikisi de sabit maliyet değil.)
                      //
                      // Renk `accentDawn` (danger DEĞİL): bu bir arıza değil,
                      // motorun doğru çalıştığının işareti.
                      if (s.isLimiting)
                        Padding(
                          padding: const EdgeInsets.only(top: NoctaSpace.s2),
                          child: Text(
                            l10n.mixerLimiterNotice(s.limiterReductionPercent),
                            key: const Key('mixer-limiter-notice'),
                            style: TextStyle(
                              fontSize: NoctaFontSize.micro,
                              color: NoctaColors.accentDawn,
                              height: 1.3,
                            ),
                          ),
                        ),
                      // Dürüstlük dipnotu: dosya döngüsünde tık DUYULABİLİR ve bunu
                      // düzeltemiyoruz (PCM'e erişimimiz yok — asset_layer.dart).
                      // Kullanıcı "uygulama bozuk" demeden önce nedenini bilsin.
                      if (s.assets.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: NoctaSpace.s2),
                          child: Text(
                            l10n.mixerAssetLoopNotice,
                            key: const Key('mixer-asset-loop-notice'),
                            style: TextStyle(
                              fontSize: NoctaFontSize.micro,
                              color: NoctaColors.inkFaint,
                              height: 1.3,
                            ),
                          ),
                        ),
                      // ⚠️ DÜRÜSTLÜK — viral kanca #3'ün bilinen deliği.
                      //
                      // `renderMix` yalnızca SENTEZ katmanlarını görür (yapısal,
                      // bkz. asset_layer.dart): eklenen dosya katmanları videoya
                      // GİRMEZ. Kullanıcı duyduğu mix'i paylaştığını sanır, karşı
                      // taraf eksik bir mix duyar. Bunu paylaşımdan SONRA fark
                      // etmek en kötü sonuç.
                      //
                      // İki kademe: burada kalıcı dipnot + export'a basınca onay
                      // ([_confirmExportWithAssets]). Diyalog tek başına butona
                      // basmadan önce bilgilendirmez; dipnot tek başına gözden
                      // kaçabilir.
                      //
                      // **Neden taşıma çubuğunda DEĞİL de burada:** çubuk dar
                      // ekranda kendi içinde kaydırılıyor; oraya konan sarmalı bir
                      // metin, büyük yazı ölçeğinde kaydırma gerektirmeden
                      // görünmezdi. Burası doğru yer aynı zamanda: uyarı, hemen
                      // üstündeki dosya katmanlarıyla ilgili.
                      // Onay diyaloğu zaten export anında ikinci kez söylüyor.
                      if (s.assets.isNotEmpty && _canExportVideo)
                        Padding(
                          padding: const EdgeInsets.only(top: NoctaSpace.s2),
                          child: Text(
                            l10n.mixerExportAssetWarning,
                            key: const Key('mixer-export-asset-warning'),
                            style: TextStyle(
                              fontSize: NoctaFontSize.micro,
                              color: NoctaColors.accentDawn,
                              height: 1.3,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // ── Taşıma çubuğu: katman sayısından bağımsız erişilebilir ──
              //
              // Tavanı `budget` (kontrol bölgesinin TAMAMI). `SingleChildScroll
              // View` sınırlı bir tavan altında içeriğine büzülür — yani:
              //
              // - **sığdığı sürece** (varsayılan ölçek, her iki dil) davranış
              //   eskisiyle birebir aynı: tam boy, dibe yapışık, video butonu
              //   ve erken-sürüm notu görünür. Kaydırma YOK.
              // - **sığmadığında** (büyük yazı ölçeği) çubuk kendi içinde
              //   kaydırılır. Çal butonu çubuğun İLK çocuğu ve liste offset
              //   0'da açılır: kırpılan taraf her zaman video butonu ve not
              //   olur, birincil eylem asla.
              //
              // `Expanded` yukarıda kalanı alır: `budget - taşıma` her zaman
              // ≥ 0, yani bu Column YAPISAL OLARAK taşamaz — hangi dil, hangi
              // yazı ölçeği, kaç dipnot olursa olsun.
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: budget),
                child: SingleChildScrollView(
                  key: const Key('mixer-transport-scroll'),
                  child: _transport(l10n, s),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _notice({
    required String text,
    required Color color,
    required Key noticeKey,
  }) {
    return Padding(
      // Yatay padding YOK: dipnotlar artık kaydırma alanının kendi
      // padding'inin içinde yaşıyor, ikinci kez uygulamak onları içeri kaydırırdı.
      padding: const EdgeInsets.only(top: NoctaSpace.s3),
      child: Text(
        text,
        key: noticeKey,
        style: TextStyle(fontSize: NoctaFontSize.caption, color: color),
      ),
    );
  }

  /// Tek bir kazanç sürgüsü — sentez ve dosya katmanları AYNI bileşeni kullanır.
  ///
  /// Eskiden `MixLayer` alıyordu; dosya katmanı eklenince ikinci bir kopya yazmak
  /// yerine imza "etiket + id"ye indirildi. Sürgünün katmanın türünü bilmesine
  /// gerek yok — zaten `setGain(id, ...)` çağırıyor.
  Widget _gainRow({
    required String label,
    required String id,
    required AppL10n l10n,
    required MixerState s,
    VoidCallback? onRemove,
  }) {
    final layerId = id;
    final gain = s.gains[layerId] ?? 0;
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
                  label,
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
              if (onRemove != null)
                IconButton(
                  key: Key('remove-$layerId'),
                  onPressed: onRemove,
                  // Ekran okuyucu "Kaldır: <ses adı>" desin — ekranda yedi
                  // sürgü varken çıplak bir çöp kutusu hangisini kaldıracağını
                  // söylemez.
                  tooltip: l10n.mixerRemoveLayer(label),
                  visualDensity: VisualDensity.compact,
                  // ≥44px dokunma hedefi (CLAUDE.md §7); ikon küçük ama hedef değil.
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  iconSize: 18,
                  color: NoctaColors.inkFaint,
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
          Slider(
            key: Key('gain-$layerId'),
            value: gain,
            onChanged: (v) => _c.setGain(layerId, v),
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

  /// Taşıma çubuğu — çal / video / erken-sürüm notu, bu SIRAYLA.
  ///
  /// **Sıra bir tasarım tercihi değil, bir garanti:** çubuk dar alanda kendi
  /// içinde kaydırılıyor (bkz. `_controlSheet`) ve kaydırma offset 0'da açılıyor.
  /// Yani ilk çocuk her koşulda görünür kalır. Çal butonunun burada BİRİNCİ
  /// olması, ekranın birincil eyleminin hiçbir yazı ölçeğinde ekran dışına
  /// düşmemesinin sebebidir. Sırayı değiştirmek bu garantiyi bozar.
  ///
  /// Dikey boşluklar (s2/s4) da bu bütçenin parçası; genişletmek küçük ekranda
  /// doğrudan katman listesinden çalar.
  Widget _transport(AppL10n l10n, MixerState s) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        NoctaSpace.s6,
        NoctaSpace.s2,
        NoctaSpace.s6,
        NoctaSpace.s4,
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
              // Sabit [playerControlsReserve] ile ORTAK: rezervasyon bu butonun
              // yüksekliğini hesaplıyor, ikisi ayrışırsa buton ekrandan taşar.
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(kPlayerPlayButtonMinHeight),
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
            const SizedBox(height: NoctaSpace.s2),
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

          const SizedBox(height: NoctaSpace.s2),
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

  /// Katalogdan ses seçip mikse katman olarak ekler.
  ///
  /// **İki dal, ikisi de bilinçli olarak farklı:**
  /// - [CatalogPickLocal] — dosya ZATEN cihazda ve adresi belli. **Hiçbir ağ
  ///   çağrısı yapılmaz**; bu, özelliğin prod'da (ağ katmanı kapalı) ve uçak
  ///   modunda çalışmasının tek sebebi.
  /// - [CatalogPickRemote] — kayıt listede URL taşımaz; presigned URL ikinci bir
  ///   çağrıyla alınır. 404/401/ağ yok → katman EKLENMEZ, hata gösterilir.
  ///   Sessizce çalmayan bir sürgü bırakmak en kötü sonuç olurdu.
  Future<void> _addSound() async {
    final selected = await showAssetCatalogSheet(
      context,
      // Tavan kontrolü katalogta yapılır: dolu ise dosya seçici HİÇ açılmaz.
      currentAssetLayerCount: _c.state.assets.length,
    );
    if (selected == null || !mounted) return;

    switch (selected) {
      case CatalogPickLocal(:final layer):
        await _addLayer(layer);
      case CatalogPickRemote(:final id):
        try {
          final layer = await resolveAssetLayer(ref, id);
          if (!mounted) return;
          if (layer == null) {
            // 404: kayıt katalogda göründü ama dosya artık yok.
            _c.reportAssetAddFailed('asset not found: $id');
            return;
          }
          await _addLayer(layer);
        } catch (e) {
          // Hata YUTULMAZ (CLAUDE.md §4): ağ/401/bozuk yanıt — hepsi buraya
          // düşer, kullanıcı sade metin görür, teknik detay state'te kalır.
          if (mounted) _c.reportAssetAddFailed(e);
        }
    }
  }

  /// Katmanı ekler ve **sonucu KONTROL EDER.**
  ///
  /// Eskiden `addAsset`'in dönüşü yok sayılıyordu: aynı ses ikinci kez
  /// seçildiğinde sheet sessizce kapanıyor ve hiçbir şey olmuyordu. Yerel bölüm
  /// listenin üstünde KALICI olduğu için bu artık rutin bir kullanıcı hareketi —
  /// gece 3'te "bastım, bir şey olmadı" kabul edilemez.
  Future<void> _addLayer(AssetLayer layer) async {
    final outcome = await _c.addAsset(layer);
    if (!mounted) return;
    if (outcome == AddAssetOutcome.duplicate) {
      _c.reportDuplicateAsset();
    }
  }

  /// Mikste dosya katmanı varken export onayı. false → export YAPILMAZ.
  ///
  /// Bu bir "emin misin" diyaloğu değil, bir BİLGİLENDİRME: paylaşılacak videonun
  /// duyulan mixten farklı olacağını söylüyor (bkz. dipnot yorumu).
  Future<bool> _confirmExportWithAssets(AppL10n l10n) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: NoctaColors.bgRaised,
        content: Text(
          l10n.mixerExportAssetWarningLong,
          key: const Key('mixer-export-warning-dialog'),
          style: TextStyle(
            fontSize: NoctaFontSize.body,
            color: NoctaColors.inkPrimary,
            height: 1.4,
          ),
        ),
        actions: <Widget>[
          TextButton(
            key: const Key('mixer-export-warning-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            key: const Key('mixer-export-warning-continue'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.mixerExportAnyway),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _exportVideo() async {
    final l10n = AppL10n.of(context);
    // Dosya katmanı varsa ÖNCE söyle: video onlarsız üretilecek.
    if (_c.state.assets.isNotEmpty) {
      final go = await _confirmExportWithAssets(l10n);
      if (!go || !mounted) return;
    }
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
