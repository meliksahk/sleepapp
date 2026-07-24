import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio_engine/dsp/mix_render.dart';
import '../../../core/design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';
import '../../content/content_models.dart';
import '../../content/content_providers.dart';
import '../data/local_sound_library_impl.dart'
    show kMaxFileBytes, kMaxImportedLayers, kMaxLibraryBytes;
import '../domain/local_sound.dart';
import '../domain/local_sound_library.dart';
import '../mixer_providers.dart';

/// Mikserdeki "Ses ekle" — **iki kaynak, eşit ağırlıkta.**
///
/// ## Yapısal karar: yerel bölüm `AsyncValue`'nun DIŞINDA
///
/// Eskiden bu sayfanın GÖVDESİNİN TAMAMI `catalog.when(...)` içindeydi. Sunucu
/// kataloğu yüklenemediğinde (ağ yok, 401, prod'da `apiBaseUrl` boş) sayfa
/// baştan sona hata durumuna düşüyordu. Cihazdan ses eklemek AĞ GEREKTİRMEDİĞİ
/// için bu, çalışan bir özelliği çalışmayan bir özelliğin arkasına saklamak
/// demekti — ve prod'da katalog HER ZAMAN boş olduğu için "Ses ekle" fiilen
/// bir çıkmazdı (kullanıcı bunu bildirdi, #22).
///
/// Artık "Bu telefonda" bölümü her koşulda çizilir; `catalog.when` yalnızca
/// "NOCTA kütüphanesi" bölümünü sarar.
///
/// ## Neden hâlâ bottom sheet
///
/// Mix çalarken seçiliyor (mikser arkada kalmalı), ambiyans kesilmiyor, çıkış
/// tek jest. **Bedeli:** dikey alan sınırlı; kütüphane büyüdükçe burası darlaşır
/// ve arama/filtre ister (bu sürümde YOK). O gün geldiğinde doğru hamle bunu tam
/// ekran bir rotaya terfi ettirmektir.
Future<CatalogPick?> showAssetCatalogSheet(
  BuildContext context, {
  required int currentAssetLayerCount,
}) {
  return showModalBottomSheet<CatalogPick>(
    context: context,
    isScrollControlled: true,
    // bgBase (bgRaised DEĞİL): listedeki [NCard]'lar bgRaised kullanıyor — sheet
    // de aynı rengi alsaydı kartların kenarı kaybolur, liste tek düz bloğa dönerdi.
    backgroundColor: NoctaColors.bgBase,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(NoctaRadius.sheet),
      ),
    ),
    builder: (context) => AssetCatalogSheet(
      currentAssetLayerCount: currentAssetLayerCount,
    ),
  );
}

/// Katalogtan dönen seçim.
///
/// **Sealed, çünkü iki dalın işi tamamen farklı:** uzak seçim bir AĞ çağrısıyla
/// presigned URL çözer, yerel seçim hiç ağ görmez. id string'ine `'local-'`
/// önekiyle bakıp dallanmak çalışırdı ama tipsizdi; derleyicinin kolladığı bir
/// ayrım, yorumla korunan bir ayrımdan iyidir.
sealed class CatalogPick {
  const CatalogPick();
}

class CatalogPickRemote extends CatalogPick {
  const CatalogPickRemote(this.id);
  final String id;
}

class CatalogPickLocal extends CatalogPick {
  const CatalogPickLocal(this.layer);
  final AssetLayer layer;
}

class AssetCatalogSheet extends ConsumerStatefulWidget {
  const AssetCatalogSheet({super.key, required this.currentAssetLayerCount});

  /// Tavan kontrolü için: dolu ise seçici HİÇ açılmaz.
  final int currentAssetLayerCount;

  @override
  ConsumerState<AssetCatalogSheet> createState() => _AssetCatalogSheetState();
}

class _AssetCatalogSheetState extends ConsumerState<AssetCatalogSheet> {
  /// İthal sürüyor — düğme devre dışı, gösterge görünür. Çift basış İKİNCİ bir
  /// seçici açmamalı: iki eşzamanlı kopyalama disk sızdırabilir.
  bool _importing = false;

