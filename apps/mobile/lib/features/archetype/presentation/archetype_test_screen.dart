import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/media/card_renderer.dart';
import '../../../core/share/sharer.dart';
import 'identity_share_card.dart';
import '../../analytics/analytics_providers.dart';
import '../archetype_gradient.dart';
import '../archetype_models.dart';
import '../archetype_providers.dart';

/// Archetype test ekranı (docs/04 M1): soruları yükle → her soruya bir seçenek →
/// gönder → sonuç. Veri katmanı ArchetypeController (401'de otomatik refresh).
///
/// **Neden yeniden tasarlandı:** bu ekran uygulamanın 1 numaralı viral kancası ama
/// çıplak bir listeydi — varsayılan AppBar, kartsız ham `Text` sorular, ilerleme
/// göstergesi yok, seçenekler ana ekranda denetlenip kaldırılan "dev menüsü"
/// (özdeş tam genişlik buton yığını) deseni, hata hali çıplak refresh ikonu ve
/// sonuç ekranı kullanıcının KENDİ arketip gradyanını hiç göstermiyordu. Gradyanı
/// ana ekranda ve paylaşılan PNG'de görüyordu ama sonucu İLK gördüğü anda değil.
///
/// **Düzen bilinçli olarak TEK KAYDIRMADA kalır — `PageView` değil.** Gerekçe:
/// gating davranışı (cevaplanmamış soruyla gönder → sonuç yok) submit butonunun
/// sihirbaz boyunca ağaçta olmasına dayanır ve testle kilitli
/// (`archetype_test_screen_test.dart`). Sayfalı akış bu kapıyı görünmez kılardı.
class ArchetypeTestScreen extends ConsumerStatefulWidget {
  const ArchetypeTestScreen({super.key});

  @override
  ConsumerState<ArchetypeTestScreen> createState() =>
      _ArchetypeTestScreenState();
}

