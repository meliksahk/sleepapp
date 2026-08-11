import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio_engine/dsp/mix_render.dart';
import '../../../core/api/network_error_view.dart';
import '../../../core/design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';
import '../../content/content_models.dart';
import '../../content/content_providers.dart';
import '../data/local_sound_library_impl.dart'
    show kMaxFileBytes, kMaxImportedLayers, kMaxLibraryBytes;
import '../domain/local_sound.dart';
import '../domain/local_sound_library.dart';
import '../mixer_providers.dart';
import 'record_sound_screen.dart';

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
/// ## Bottom sheet DEĞİL, tam ekran (F1)
///
/// Sheet ekranın %70'iyle sınırlıydı: arama kutusu + kategori şeridi + iki bölüm
/// aynı anda sığmıyordu, klavye açılınca liste iki satıra düşüyordu. Kütüphane
/// büyüdükçe (ürünün asıl vaadi) bu daralma kabul edilemez.
///
/// **Neden `Navigator.push`, go_router rotası değil:** bu bir HEDEF değil, bir
/// SEÇİCİ — çağırana bir değer döndürür (`CatalogPick`) ve derin linki olmamalı
/// (bağlamsız açılan bir "ses seç" ekranının döneceği yer yoktur). go_router'ın
/// tip güvenli rota tablosu (CLAUDE.md §3.1) gezilebilir ekranlar içindir.
Future<CatalogPick?> openAssetCatalog(
  BuildContext context, {
  required int currentAssetLayerCount,
}) {
  return Navigator.of(context).push<CatalogPick>(
    MaterialPageRoute<CatalogPick>(
      builder: (context) =>
          AssetCatalogScreen(currentAssetLayerCount: currentAssetLayerCount),
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

class AssetCatalogScreen extends ConsumerStatefulWidget {
  const AssetCatalogScreen({super.key, required this.currentAssetLayerCount});

  /// Tavan kontrolü için: dolu ise seçici HİÇ açılmaz.
  final int currentAssetLayerCount;

  @override
  ConsumerState<AssetCatalogScreen> createState() => _AssetCatalogScreenState();
}

class _AssetCatalogScreenState extends ConsumerState<AssetCatalogScreen> {
  /// İthal sürüyor — düğme devre dışı, gösterge görünür. Çift basış İKİNCİ bir
  /// seçici açmamalı: iki eşzamanlı kopyalama disk sızdırabilir.
  bool _importing = false;

  /// Son ithal hatasının i18n metni. `null` → hata yok.
  String? _error;

  /// Kutuya YAZILAN metin (her tuşta değişir) — yerel listeyi anında süzer.
  String _typed = '';

  /// SUNUCUYA sorulan metin — [_debounce] sonrası [_typed]'a yetişir.
  ///
  /// İkisi ayrı, çünkü her tuş vuruşunda ağ isteği atmak hem sunucuyu hem
  /// kullanıcının bağlantısını boşa yorar; yerel listeyi geciktirmenin ise
  /// hiçbir sebebi yok (arama diskte, anında).
  String _searched = '';
  Timer? _debounce;

  /// Seçili kategori — yalnızca NOCTA kütüphanesi bölümünü etkiler
  /// (cihazdaki dosyaların türü yoktur). null = hepsi.
  String? _genre;

  static const Duration _debounceDelay = Duration(milliseconds: 300);

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() => _typed = value);
    _debounce?.cancel();
    _debounce = Timer(_debounceDelay, () {
      if (!mounted) return;
      setState(() => _searched = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final query = (genre: _genre, search: _searched);
    final catalog = ref.watch(audioAssetCatalogProvider(query));
    final local = ref.watch(localSoundsProvider);

    return Scaffold(
      appBar: AppBar(title: NMono(l10n.mixerAssetCatalogTitle)),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _header(l10n),
            _searchField(l10n),
            Expanded(
              child: ListView(
                key: const Key('asset-catalog-list'),
                padding: const EdgeInsets.fromLTRB(
                  NoctaSpace.s5,
                  NoctaSpace.s3,
                  NoctaSpace.s5,
                  NoctaSpace.s6,
                ),
                children: <Widget>[
                  // ── BU TELEFONDA ── her koşulda çizilir (ağdan bağımsız).
                  _sectionTitle(l10n.mixerLocalSectionTitle),
                  ..._localSection(l10n, local),

                  // ── NOCTA KÜTÜPHANESİ ── kategori şeridi bu bölüme aittir:
                  // türler kütüphanenin, cihazdaki dosyaların değil.
                  const SizedBox(height: NoctaSpace.s5),
                  _sectionTitle(l10n.mixerRemoteSectionTitle),
                  _genreStrip(l10n),
                  // Ağ hatası burada KALIR, yukarıdaki bölümü etkilemez.
                  ...catalog.when(
                    data: (list) => list.isEmpty
                        ? <Widget>[_noMatches(l10n)]
                        : <Widget>[for (final asset in list) _remoteRow(asset)],
                    loading: () => const <Widget>[
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
                      NetworkErrorView(
                        retryKey: const Key('asset-catalog-retry'),
                        onRetry: () =>
                            ref.invalidate(audioAssetCatalogProvider(query)),
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

  Widget _searchField(AppL10n l10n) => Padding(
    padding: const EdgeInsets.fromLTRB(
      NoctaSpace.s5,
      0,
      NoctaSpace.s5,
      NoctaSpace.s2,
    ),
    child: TextField(
      key: const Key('asset-catalog-search'),
      onChanged: _onSearchChanged,
      textInputAction: TextInputAction.search,
      style: const TextStyle(
        fontSize: NoctaFontSize.body,
        color: NoctaColors.inkPrimary,
      ),
      decoration: InputDecoration(
        hintText: l10n.catalogSearchHint,
        hintStyle: const TextStyle(color: NoctaColors.inkSecondary),
        prefixIcon: const Icon(
          Icons.search,
          size: 20,
          color: NoctaColors.inkSecondary,
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          vertical: NoctaSpace.s3,
          horizontal: NoctaSpace.s3,
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: NoctaColors.lineSoft),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: NoctaColors.inkSecondary),
        ),
      ),
    ),
  );

  /// Kategori şeridi — türler katalogtan gelir, elle yazılmaz (yeni tür eklenince
  /// şerit kendiliğinden büyür).
  Widget _genreStrip(AppL10n l10n) {
    final genres = ref.watch(audioAssetGenresProvider).valueOrNull;
    if (genres == null || genres.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: NoctaSpace.s3),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: <Widget>[
            _genreChip(l10n.catalogGenreAll, null),
            for (final g in genres) _genreChip(g, g),
          ],
        ),
      ),
    );
  }

  Widget _genreChip(String label, String? value) {
    final selected = _genre == value;
    return Padding(
      padding: const EdgeInsets.only(right: NoctaSpace.s2),
      child: InkWell(
        key: Key('asset-catalog-genre-${value ?? 'all'}'),
        onTap: () => setState(() => _genre = value),
        child: Container(
          // Dokunma hedefi ≥44px (CLAUDE.md §7).
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: NoctaSpace.s3),
          decoration: BoxDecoration(
            // Seçim RENKLE DEĞİL dolgu+kenarla işaretlenir: renk tek başına
            // taşıyıcı olamaz (CLAUDE.md §7).
            color: selected ? NoctaColors.bgOverlay : null,
            border: Border.all(
              color: selected ? NoctaColors.inkSecondary : NoctaColors.lineSoft,
            ),
          ),
          child: NMono(
            label,
            color: selected ? NoctaColors.inkPrimary : NoctaColors.inkSecondary,
            track: NoctaTrack.tight,
          ),
        ),
      ),
    );
  }

  Widget _noMatches(AppL10n l10n) => Padding(
    padding: const EdgeInsets.symmetric(vertical: NoctaSpace.s3),
    child: Text(
      // Arama/kategori boş sonuç verdiyse bunu SÖYLE. Boş bir alan bırakmak
      // "katalog yok" gibi okunur — oysa yalnızca bu süzgeç boş.
      _typed.isEmpty && _genre == null
          ? l10n.mixerAssetCatalogEmpty
          : l10n.catalogNoMatches,
      key: const Key('asset-catalog-no-matches'),
      style: const TextStyle(
        fontSize: NoctaFontSize.caption,
        color: NoctaColors.inkSecondary,
        height: 1.5,
      ),
    ),
  );

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
          NDisplay(
            l10n.mixerAssetCatalogTitle,
            key: const Key('asset-catalog-title'),
            size: NoctaFontSize.h2,
          ),
          if (total > 0)
            Text(
              // Kopyalama yaklaşımının BEDELİ görünür kılınıyor: kullanıcı ne
              // harcadığını bilmeden silmeye karar veremez.
              l10n.mixerLocalStorageUsed(_mb(total)),
              key: const Key('local-storage-used'),
              style: const TextStyle(
                fontFamily: NoctaFont.mono,
                fontSize: NoctaFontSize.micro,
                letterSpacing: NoctaTrack.tight,
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
          else ...<Widget>[
            // F3 — kendi kaydın. "Telefondan ekle"nin YANINDA ve aynı ağırlıkta:
            // ürünün vaadi (gerçek yerlerin sesi) burada başlıyor.
            TextButton.icon(
              key: const Key('mixer-record-place'),
              onPressed: _record,
              icon: const Icon(Icons.mic_none, size: 18),
              label: NMono(
                l10n.recordTitle,
                color: NoctaColors.inkSecondary,
                track: NoctaTrack.tight,
              ),
              style: TextButton.styleFrom(
                minimumSize: const Size(44, 44),
                foregroundColor: NoctaColors.inkSecondary,
                shape: const RoundedRectangleBorder(),
                side: const BorderSide(color: NoctaColors.lineDashed),
                padding: const EdgeInsets.symmetric(horizontal: NoctaSpace.s3),
              ),
            ),
            TextButton.icon(
              key: const Key('mixer-pick-from-device'),
              onPressed: _import,
              icon: const Icon(Icons.add, size: 18),
              label: NMono(
                l10n.mixerPickFromDevice,
                color: NoctaColors.inkSecondary,
                track: NoctaTrack.tight,
              ),
              style: TextButton.styleFrom(
                // Dokunma hedefi ≥44px (CLAUDE.md §7).
                minimumSize: const Size(44, 44),
                foregroundColor: NoctaColors.inkSecondary,
                shape: const RoundedRectangleBorder(),
                side: const BorderSide(color: NoctaColors.lineDashed),
                padding: const EdgeInsets.symmetric(horizontal: NoctaSpace.s3),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Kayıt ekranını açar; kullanıcı bir kayıt aldıysa doğrudan mikse koyar.
  Future<void> _record() async {
    final layer = await Navigator.of(context).push<AssetLayer>(
      MaterialPageRoute<AssetLayer>(
        builder: (context) => RecordSoundScreen(
          currentAssetLayerCount: widget.currentAssetLayerCount,
        ),
      ),
    );
    if (layer == null || !mounted) return;
    // Kütüphane listesi tazelensin (kayıt oraya da girdi).
    ref.invalidate(localSoundsProvider);
    Navigator.of(context).pop(CatalogPickLocal(layer));
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
    final all = index is LocalSoundIndexOk ? index.sounds : const <LocalSound>[];
    // Yerel arama DİSKTE, anında — sunucu gecikmesini beklemez.
    final sounds = _matching(all);

    if (sounds.isEmpty && all.isNotEmpty) {
      // Kütüphane dolu ama süzgeç boş: "hiç sesin yok" demek YANLIŞ olurdu.
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: NoctaSpace.s2),
          child: Text(
            l10n.catalogNoMatches,
            key: const Key('local-no-matches'),
            style: const TextStyle(
              fontSize: NoctaFontSize.caption,
              color: NoctaColors.inkSecondary,
              height: 1.5,
            ),
          ),
        ),
      );
      return widgets;
    }

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
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
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
      case LocalSoundImportRejected(
        :final reason,
        :final sizeBytes,
        :final usedBytes,
      ):
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
  ) => switch (reason) {
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
    LocalSoundImportFailure.pickerFailed => l10n.mixerLocalImportPickerFailed,
    LocalSoundImportFailure.tooManyLayers => l10n.mixerLocalImportTooManyLayers(
      '$kMaxImportedLayers',
    ),
    // `cancelled` buraya hiç gelmez (çağıran yerde eleniyor) ama switch'in
    // tükendiğinden emin olmak için sade bir metne düşer.
    LocalSoundImportFailure.cancelled ||
    LocalSoundImportFailure.unknown => l10n.mixerLocalImportUnknown,
  };

  /// Yazılan metne göre cihazdaki sesleri süzer.
  ///
  /// **`toLowerCase()` KULLANILMAZ:** Dart'ın locale'siz küçültmesi Türkçe'de
  /// `I → i` üretir (`ı` olmalı) ve "IŞIK" araması "ışık"ı bulamaz. `RegExp`'in
  /// `caseSensitive: false`'u en azından simetrik davranır; desen kaçırılır
  /// (`escape`) ki kullanıcının yazdığı `(` regex'e dönüşüp çökmesin.
  List<LocalSound> _matching(List<LocalSound> sounds) {
    final q = _typed.trim();
    if (q.isEmpty) return sounds;
    final re = RegExp(RegExp.escape(q), caseSensitive: false);
    return sounds.where((s) => re.hasMatch(s.title)).toList();
  }

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
