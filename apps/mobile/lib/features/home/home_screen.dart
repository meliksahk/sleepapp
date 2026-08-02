import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/flavor.dart';
import '../../core/design_system/design_system.dart';
import '../../l10n/app_localizations.dart';
import '../archetype/archetype_providers.dart';
import '../content/content_providers.dart';
import '../sleep/sleep_providers.dart';
import 'widgets/explore_tile.dart';
import 'widgets/identity_hero.dart';
import 'widgets/identity_invite.dart';
import 'widgets/streak_strip.dart';
import 'widgets/weekly_card.dart';

/// Ana ekran — üç bölge: **Bu gece** (birincil eylem) → **Kimlik** → **Keşfet**.
///
/// **Neden yeniden yapılandırıldı:** eskiden alt alta 6 özdeş ghost buton vardı; bir
/// denetim bunu "dev menüsü" diye niteledi ve haklıydı — eşit ağırlıklı butonlar
/// kullanıcıya neyin önemli olduğunu söylemez. Artık hiyerarşi görsel: ekranın tek
/// `display` başlığı ve tek dolu butonu gece ritüelini başlatır; kimlik tek doygun
/// gradyandır; ikincil gezinme ikonlu karolara, ayarlar AppBar'a taşındı.
///
/// **Ekran `sessionBootstrapProvider`'ı OKUMAZ** (bilinçli): çevrimdışı anlatımı
/// kabuktaki `offline-banner`'da yaşar. Buraya ikinci bir çevrimdışı dalı eklemek
/// hem tekrar hem de router'sız koşan widget testlerini tanımsız bir dala sokardı.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final streak = ref.watch(streakProvider);
    final weekly = ref.watch(weeklyReleaseProvider);
    final result = ref.watch(latestArchetypeResultProvider);
    final content = ref.watch(archetypeContentProvider);
    final history = ref.watch(archetypeHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const NMono(
          'NOCTA',
          track: NoctaTrack.wide,
          color: NoctaColors.inkFaint,
        ),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: l10n.settingsTitle,
            color: NoctaColors.inkSecondary,
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      // KAYDIRILABİLİR + minHeight: ekran her yeni özellikle uzuyor; sabit Column
      // küçük ekranlarda taşıyordu (widget testi yakalamıştı). `Align(topCenter)`
      // kısa içerikte bloğu yukarıda sabit tutar (eski `Center` zıplatıyordu).
      body: SafeArea(
        child: LayoutBuilder(
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
                        // ── BÖLGE 1 · BU GECE (birincil) ──
                        // Elegy: bu blok bir kart değil, tuvale yapıştırılmış YIRTIK
                        // KAĞIT. Hafif eğim (~0,7°) kolajın elle yapıştırılmış hissini
                        // verir; `Transform.rotate` yerleşimi değil yalnız çizimi döndürür,
                        // o yüzden yükseklik hesabı bozulmaz.
                        Transform.rotate(
                          angle: -0.012,
                          child: NPaper(
                            seed: 7,
                            padding: const EdgeInsets.fromLTRB(
                              NoctaSpace.s6,
                              NoctaSpace.s8,
                              NoctaSpace.s5,
                              NoctaSpace.s6,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                NMono(
                                  l10n.homeTonightLabel,
                                  track: NoctaTrack.wide,
                                  color: NoctaColors.inkOnPaperSoft,
                                ),
                                const SizedBox(height: NoctaSpace.s3),
                                NDisplay(
                                  l10n.homeRitualTitle,
                                  size: NoctaFontSize.display,
                                  color: NoctaColors.inkOnPaper,
                                  height: 1.02,
                                ),
                                const SizedBox(height: NoctaSpace.s3),
                                Text(
                                  l10n.homeRitualSubtitle,
                                  style: const TextStyle(
                                    fontSize: NoctaFontSize.caption,
                                    color: NoctaColors.inkOnPaperSoft,
                                    height: 1.55,
                                  ),
                                ),
                                const SizedBox(height: NoctaSpace.s6),
                                NButton(
                                  key: const Key('sleep-mode-cta'),
                                  label: l10n.homeStartRitual,
                                  variant: NButtonVariant.inverse,
                                  expand: true,
                                  rule: true,
                                  onPressed: () => context.push('/sleep-mode'),
                                ),
                                const SizedBox(height: NoctaSpace.s4),
                                _PaperLink(
                                  key: const Key('mixer-cta'),
                                  label: l10n.homeOpenMixer,
                                  onTap: () => context.push('/mixer'),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: NoctaSpace.s8),

                        // ── BÖLGE 2 · KİMLİK ──
                        // Yükleme/hata → DAVET (ekran asla boşalmaz, archetype-cta hep 1).
                        result.maybeWhen(
                          data: (r) {
                            if (r == null) return const IdentityInvite();
                            final info = content.maybeWhen(
                              data: (m) => m[r.archetypeSlug],
                              orElse: () => null,
                            );
                            return IdentityHero(
                              slug: r.archetypeSlug,
                              name: info?.name ?? r.archetypeSlug,
                              tagline: info?.tagline,
                              historyCount: history.maybeWhen(
                                data: (list) => list.length,
                                orElse: () => 0,
                              ),
                            );
                          },
                          orElse: () => const IdentityInvite(),
                        ),
                        // Streak kimlikten BAĞIMSIZ koşullu (test bu kombinasyonu kuruyor).
                        streak.maybeWhen(
                          data: (s) => s.totalNights == 0
                              ? const SizedBox.shrink()
                              : Padding(
                                  padding: const EdgeInsets.only(
                                    top: NoctaSpace.s3,
                                  ),
                                  // Şerit artık bir KAPI: seri kendi ekranında
                                  // bağlamıyla (ay ızgarası, en uzun, ortalama)
                                  // yaşıyor — ana ekranda tek sayı bağlamsızdı.
                                  child: GestureDetector(
                                    key: const Key('streak-open'),
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () => context.push('/ritual'),
                                    child: StreakStrip(
                                      current: s.current,
                                      longest: s.longest,
                                    ),
                                  ),
                                ),
                          orElse: () => const SizedBox.shrink(),
                        ),
                        const SizedBox(height: NoctaSpace.s6),

                        // ── BÖLGE 3 · KEŞFET (üçüncül gezinme) ──
                        _SectionLabel(l10n.homeSectionExplore),
                        const SizedBox(height: NoctaSpace.s2),
                        // IntrinsicHeight ŞART: `Row` + `stretch` dikey eksende esner ve
                        // kaydırılabilir sütunda yükseklik SINIRSIZ olduğu için layout
                        // patlar ("RenderBox was not laid out" — testte yakalandı).
                        // IntrinsicHeight satıra en uzun karonun yüksekliğini verir →
                        // iki karo eşit yükseklikte, taşma yok.
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              Expanded(
                                child: ExploreTile(
                                  icon: Icons.graphic_eq,
                                  label: l10n.homeBrowseSoundscapes,
                                  onTap: () => context.push('/library'),
                                ),
                              ),
                              const SizedBox(width: NoctaSpace.s3),
                              Expanded(
                                child: ExploreTile(
                                  icon: Icons.bedtime_outlined,
                                  label: l10n.sleepHistoryTitle,
                                  onTap: () => context.push('/sleep'),
                                ),
                              ),
                            ],
                          ),
                        ),
                        weekly.maybeWhen(
                          data: (w) => w == null
                              ? const SizedBox.shrink()
                              : Padding(
                                  padding: const EdgeInsets.only(
                                    top: NoctaSpace.s4,
                                  ),
                                  child: WeeklyCard(release: w),
                                ),
                          orElse: () => const SizedBox.shrink(),
                        ),

                        // Build flavor rozeti YALNIZCA dev/staging'de (test için).
                        if (FlavorConfig.current.flavor != Flavor.prod)
                          Padding(
                            padding: const EdgeInsets.only(top: NoctaSpace.s6),
                            child: Text(
                              'flavor: ${FlavorConfig.current.name}',
                              style: TextStyle(
                                fontSize: NoctaFontSize.micro,
                                color: NoctaColors.inkFaint,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bölüm etiketi. `toUpperCase()` YASAK: Dart'ın locale'siz büyütmesi Türkçe
/// `i` → `I` üretir. Büyük harf etkisi mono aile + letterSpacing ile verilir.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => NMono(text, track: NoctaTrack.wide);
}

/// Kağıdın üstündeki ikincil eylem: altı çizili mono bağlantı.
/// Kağıt zeminde ghost buton (koyu çerçeve) ağır durur — tasarım burada
/// bilinçli olarak buton değil bağlantı kullanıyor.
class _PaperLink extends StatelessWidget {
  const _PaperLink({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          // Dokunma hedefi 44px: görsel çizgi ince, hedef değil (CLAUDE.md §7).
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.only(bottom: NoctaSpace.s1),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: NoctaColors.inkOnPaperSoft),
              ),
            ),
            child: NMono(
              label,
              color: NoctaColors.inkOnPaperSoft,
              track: NoctaTrack.tight,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}
