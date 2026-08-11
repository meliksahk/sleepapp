import 'package:flutter/material.dart';

import '../../../core/design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';

/// İlk açılış karşılaması (Faz 0 cila).
///
/// **Neden var:** uygulama daha önce soğuk açılıyordu — kullanıcı ne olduğunu anlamadan
/// bir ekranla ve (uyku modunda) habersiz bir mikrofon izniyle karşılaşıyordu. Üç sayfa:
/// kimlik (ne sunuyoruz) → ritüel (nasıl çalışır) → izin priming (mikrofonu NEDEN istiyoruz
/// ve ham sesin telefonda kaldığı). Priming yalnızca AÇIKLAR; gerçek izin istemi kendi
/// bağlamında (uyku modu başlarken) sorulur.
///
/// Sağlık iddiası YOK (CLAUDE.md §1.1): metinler "ritüel/rahatlama" dilinde.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});

  /// Akış bitince (Başla veya Atla) çağrılır — çağıran "görüldü" damgasını yazar.
  final Future<void> Function() onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next(int lastIndex) {
    if (_page >= lastIndex) {
      unawaitedDone();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  /// `onDone` Future döner ama buton geri bildirimi beklemeye gerek yok:
  /// çağıran damgayı yazıp kökü yeniden kurar.
  void unawaitedDone() {
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final pages = <_OnboardingPage>[
      _OnboardingPage(
        gradient: NoctaArchetypeGradient.deepOcean,
        step: '1 / 3',
        title: l10n.onboardingIdentityTitle,
        body: l10n.onboardingIdentityBody,
      ),
      _OnboardingPage(
        gradient: NoctaArchetypeGradient.overthinker,
        step: '2 / 3',
        title: l10n.onboardingRitualTitle,
        body: l10n.onboardingRitualBody,
      ),
      _OnboardingPage(
        gradient: NoctaArchetypeGradient.deltaDrifter,
        step: '3 / 3',
        title: l10n.onboardingAlarmTitle,
        body: l10n.onboardingAlarmBody,
      ),
    ];
    final last = pages.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            // Atla: her zaman erişilebilir — kullanıcıyı akışta hapsetmeyiz.
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.all(NoctaSpace.s3),
                child: TextButton(
                  key: const Key('onboarding-skip'),
                  onPressed: unawaitedDone,
                  child: NMono(l10n.onboardingSkip),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) => pages[i],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: NoctaSpace.s6),
              child: _Dots(count: pages.length, active: _page),
            ),
            Padding(
              padding: const EdgeInsets.all(NoctaSpace.s6),
              child: NButton(
                key: const Key('onboarding-cta'),
                label: _page >= last ? l10n.onboardingStart : l10n.onboardingNext,
                expand: true,
                rule: true,
                onPressed: () => _next(last),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.gradient,
    required this.step,
    required this.title,
    required this.body,
  });

  final LinearGradient gradient;
  final String step;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    // Elegy: metin ORTALANMAZ. Kolajda her şey bir kenara yaslanır; ortalama
    // metin sunum slaytı hissi veriyordu.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: NoctaSpace.s6),
      child: Stack(
        children: <Widget>[
          // Organik leke: daire değil ELİPS — kolajın kesilmiş kağıt lekeleri.
          Positioned(
            left: -60,
            top: 40,
            child: Container(
              width: 210,
              height: 270,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(NoctaRadius.full),
                gradient: gradient,
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                NMono(step, track: NoctaTrack.wide),
                const SizedBox(height: NoctaSpace.s5),
                NDisplay(title, size: NoctaFontSize.display, height: 1.06),
                const SizedBox(height: NoctaSpace.s4),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: Text(
                    body,
                    style: const TextStyle(
                      fontSize: NoctaFontSize.body,
                      color: NoctaColors.inkSecondary,
                      height: 1.65,
                    ),
                  ),
                ),
                const SizedBox(height: NoctaSpace.s8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// İlerleme: nokta değil **çubuk**. Tasarımda üç eşit şerit var; aktif olan
/// dolu ve kalın, geçilmiş olanlar sönük — sayfa sayısını göz saymadan görür.
class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List<Widget>.generate(count, (i) {
        final bool on = i == active;
        final bool past = i < active;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: NoctaSpace.s2),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: on ? 6 : 2,
              color: on
                  ? NoctaColors.inkPrimary
                  : past
                  ? NoctaColors.inkFaint
                  : NoctaColors.lineStrong,
            ),
          ),
        );
      }),
    );
  }
}
