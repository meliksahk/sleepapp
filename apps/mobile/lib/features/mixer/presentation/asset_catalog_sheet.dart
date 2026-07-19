import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio_engine/dsp/mix_render.dart';
import '../../../core/design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';
import '../../content/content_models.dart';
import '../../content/content_providers.dart';

/// Kullanıcının KENDİ ses dosyalarının kataloğu — mikserdeki "Ses ekle".
///
/// ## Neden BOTTOM SHEET, neden ayrı ekran değil
///
/// Üç gerekçe, hepsi bu ekrana özgü:
///
/// 1. **Mix çalarken seçiliyor.** Katalogdan bir ses eklemek mikserin bir ALT
///    eylemi; kullanıcı ekledikten sonra hemen sürgüsünü arayacak. Sayfa itmek
///    mikseri (ve sürgüleri) ekrandan tamamen kaldırır, dönünce yeniden çizer.
///    Sheet'te mikser arkada durmaya devam eder — eylemin nereye döndüğü belli.
/// 2. **Ambiyans kesilmez.** Player tam ekran bir `AmbientBackdrop` üstünde
///    yaşıyor ve hareketi ses zarfından geliyor. Rota itmek gece karanlığında
///    tam ekran bir geçiş (ve yeni bir Scaffold zemini) demek olurdu.
/// 3. **Çıkış tek jest.** Vazgeçmek için geri butonu aramak yerine aşağı
///    sürükleme yeter; yanlışlıkla açıldığında maliyeti sıfır.
///
/// **Bedeli (gizlenmiyor):** sheet'in dikey alanı sınırlı. Katalog uzadıkça
/// (yüzlerce dosya) burası dar kalır ve arama/filtre ister — tür/mood filtreleri
/// uçta VAR ama bu sürümde UI'ı YOK (bkz. rapor). O gün geldiğinde doğru hamle
/// bunu tam ekran bir rotaya terfi ettirmektir.
///
/// Sonuç [Navigator.pop] ile döner: seçilen [AudioAsset] ya da null (vazgeçti).
Future<AudioAsset?> showAssetCatalogSheet(BuildContext context) {
  return showModalBottomSheet<AudioAsset>(
    context: context,
    isScrollControlled: true,
    // bgBase (bgRaised DEĞİL): listedeki [NCard]'lar bgRaised kullanıyor —
    // sheet de aynı rengi alsaydı kartların kenarı kaybolur, liste tek bir
    // düz bloğa dönerdi.
    backgroundColor: NoctaColors.bgBase,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(NoctaRadius.sheet),
      ),
    ),
    builder: (context) => const AssetCatalogSheet(),
  );
}

/// Sheet'in gövdesi. **Ayrı bir public widget** çünkü widget testi onu
/// `showModalBottomSheet` kabuğu olmadan doğrudan kurabilsin (sheet animasyonu
/// testte gereksiz bir zamanlama kaynağı).
class AssetCatalogSheet extends ConsumerWidget {
  const AssetCatalogSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final catalog = ref.watch(audioAssetCatalogProvider);

