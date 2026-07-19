import 'package:flutter/foundation.dart' show debugPrint;

import 'content_controller.dart';
import 'content_models.dart';
import 'data/content_library_source.dart';

/// İçerik kütüphanesinin **yerel-öncelikli** yüzü. Ekranlar artık
/// [ContentController] (ağ) yerine burayı kullanır.
///
/// ## NEDEN
///
/// Üç uç da (feed / detay / haftalık) KOŞULSUZ ağa gidiyordu ve yerel yedek
/// yoktu. `api.nocta.app` ayakta olmadığı için kurulan prod APK'da kütüphane
/// BOŞTU: kullanıcı "Kütüphane"ye giriyor, hata ekranı görüyordu. Mikser çalışsa
/// bile çalacak tarif yoksa "offline-first" (CLAUDE.md §3.1) bir iddiadan ibaret.
///
/// ## BİRLEŞTİRME POLİTİKASI — **SUNUCU YANIT VERİRSE SUNUCU KAZANIR**
///
/// Bu bir karar, bir varsayılan değil. Gerekçe:
///
/// - İçerik **güncellenebilir olmak zorunda.** Admin panelin (CMS) tüm varlık
///   sebebi bu: yeni bir soundscape ya da düzeltilmiş bir kazanç, mağaza sürümü
///   beklemeden kullanıcıya ulaşmalı. Gömülü kopya kazansaydı CMS ölü bir özellik
///   olurdu ve haftalık yayın kavramı anlamını yitirirdi.
/// - Gömülü kopya bir **taban**, bir tavan değil: "hiç yok"tan iyisi, "en güncel"
///   değil.
/// - Ayrışma riski drift kapısıyla (`check-content-drift.mjs`) yönetiliyor;
///   gömülü kopya ile seed'in aynı kaldığı CI'da garanti.
///
/// **TEK İSTİSNA — BOŞ YANIT KAZANMAZ.** Sunucu 200 ile BOŞ liste dönerse gömülü
/// kütüphane korunur. Sebep: taze kurulmuş (seed'lenmemiş) bir sunucu ya da
/// yanlış yapılandırılmış bir ortam, kullanıcının kütüphanesini sessizce
/// SİLERDİ — ve bu, ağ hatasından beter bir sonuçtur çünkü hata gibi
/// görünmez. "Bir şey biliyorsan söyle, bilmiyorsan sus."
///
/// ## SÖZLEŞME
///
/// - **Ağ ASLA zorunlu değil.** Her metot gömülü kütüphaneyle çalışır.
/// - **Sunucu denemesi best-effort ve SESSİZ.** Patlarsa kullanıcı hata görmez
///   (log'a düşer); gömülü kopya döner.
/// - Sunucu istemcisi **null olabilir** — sunucusuz bir build/test tamamen
///   geçerli bir yapılandırmadır.
class ContentService {
  ContentService({required this.library, this.remote});

  final ContentLibrarySource library;

  /// Sunucu istemcisi. null → hiç denenmez (ağ kapalı flavor'da böyle olur).
  final ContentController? remote;

  /// Soundscape feed'i. [archetype] verilirse yalnızca affinity eşleşenler öne
  /// alınmaz — sunucu sıralamasının yerel karşılığı YOK (bkz. BİLİNEN AÇIK).
  Future<List<Soundscape>> feed({String? archetype}) async {
    final remoteList = await _tryRemote(
      () => remote!.feed(archetype: archetype),
      'feed',
    );
    if (remoteList != null && remoteList.isNotEmpty) return remoteList;
    return (await library.load()).soundscapes;
  }

  /// Soundscape detayı (slug'a göre); ne sunucuda ne gömülü kopyada varsa null.
  Future<SoundscapeDetail?> soundscape(String slug) async {
    final remoteDetail = await _tryRemote(() => remote!.soundscape(slug), 'soundscape');
    if (remoteDetail != null) return remoteDetail;
    return (await library.load()).detail(slug);
  }

  /// En güncel haftalık yayın; gömülü kopyada da yoksa null.
  Future<WeeklyRelease?> weekly() async {
    final remoteWeekly = await _tryRemote(() => remote!.weekly(), 'weekly');
    if (remoteWeekly != null && remoteWeekly.soundscapes.isNotEmpty) return remoteWeekly;
    return (await library.load()).weekly;
  }

  /// Sunucu çağrısını dener; sunucu yok/patladıysa null. Kullanıcıya hata
  /// göstermeden gömülü kopyaya düşmenin tek yeri.
  ///
  /// **BİLİNEN AÇIK — 404 ile ağ hatası burada AYNI muamele görüyor.**
  /// `soundscape()` sunucuda 404 alırsa (kayıt gerçekten silinmiş) null döner ve
  /// gömülü kopya devreye girer, yani silinmiş bir tarif APK ömrü boyunca
  /// görünmeye devam eder. Kabul edildi: alternatif (404'ü "yok" diye
  /// kesinleştirmek) ağ hatasında kullanıcının kütüphanesini boşaltırdı ve o daha
  /// sık, daha kötü bir sonuç. İçerik silme yolu gerçekten gerektiğinde
  /// sunucudan gelen açık bir "tombstone" ile çözülür.
  Future<T?> _tryRemote<T>(Future<T?> Function() call, String label) async {
    if (remote == null) return null;
    try {
      return await call();
    } catch (e) {
      debugPrint('İçerik sunucu çağrısı başarısız ($label) — gömülü kütüphaneye düşülüyor: $e');
      return null;
    }
  }
}