class _ArchetypeTestScreenState extends ConsumerState<ArchetypeTestScreen> {
  ArchetypeQuestions? _questions;
  final Map<String, String> _answers = {};
  ArchetypeResult? _result;
  bool _loading = true;
  bool _submitting = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Açılış: kayıtlı sonuç varsa doğrudan göster (dönen kullanıcı testi tekrar
  /// yapmaz), yoksa soru sihirbazını yükle.
  ///
  /// **AĞ YOK.** Sonuç cihazdaki kayıttan, sorular gömülü matristen gelir; ikisi
  /// de backend olmadan çalışır (bkz. archetype_service.dart).
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final existing = await ref.read(archetypeServiceProvider).latest();
      if (!mounted) return;
      if (existing != null) {
        setState(() {
          _result = existing;
          _loading = false;
        });
        return;
      }
      await _loadQuestions();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _loadQuestions() async {
    final q = await ref.read(archetypeQuestionsProvider.future);
    if (!mounted) return;
    setState(() {
      _questions = q;
      _loading = false;
    });
  }

  /// Yeniden test: sonucu temizle, cevapları sıfırla, soruları yükle.
  Future<void> _retake() async {
    setState(() {
      _result = null;
      _answers.clear();
      _loading = true;
      _error = null;
    });
    try {
      await _loadQuestions();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  bool get _allAnswered =>
      _questions != null && _answers.length == _questions!.questions.length;

  Future<void> _submit() async {
    final q = _questions;
    if (q == null || !_allAnswered || _submitting) return;
    setState(() => _submitting = true);
    try {
      // CİHAZDA puanlanır, CİHAZA yazılır, ANINDA döner. Sunucuya gönderim arka
      // planda ve sessiz — patlarsa kullanıcı hiçbir şey görmez.
      final r = await ref.read(archetypeServiceProvider).submit(_answers);
      if (!mounted) return;
      // Ana ekran / geçmiş kimlik kartını yeni sonuçla tazelesin.
      ref.invalidate(latestArchetypeResultProvider);
      ref.invalidate(archetypeHistoryProvider);
      setState(() {
        _result = r;
        _submitting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Markalı AppBar — ana ekran deseni (transparan + letterSpacing).
      // `toUpperCase()` YOK: Dart'ın locale'siz büyütmesi Türkçe 'i' → 'I' üretir.
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: Text(
          AppL10n.of(context).archetypeTestTitle,
          style: TextStyle(
            fontSize: NoctaFontSize.caption,
            letterSpacing: 2.4,
            color: NoctaColors.inkSecondary,
          ),
        ),
      ),
      body: SafeArea(child: _body(context)),
    );
  }

  Widget _body(BuildContext context) {
    if (_result != null) {
      return _ResultView(result: _result!, onRetake: _retake);
    }
    if (_loading) return const _LoadingView();
    if (_error != null) {
      // Çıplak refresh ikonu DEĞİL: ne oldu / ne yapabilirim (NErrorState).
      return NErrorState(
        retryKey: const Key('archetype-retry'),
        message: AppL10n.of(context).loadFailed,
        retryLabel: AppL10n.of(context).offlineRetry,
        onRetry: _load,
      );
    }
    final l10n = AppL10n.of(context);
    final questions = _questions!.questions;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  NoctaSpace.s5,
                  NoctaSpace.s2,
                  NoctaSpace.s5,
                  NoctaSpace.s8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      l10n.archetypeTestIntro,
                      style: TextStyle(
                        fontSize: NoctaFontSize.caption,
                        height: 1.4,
                        color: NoctaColors.inkSecondary,
                      ),
                    ),
                    const SizedBox(height: NoctaSpace.s4),
                    _ProgressStrip(
                      answered: _answers.length,
                      total: questions.length,
                    ),
                    const SizedBox(height: NoctaSpace.s5),
                    for (var i = 0; i < questions.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: NoctaSpace.s4),
                        child: _questionCard(questions[i], i + 1),
                      ),
                    const SizedBox(height: NoctaSpace.s2),
                    NButton(
                      key: const Key('archetype-submit'),
                      label: _submitting
                          ? l10n.archetypeTestScoring
                          : l10n.archetypeTestSeeResult,
                      onPressed: _allAnswered && !_submitting ? _submit : null,
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

  Widget _questionCard(ArchetypeQuestion q, int number) {
    final bool answered = _answers.containsKey(q.id);
    return NCard(
      padding: const EdgeInsets.all(NoctaSpace.s5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _QuestionBadge(number: number, answered: answered),
              const SizedBox(width: NoctaSpace.s3),
              Expanded(
                // TEK `Text`: testler soru prompt'unu `find.text` ile arıyor —
                // RichText'e bölmek ya da harf harf animasyon kırardı.
                child: Text(
                  q.prompt,
                  style: TextStyle(
                    fontSize: NoctaFontSize.body,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                    color: NoctaColors.inkPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: NoctaSpace.s4),
          for (final o in q.options)
            Padding(
              padding: const EdgeInsets.only(bottom: NoctaSpace.s2),
              child: NSelectableOption(
                key: Key('opt-${q.id}-${o.id}'),
                label: o.label,
                selected: _answers[q.id] == o.id,
                onTap: () => setState(() => _answers[q.id] = o.id),
              ),
            ),
        ],
      ),
    );
  }
}

/// Soru numarası rozeti — cevaplanınca tike döner (ilerleme kartın içinde de okunur).
class _QuestionBadge extends StatelessWidget {
  const _QuestionBadge({required this.number, required this.answered});

  final int number;
  final bool answered;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: answered
            ? NoctaColors.accentAurora.withValues(alpha: 0.18)
            : NoctaColors.bgOverlay,
      ),
      child: answered
          ? Icon(Icons.check, size: 15, color: NoctaColors.accentAurora)
          : Text(
              // Rakam — çevrilen bir metin değil, sıra numarası.
              '$number',
              style: TextStyle(
                fontSize: NoctaFontSize.caption,
                fontWeight: FontWeight.w600,
                color: NoctaColors.inkFaint,
              ),
            ),
    );
  }
}

/// İlerleme: "kaç sorudan kaçı" + ince dolum çubuğu.
class _ProgressStrip extends StatelessWidget {
  const _ProgressStrip({required this.answered, required this.total});

  final int answered;
  final int total;

  @override
  Widget build(BuildContext context) {
    final double ratio = total == 0 ? 0 : (answered / total).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          AppL10n.of(context).archetypeTestProgress(answered, total),
          style: TextStyle(
            fontSize: NoctaFontSize.micro,
            letterSpacing: 1.2,
            color: NoctaColors.inkFaint,
          ),
        ),
        const SizedBox(height: NoctaSpace.s2),
        ClipRRect(
          borderRadius: BorderRadius.circular(NoctaRadius.full),
          child: SizedBox(
            height: 4,
            child: Stack(
              children: <Widget>[
                Container(color: NoctaColors.bgOverlay),
                FractionallySizedBox(
                  widthFactor: ratio,
                  child: Container(color: NoctaColors.accentAurora),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Yükleme hali — çıplak spinner yerine ne beklendiğini söyleyen bir an.
class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(NoctaSpace.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: NoctaColors.accentAurora,
              ),
            ),
            const SizedBox(height: NoctaSpace.s4),
            Text(
              AppL10n.of(context).archetypeTestPreparing,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: NoctaFontSize.caption,
                color: NoctaColors.inkSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultView extends ConsumerStatefulWidget {
  const _ResultView({required this.result, required this.onRetake});

  final ArchetypeResult result;
  final VoidCallback onRetake;

  @override
  ConsumerState<_ResultView> createState() => _ResultViewState();
}

class _ResultViewState extends ConsumerState<_ResultView> {
  bool _sharing = false;

  /// slug → görünen ad ("deep-ocean" → "Deep Ocean"). İçerik ucu gelmezse yedek.
  String get _display => widget.result.archetypeSlug
      .split('-')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  /// Tanıtım içeriği (public uç); gelmediyse null.
  ArchetypeInfo? get _info => ref
      .read(archetypeContentProvider)
      .maybeWhen(
        data: (m) => m[widget.result.archetypeSlug],
        orElse: () => null,
      );

  @override
  void initState() {
    super.initState();
    // Sonuç görüntülendi → analitik olayı (viral kanca ölçümü). Bloklamaz.
    ref
        .read(analyticsProvider)
        .track(
          'archetype_completed',
          props: {'archetype': widget.result.archetypeSlug},
        );
  }

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppL10n.of(context); // await'ten ONCE (context async gap)
    final locale = Localizations.localeOf(context).languageCode;
    try {
      // Sunucu varsa kanonik paylaşım verisi ondan; yoksa yerelden kurulur —
      // ağsız kullanıcı da paylaşabilmeli (viral kanca #1'in tüm anlamı bu).
      final share = await ref.read(archetypeServiceProvider).share(locale);
      if (share == null) return;

      // Viral kanca #1: link DEĞİL, GÖRSEL paylaşılır (docs/04 §103).
      // Kart render edilemezse paylaşım TÜMDEN düşmez — link'le devam eder.
      ShareFile? card;
      try {
        // Kart ağaçta DEĞİL: kendi render hattında çizilir (bkz. card_renderer.dart).
        final rendered = await renderWidgetToPng(
          IdentityShareCard(
            name: _info?.name ?? _display,
            tagline: _info?.tagline,
            gradient: IdentityShareCard.gradientFor(
              widget.result.archetypeSlug,
            ),
          ),
        );
        debugPrint(
          'Kimlik kartı render: ${rendered.elapsed.inMilliseconds}ms '
          '(bütçe ${shareCardRenderBudget.inMilliseconds}ms — docs/04 §105) '
          '${rendered.withinBudget ? "İÇİNDE" : "AŞILDI"}',
        );
        card = ShareFile.png(
          bytes: rendered.pngBytes,
          filename: 'nocta-${widget.result.archetypeSlug}.png',
        );
      } catch (e) {
        // Sessiz yutma DEĞİL: kart gitmedi ama kullanıcı yine paylaşabilsin.
        debugPrint('Kimlik kartı render edilemedi, link ile paylaşılıyor: $e');
      }

      await ref
          .read(sharerProvider)
          .share(
            ShareContent(text: share.title, url: share.webUrl, file: card),
          );
      // Viral huni ölçümü: tamamlama → paylaşım (analitik, bloklamaz).
      ref
          .read(analyticsProvider)
          .track(
            'share_tapped',
            props: {'archetype': widget.result.archetypeSlug},
          );
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.archetypeShareCopied)),
      );
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.archetypeShareFailed)),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final display = _display;
    // Tanıtım içeriği (public uç) — geldiyse tagline/özet göster (yoksa gizli).
    final info = ref
        .watch(archetypeContentProvider)
        .maybeWhen(
          data: (m) => m[widget.result.archetypeSlug],
          orElse: () => null,
        );

    // KAYDIRILABİLİR: uzun TR özeti + iki buton küçük ekranda taşıyordu; eski
    // `Center + Column` taşmayı görünür kılmadan kırpıyordu.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  NoctaSpace.s5,
                  NoctaSpace.s4,
                  NoctaSpace.s5,
                  NoctaSpace.s8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _IdentityReveal(
                      slug: widget.result.archetypeSlug,
                      label: l10n.archetypeYourSleepIdentity,
                      name: info?.name ?? display,
                      tagline: info?.tagline,
                    ),
                    if (info != null) ...<Widget>[
                      const SizedBox(height: NoctaSpace.s4),
                      NCard(
                        padding: const EdgeInsets.all(NoctaSpace.s5),
                        child: Text(
                          info.summary,
                          style: TextStyle(
                            fontSize: NoctaFontSize.body,
                            height: 1.45,
                            color: NoctaColors.inkSecondary,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: NoctaSpace.s6),
                    NButton(
                      key: const Key('archetype-share'),
                      label: _sharing
                          ? l10n.archetypeShareSharing
                          : l10n.archetypeShareButton,
                      onPressed: _sharing ? null : _share,
                    ),
                    const SizedBox(height: NoctaSpace.s3),
                    NButton(
                      key: const Key('archetype-retake'),
                      label: l10n.archetypeRetakeTest,
                      variant: NButtonVariant.ghost,
                      onPressed: widget.onRetake,
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

/// Sonucun açılış anı — kullanıcının KENDİ arketip gradyanı.
///
/// **Neden gradyan:** gradyan tek kaynaktan gelir (`archetypeGradientForSlug`,
/// #178) ve kimliğin görsel imzasıdır. Kullanıcı onu ana ekranda ve paylaştığı
/// PNG'de görüyordu ama sonucu İLK gördüğü — yani en çok önemsediği — anda
/// görmüyordu; sonuç düz bir kutuydu.
///
/// **Scrim (bgBase @ .28):** `identity_hero.dart` ile aynı desen; açık gradyan
/// uçlarında (dawn-chaser / delta-drifter) beyaz metin kontrastını geri kazandırır.
/// ⚠️ Oran ölçülmedi — gerçek cihazda karanlık odada kontrol edilmeli.
class _IdentityReveal extends StatelessWidget {
  const _IdentityReveal({
    required this.slug,
    required this.label,
    required this.name,
    required this.tagline,
  });

  final String slug;
  final String label;
  final String name;
  final String? tagline;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(NoctaRadius.card);
    return Container(
      decoration: BoxDecoration(
        gradient: archetypeGradientForSlug(slug),
        borderRadius: radius,
      ),
      child: Container(
        decoration: BoxDecoration(
          // Kontrast örtüsü — açık gradyan uçlarında metni okunur tutar.
          color: NoctaColors.bgBase.withValues(alpha: 0.28),
          borderRadius: radius,
        ),
        padding: const EdgeInsets.all(NoctaSpace.s6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label,
              style: TextStyle(
                fontSize: NoctaFontSize.micro,
                letterSpacing: 1.2,
                color: NoctaColors.inkPrimary.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: NoctaSpace.s3),
            // TEK `Text` + değişmeden yazılan ad: testler `find.text` ile arıyor.
            Text(
              name,
              key: const Key('archetype-result'),
              style: TextStyle(
                fontSize: NoctaFontSize.display,
                fontWeight: FontWeight.w600,
                height: 1.15,
                color: NoctaColors.inkPrimary,
              ),
            ),
            if (tagline != null && tagline!.isNotEmpty) ...<Widget>[
              const SizedBox(height: NoctaSpace.s2),
              Text(
                tagline!,
                key: const Key('archetype-tagline'),
                style: TextStyle(
                  fontSize: NoctaFontSize.body,
                  height: 1.4,
                  color: NoctaColors.inkPrimary.withValues(alpha: 0.85),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