    return SafeArea(
      child: ConstrainedBox(
        // Ekranın %70'i: arkada mikserin bir kısmı görünmeye devam etsin
        // (sheet'i seçmemizin sebebi buydu — tam ekran olsaydı rota iterdik).
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                NoctaSpace.s6,
                NoctaSpace.s5,
                NoctaSpace.s6,
                NoctaSpace.s3,
              ),
              child: Text(
                l10n.mixerAssetCatalogTitle,
                key: const Key('asset-catalog-title'),
                style: TextStyle(
                  fontSize: NoctaFontSize.h2,
                  color: NoctaColors.inkPrimary,
                ),
              ),
            ),
            Flexible(
              child: catalog.when(
                data: (list) => _list(context, list),
                loading: () => const Padding(
                  padding: EdgeInsets.all(NoctaSpace.s8),
                  child: Center(
                    child: CircularProgressIndicator(
                      key: Key('asset-catalog-loading'),
                    ),
                  ),
                ),
                // Ağ yok / 401 / 404 / bozuk JSON — hepsi BURAYA düşer ve sheet
                // KIRILMAZ: ne olduğunu söyleyen bir metin + yeniden dene.
                // (`NErrorState` deseni, kütüphane ekranıyla aynı.)
                error: (error, stack) => Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: NoctaSpace.s6,
                  ),
                  child: NErrorState(
                    retryKey: const Key('asset-catalog-retry'),
                    message: l10n.loadFailed,
                    retryLabel: l10n.offlineRetry,
                    onRetry: () => ref.invalidate(audioAssetCatalogProvider),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(BuildContext context, List<AudioAsset> list) {
    if (list.isEmpty) return _empty(context);
    return ListView.separated(
      key: const Key('asset-catalog-list'),
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(
        NoctaSpace.s5,
        0,
        NoctaSpace.s5,
        NoctaSpace.s6,
      ),
      itemCount: list.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: NoctaSpace.s3),
      itemBuilder: (context, i) {
        final asset = list[i];
        return InkWell(
          key: Key('asset-catalog-item-${asset.id}'),
          onTap: () => Navigator.of(context).pop(asset),
          borderRadius: BorderRadius.circular(NoctaRadius.card),
          child: NCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  // İÇERİK adı — i18n'e girmez (bkz. `AssetLayer.title`).
                  asset.title,
                  style: TextStyle(
                    fontSize: NoctaFontSize.body,
                    color: NoctaColors.inkPrimary,
                  ),
                ),
                if (_metaLine(asset).isNotEmpty) ...<Widget>[
                  const SizedBox(height: NoctaSpace.s1),
                  Text(
                    _metaLine(asset),
                    key: Key('asset-catalog-meta-${asset.id}'),
                    style: TextStyle(
                      fontSize: NoctaFontSize.caption,
                      color: NoctaColors.inkSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// "ambient · calm, warm" — tür + mood etiketleri.
  ///
  /// Bunlar SUNUCUDAKİ İÇERİK değerleri (`audio_assets.genre/mood`), arayüz
  /// metni değil: çevrilmezler, arb'ye girmezler. Ayraçlar metin değil noktalama.
  String _metaLine(AudioAsset asset) {
    final parts = <String>[
      if (asset.genre.isNotEmpty) asset.genre,
      if (asset.mood.isNotEmpty) asset.mood.join(', '),
    ];
    return parts.join(' · ');
  }

  /// BOŞ KATALOG — "hiç ses yok" demek yetmez, NE YAPACAĞINI söyler.
  ///
  /// Kullanıcı (bugün: tek kişilik ekip) dosyayı nereye koyacağını ve hangi
  /// komutu çalıştıracağını buradan öğrenir. Yol ve komut arb'de METNİN İÇİNDE
  /// duruyor — çevrilecek şey cümle, yol değil.
  Widget _empty(BuildContext context) {
    final l10n = AppL10n.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        NoctaSpace.s6,
        NoctaSpace.s2,
        NoctaSpace.s6,
        NoctaSpace.s8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            l10n.mixerAssetCatalogEmpty,
            key: const Key('asset-catalog-empty'),
            style: TextStyle(
              fontSize: NoctaFontSize.body,
              color: NoctaColors.inkPrimary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: NoctaSpace.s4),
          Text(
            l10n.mixerAssetCatalogEmptyHow,
            key: const Key('asset-catalog-empty-how'),
            style: TextStyle(
              fontSize: NoctaFontSize.caption,
              color: NoctaColors.inkSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Katalogdan seçilen kaydı mikserin çalabileceği katmana çevirir.
///
/// **Neden ayrı bir fonksiyon:** presigned URL'i almak İKİNCİ bir ağ çağrısıdır
/// (liste imza taşımaz) ve başarısız olabilir — 404 (dosya silinmiş), 401
/// (oturum düştü), ağ yok. Hepsinde dönüş null'dır ve çağıran kullanıcıya
/// söyler; sessizce boş bir katman eklenmez.
Future<AssetLayer?> resolveAssetLayer(WidgetRef ref, String id) async {
  final detail = await ref.read(audioAssetDetailProvider(id).future);
  return detail?.toLayer();
}
