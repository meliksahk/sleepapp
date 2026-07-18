import 'package:flutter/foundation.dart' show debugPrint;

import 'archetype_controller.dart';
import 'archetype_models.dart';
import 'data/archetype_matrix_source.dart';
import 'data/local_archetype_store.dart';
import 'domain/archetype_matrix.dart';

/// Arketip testinin **yerel-öncelikli** yüzü. Ekranlar artık [ArchetypeController]
/// (ağ) yerine burayı kullanır.
///
/// ## NEDEN
///
/// `api.nocta.app` henüz ayakta değil. Testin her adımı ağa bağlı olduğu için
/// kurulan prod APK'da viral kanca #1 ÖLÜYDU: onboarding → ana ekran →
/// "Kimliğini keşfet" → hata + yeniden dene. Ölçtüğümüz her şeyin (paylaşım
/// oranı, D7) beslendiği kanca, kurulumda çalışmıyordu.
///
/// ## SÖZLEŞME
///
/// - **Sorular, puanlama, tanıtım metni: ağ YOK.** Hepsi gömülü matristen
///   (`assets/archetype/matrix.json`, sunucu domain'inden üretilir).
/// - **Sonuç ÖNCE yerele yazılır**, sonra döner. Kullanıcı sonucu ağdan bağımsız
///   ve anında görür.
/// - **Sunucu senkronu best-effort ve SESSİZ.** Gönderim patlarsa kullanıcı
///   hiçbir hata görmez (log'a düşer). Sunucu bu akışın parçası değil,
///   yedeğidir.
///
/// ## BİLİNEN AÇIK
///
/// Sunucu senkronu tek denemedir — offline kaydedilen bir sonuç, ağ geri
/// geldiğinde KENDİLİĞİNDEN yeniden gönderilmez. Cihazdaki kayıt kullanıcı için
/// yeterli (ekran ondan besleniyor); eksik olan sunucu tarafındaki analitik
/// kaydıdır. Kalıcı bir kuyruk (`sleep_session_queue.dart` deseni) ayrı bir iş.
class ArchetypeService {
  ArchetypeService({
    required this.matrixSource,
    required this.store,
    this.remote,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final ArchetypeMatrixSource matrixSource;
  final LocalArchetypeStore store;
  final DateTime Function() _now;

  /// Sunucu istemcisi. **null olabilir** — sunucusuz bir build/test tamamen
  /// geçerli bir yapılandırmadır.
  final ArchetypeController? remote;

  Future<ArchetypeMatrix> matrix() => matrixSource.load();

  /// Sihirbazın göstereceği sorular, verilen dilde. **Ağ isteği yok.**
  Future<ArchetypeQuestions> questions(String locale) async {
    final m = await matrix();
    return ArchetypeQuestions(
      version: m.version,
      questions: <ArchetypeQuestion>[
        for (final q in m.questions)
          ArchetypeQuestion(
            id: q.id,
            prompt: m.promptFor(q.id, locale),
            options: <ArchetypeOption>[
              for (final o in q.options)
                ArchetypeOption(
                  id: o.id,
                  label: m.optionLabel(q.id, o.id, locale),
                  archetype: o.archetype,
                ),
            ],
          ),
      ],
    );
  }

  /// Arketip tanıtım içeriği (slug → info), verilen dilde. **Ağ isteği yok.**
  Future<Map<String, ArchetypeInfo>> content(String locale) async {
    final m = await matrix();
    final texts = m.textsFor(locale);
    return <String, ArchetypeInfo>{
      for (final slug in m.archetypes)
        if (texts[slug] != null)
          slug: ArchetypeInfo(
            slug: slug,
            name: texts[slug]!.name,
            tagline: texts[slug]!.tagline,
            summary: texts[slug]!.summary,
          ),
    };
  }

  /// Cevapları CİHAZDA puanlar, yerele yazar ve sonucu döner. Sunucuya gönderim
  /// arka planda, sessizce denenir.
  ///
  /// Eksik/geçersiz cevapta [ArgumentError] — sunucunun 400'ünün yerel karşılığı.
  /// (Ekran zaten hepsi cevaplanmadan submit'i kapatıyor; bu ikinci kapı.)
  Future<ArchetypeResult> submit(Map<String, String> answers) async {
    final m = await matrix();
    final invalid = m.findInvalidAnswer(answers);
    if (invalid != null) {
      throw ArgumentError('Arketip cevapları geçersiz: $invalid');
    }

    final scored = m.scoreAnswers(answers);
    final result = ArchetypeResult(
      // Yerel puanlamada kullanıcı kimliği YOK (sunucusuz da çalışır). Alan
      // sunucu sözleşmesinin parçası; hiçbir ekranda gösterilmiyor.
      userId: '',
      archetypeSlug: scored.archetypeSlug,
      scores: scored.scores,
      version: m.version,
      createdAt: _now().toUtc().toIso8601String(),
    );

    // ÖNCE yerel: sunucu senkronu beklenmez, sonuç anında gösterilebilir olmalı.
    await store.save(result);
    _syncInBackground(m.version, answers);
    return result;
  }

  /// En son sonuç. **Önce yerel**; yerelde yoksa sunucu bir kez denenir (eski bir
  /// kurulumdan/başka cihazdan gelen sonuç kaybolmasın) — sunucu yoksa null.
  ///
  /// **SUNUCU DENEMESİ KISA BÜTÇELİ (`_discoveryBudget`).** Bu yol, testi HENÜZ
  /// YAPMAMIŞ her kullanıcının ana ekranında (kimlik kartı) her açılışta geçiliyor.
  /// Tam istemci timeout'u (5 sn) beklemek, ölü backend'de ana ekranı her seferinde
  /// 5 sn geciktirirdi — ölçüldü. Burada aranan şey "belki başka cihazda sonuç
  /// vardır" gibi opsiyonel bir kazanç; onun için kullanıcıyı bekletmeye değmez.
  Future<ArchetypeResult?> latest() async {
    final local = await store.latest();
    if (local != null) return local;

    final r = await _tryRemote(
      () => remote!.latestResult().timeout(_discoveryBudget),
      'latestResult',
    );
    if (r != null) await store.save(r);
    return r;
  }

  /// "Belki sunucuda vardır" keşif çağrıları için kısa bütçe. Kullanıcı bir şey
  /// İSTEMEDİ; bu opsiyonel bir zenginleştirme, o yüzden ekranı bekletmemeli.
  static const Duration _discoveryBudget = Duration(milliseconds: 1200);

  /// Sonuç geçmişi (yeniden eskiye). Yerel kayıt varsa o; yoksa sunucu denenir.
  Future<List<ArchetypeResult>> history() async {
    final local = await store.history();
    if (local.isNotEmpty) return local;

    final r = await _tryRemote(
      () => remote!.listResults().timeout(_discoveryBudget),
      'listResults',
    );
    return r ?? const <ArchetypeResult>[];
  }

  /// Paylaşım kartı verisi.
  ///
  /// **YEREL ÖNCELİKLİ — bu sıra bilinçli ve ölçülmüş.** Önceden sunucu ÖNCE
  /// deneniyordu; ölü backend'de paylaş butonu, ihtiyaç duyduğu her şey zaten
  /// cihazda olmasına rağmen tam 5 sn (istemci timeout'u) donuyordu. Üç ayrı
  /// denetim merceği bunu bağımsız ölçtü: aynı serviste `latest()` 0 ms iken
  /// `share()` 5024 ms. Paylaşım viral kanca #1'in ASIL eylemi ve bu iterasyonun
  /// tüm iddiası "backend olmadan çalışır" — o yüzden burada ağı beklemek
  /// doğrudan iddiayı çürütüyordu.
  ///
  /// Sunucu yalnızca **yerelde sonuç yokken** denenir (başka cihazdan/eski
  /// kurulumdan gelen sonuç kaybolmasın).
  Future<ArchetypeShare?> share(String locale) async {
    final result = await latest();
    if (result == null) {
      // Yerelde hiç sonuç yok → sunucuda olabilir (latest() zaten denedi ve
      // null döndü). Paylaşılacak bir şey yok.
      return null;
    }
    final info = (await content(locale))[result.archetypeSlug];
    return ArchetypeShare(
      archetypeSlug: result.archetypeSlug,
      title: info?.name ?? result.archetypeSlug,
      description: info?.tagline ?? '',
      webUrl: '$archetypeShareBaseUrl/${result.archetypeSlug}',
      deepLink: 'nocta://a/${result.archetypeSlug}',
    );
  }

  /// Paylaşım linkinin kökü. **AÇIK RİSK:** bu alan adı henüz bizim değil
  /// (bkz. defter — alan adı kararı beklemede). Sunucu ayaktayken kanonik URL
  /// ondan gelir; buradaki yalnızca ağsız yedektir.
  static const String archetypeShareBaseUrl = 'https://nocta.app/a';

  /// Sunucuya gönderim — **fire-and-forget**. Hata kullanıcıya ULAŞMAZ.
  ///
  /// Dönen Future test için tutulur ([pendingSync]); üretimde beklenmez.
  void _syncInBackground(int version, Map<String, String> answers) {
    final client = remote;
    if (client == null) return;
    pendingSync = () async {
      try {
        await client.submitAnswers(version, answers);
      } catch (e) {
        // Sessizce GEÇİLİR (tasarım): kullanıcı sonucunu zaten aldı ve o sonuç
        // cihazda kalıcı. Boş catch DEĞİL — hata burada YAKALANIR (yoksa
        // yakalanmamış Future hatası olarak testleri kirletirdi) ve teşhis için
        // log'lanır.
        debugPrint('Arketip sonucu sunucuya gönderilemedi (yerel kayıt sağlam): $e');
      }
    }();
  }

  /// Son arka plan senkronu. **Yalnızca test için**: "senkron patladı ama
  /// kullanıcı hata görmedi" iddiası, senkronun gerçekten koştuğunu bekleyebilmeyi
  /// gerektirir. Üretim kodu bunu okumaz.
  Future<void>? pendingSync;

  /// Sunucu çağrısını dener; sunucu yok/patladıysa null. Kullanıcıya hata
  /// göstermeden yedeğe düşmenin tek yeri.
  Future<T?> _tryRemote<T>(Future<T?> Function() call, String label) async {
    if (remote == null) return null;
    try {
      return await call();
    } catch (e) {
      debugPrint('Arketip sunucu çağrısı başarısız ($label) — yerele düşülüyor: $e');
      return null;
    }
  }
}