  /// Son ithal hatasının i18n metni. `null` → hata yok.
  String? _error;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final catalog = ref.watch(audioAssetCatalogProvider);
    final local = ref.watch(localSoundsProvider);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _header(l10n),
            Flexible(
              child: ListView(
                key: const Key('asset-catalog-list'),
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(
                  NoctaSpace.s5,
                  0,
                  NoctaSpace.s5,
                  NoctaSpace.s6,
                ),
                children: <Widget>[
                  // ── BU TELEFONDA ── her koşulda çizilir (ağdan bağımsız).
                  _sectionTitle(l10n.mixerLocalSectionTitle),
                  ..._localSection(l10n, local),

                  // ── NOCTA KÜTÜPHANESİ ── yalnızca içerik varsa/yükleniyorsa.
                  // Ağ hatası burada KALIR, yukarıdaki bölümü etkilemez.
                  ...catalog.when(
                    data: (list) => list.isEmpty
                        ? const <Widget>[]
                        : <Widget>[
                            const SizedBox(height: NoctaSpace.s5),
                            _sectionTitle(l10n.mixerRemoteSectionTitle),
                            for (final asset in list) _remoteRow(asset),
                          ],
                    loading: () => const <Widget>[
                      SizedBox(height: NoctaSpace.s5),
                      Center(
                        child: Padding(
                          padding: EdgeInsets.all(NoctaSpace.s4),
                          child: CircularProgressIndicator(
                            key: Key('asset-catalog-loading'),
                          ),
                        ),
                      ),
                    ],
                    error: (error, stack) => <Widget>[
                      const SizedBox(height: NoctaSpace.s5),
                      _sectionTitle(l10n.mixerRemoteSectionTitle),
                      NErrorState(
                        retryKey: const Key('asset-catalog-retry'),
                        message: l10n.loadFailed,
                        retryLabel: l10n.offlineRetry,
                        onRetry: () =>
                            ref.invalidate(audioAssetCatalogProvider),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Başlık + disk kullanımı + "Telefondan ekle".
  ///
  /// **`Row` DEĞİL `Wrap`:** aynı ekranda ölçülmüş bir taşma düzeltmesinin
  /// (mixer_screen'deki katman başlığı) birebir gerekçesi burada da geçerli —
  /// üç çocuk, 2.0 yazı ölçeğinde 320 px genişliğe sığmaz. `Wrap` sığmayanı alt
  /// satıra alır; ne metin kırpılır ne dokunma hedefi küçülür.
  Widget _header(AppL10n l10n) {
    final total = ref.watch(localSoundsTotalProvider).valueOrNull ?? 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        NoctaSpace.s6,
        NoctaSpace.s5,
        NoctaSpace.s6,
        NoctaSpace.s3,
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: NoctaSpace.s3,
        runSpacing: NoctaSpace.s2,
        children: <Widget>[
          Text(
            l10n.mixerAssetCatalogTitle,
            key: const Key('asset-catalog-title'),
            style: TextStyle(
              fontSize: NoctaFontSize.h2,
              color: NoctaColors.inkPrimary,
            ),
          ),
          if (total > 0)
            Text(
              // Kopyalama yaklaşımının BEDELİ görünür kılınıyor: kullanıcı ne
              // harcadığını bilmeden silmeye karar veremez.
              l10n.mixerLocalStorageUsed(_mb(total)),
              key: const Key('local-storage-used'),
              style: TextStyle(
                fontSize: NoctaFontSize.caption,
                color: NoctaColors.inkSecondary,
              ),
            ),
          if (_importing)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    key: Key('mixer-import-progress'),
                    strokeWidth: 2,
                  ),
                ),
                const SizedBox(width: NoctaSpace.s2),
                Text(
                  l10n.mixerLocalImporting,
                  style: TextStyle(
                    fontSize: NoctaFontSize.caption,
                    color: NoctaColors.inkSecondary,
                  ),
                ),
              ],
            )
          else
            TextButton.icon(
              key: const Key('mixer-pick-from-device'),
              onPressed: _import,
              icon: const Icon(Icons.add, size: 18),
              label: Text(l10n.mixerPickFromDevice),
              style: TextButton.styleFrom(
                // Dokunma hedefi ≥44px (CLAUDE.md §7).
                minimumSize: const Size(44, 44),
                foregroundColor: NoctaColors.accentAurora,
                padding: const EdgeInsets.symmetric(
                  horizontal: NoctaSpace.s3,
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _localSection(AppL10n l10n, AsyncValue<LocalSoundIndex> local) {
    final widgets = <Widget>[];

    if (_error != null) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: NoctaSpace.s3),
          child: Text(
            _error!,
            key: const Key('local-import-error'),
            style: TextStyle(
              fontSize: NoctaFontSize.caption,
              color: NoctaColors.danger,
              height: 1.4,
            ),
          ),
        ),
      );
    }

    final index = local.valueOrNull;
    final sounds = index is LocalSoundIndexOk ? index.sounds : const <LocalSound>[];

    if (sounds.isEmpty) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: NoctaSpace.s2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
              const SizedBox(height: NoctaSpace.s2),
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
        ),
      );
    } else {
      for (final sound in sounds) {
        widgets.add(_localRow(l10n, sound));
      }
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: NoctaSpace.s2),
          child: Text(
            // DÜRÜSTLÜK DİPNOTU: ses kütüphanede kalıcı, ama mikser her
            // açıldığında katman listesi sıfırlanıyor. Söylememek yalan olurdu.
            l10n.mixerLocalSessionNotice,
            key: const Key('local-session-notice'),
            style: TextStyle(
              fontSize: NoctaFontSize.caption,
              color: NoctaColors.inkSecondary,
              height: 1.4,
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  Widget _localRow(AppL10n l10n, LocalSound sound) {
    return Padding(
      padding: const EdgeInsets.only(bottom: NoctaSpace.s3),
      child: InkWell(
        key: Key('local-sound-${sound.id}'),
        onTap: () => _pickLocal(sound),
        borderRadius: BorderRadius.circular(NoctaRadius.card),
        child: NCard(
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      // İÇERİK adı (kullanıcının dosya adı) — i18n'e girmez.
                      // Uzun/RTL/emoji olabilir: tek satır + ellipsis.
                      sound.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: NoctaFontSize.body,
                        color: NoctaColors.inkPrimary,
                      ),
                    ),
                    const SizedBox(height: NoctaSpace.s1),
                    Text(
                      '${_mb(sound.sizeBytes)} MB',
                      style: TextStyle(
                        fontSize: NoctaFontSize.caption,
                        color: NoctaColors.inkSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: Key('local-sound-delete-${sound.id}'),
                onPressed: () => _confirmDelete(l10n, sound),
                tooltip: l10n.mixerLocalDelete,
                // Dokunma hedefi ≥44px (CLAUDE.md §7).
                constraints: const BoxConstraints(
                  minWidth: 44,
                  minHeight: 44,
                ),
                icon: Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: NoctaColors.inkSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _remoteRow(AudioAsset asset) {
    return Padding(
      padding: const EdgeInsets.only(bottom: NoctaSpace.s3),
      child: InkWell(
        key: Key('asset-catalog-item-${asset.id}'),
        onTap: () => Navigator.of(context).pop(CatalogPickRemote(asset.id)),
        borderRadius: BorderRadius.circular(NoctaRadius.card),
        child: NCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
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
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: NoctaSpace.s3),
        child: Text(
          text,
          style: TextStyle(
            fontSize: NoctaFontSize.caption,
            color: NoctaColors.inkSecondary,
            letterSpacing: 1.2,
          ),
        ),
      );

  /// Seçiciyi aç, kopyala, sına, kaydet — ve başarılıysa doğrudan mikse ekle.
  ///
  /// Kullanıcı "telefondan ekle"ye bastığında niyeti dosyayı kütüphaneye
  /// KOYMAK değil, MİKSTE DUYMAK. Ara bir adım (kütüphaneye eklendi, şimdi bir
  /// de listeden seç) gereksiz bir dokunuş olurdu.
  Future<void> _import() async {
    setState(() {
      _importing = true;
      _error = null;
    });
    final l10n = AppL10n.of(context);
    final library = ref.read(localSoundLibraryProvider);
    final result = await library.import(
      currentAssetLayerCount: widget.currentAssetLayerCount,
    );
    if (!mounted) return;

    switch (result) {
      case LocalSoundImported(:final sound):
        final path = await library.pathOf(sound);
        if (!mounted) return;
        // Liste ve toplam tazelensin (kullanıcı sheet'e dönerse görsün).
        ref.invalidate(localSoundsProvider);
        Navigator.of(context).pop(
          CatalogPickLocal(
            AssetLayer(
              id: sound.id,
              title: sound.title,
              url: path,
              // Sunucudan gelen dosya katmanıyla AYNI varsayılan: gece yarısı
              // yeni bir katmanın ani seviye sıçraması yapmaması için düşük.
              gain: 0.3,
            ),
          ),
        );
      case LocalSoundImportRejected(:final reason, :final sizeBytes, :final usedBytes):
        setState(() {
          _importing = false;
          // Vazgeçmek HATA DEĞİL: ekranda hiçbir şey gösterilmez.
          _error = reason == LocalSoundImportFailure.cancelled
              ? null
              : _failureText(l10n, reason, sizeBytes, usedBytes);
        });
    }
  }

  Future<void> _pickLocal(LocalSound sound) async {
    final library = ref.read(localSoundLibraryProvider);
    final path = await library.pathOf(sound);
    if (!mounted) return;
    Navigator.of(context).pop(
      CatalogPickLocal(
        AssetLayer(id: sound.id, title: sound.title, url: path, gain: 0.3),
      ),
    );
  }

  Future<void> _confirmDelete(AppL10n l10n, LocalSound sound) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: NoctaColors.bgRaised,
        content: Text(
          // Kullanıcının TELEFONUNDAKİ orijinal dosyaya dokunulmadığını açıkça
          // söyler — yoksa silmeye korkar ve kütüphane sonsuza dek şişer.
          l10n.mixerLocalDeleteConfirm(sound.title),
          style: TextStyle(color: NoctaColors.inkPrimary),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            key: const Key('local-delete-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.mixerLocalDelete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final deleted = await ref.read(localSoundLibraryProvider).delete(sound.id);
    if (!mounted) return;
    ref.invalidate(localSoundsProvider);
    if (!deleted) {
      // Dosya silinemedi → KAYIT KORUNDU. Sessiz kalmak, kullanıcıya silinmiş
      // gibi gösterip diskte yetim bırakmak olurdu.
      setState(() => _error = l10n.mixerLocalDeleteFailed);
    }
  }

  String _failureText(
    AppL10n l10n,
    LocalSoundImportFailure reason,
    int? sizeBytes,
    int? usedBytes,
  ) =>
      switch (reason) {
        LocalSoundImportFailure.notAudio => l10n.mixerLocalImportNotPlayable,
        LocalSoundImportFailure.tooLarge => l10n.mixerLocalImportTooLarge(
            _mb(sizeBytes ?? 0),
            _mb(kMaxFileBytes),
          ),
        LocalSoundImportFailure.libraryFull => l10n.mixerLocalImportLibraryFull(
            _mb(usedBytes ?? 0),
            _mb(kMaxLibraryBytes),
          ),
        LocalSoundImportFailure.noSpace => l10n.mixerLocalImportNoSpace,
        LocalSoundImportFailure.sourceGone => l10n.mixerLocalImportSourceGone,
        LocalSoundImportFailure.pickerFailed =>
          l10n.mixerLocalImportPickerFailed,
        LocalSoundImportFailure.tooManyLayers =>
          l10n.mixerLocalImportTooManyLayers('$kMaxImportedLayers'),
        // `cancelled` buraya hiç gelmez (çağıran yerde eleniyor) ama switch'in
        // tükendiğinden emin olmak için sade bir metne düşer.
        LocalSoundImportFailure.cancelled ||
        LocalSoundImportFailure.unknown =>
          l10n.mixerLocalImportUnknown,
      };

  /// "4.1" — bir ondalık. Bayt göstermek kullanıcıya hiçbir şey anlatmaz.
  static String _mb(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);

  /// "ambient · calm, warm" — SUNUCUDAKİ içerik değerleri, arayüz metni değil:
  /// çevrilmezler, arb'ye girmezler.
  static String _metaLine(AudioAsset asset) {
    final parts = <String>[
      if (asset.genre.isNotEmpty) asset.genre,
      if (asset.mood.isNotEmpty) asset.mood.join(', '),
    ];
    return parts.join(' · ');
  }
}

/// Katalogtan seçilen SUNUCU kaydını mikserin çalabileceği katmana çevirir.
///
/// **Neden ayrı bir fonksiyon:** presigned URL'i almak İKİNCİ bir ağ çağrısıdır
/// (liste imza taşımaz) ve başarısız olabilir — 404 (dosya silinmiş), 401
/// (oturum düştü), ağ yok. Hepsinde dönüş null'dır ve çağıran kullanıcıya söyler.
Future<AssetLayer?> resolveAssetLayer(WidgetRef ref, String id) async {
  final detail = await ref.read(audioAssetDetailProvider(id).future);
  return detail?.toLayer();
}
