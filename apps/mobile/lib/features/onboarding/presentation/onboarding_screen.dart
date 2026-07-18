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
        title: l10n.onboardingIdentityTitle,
        body: l10n.onboardingIdentityBody,
      ),
      _OnboardingPage(
        gradient: NoctaArchetypeGradient.overthinker,
        title: l10n.onboardingRitualTitle,
        body: l10n.onboardingRitualBody,
      ),
      _OnboardingPage(
        gradient: NoctaArchetypeGradient.deltaDrifter,
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
                  child: Text(
                    l10n.onboardingSkip,
                    style: TextStyle(color: NoctaColors.inkSecondary),
                  ),
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
            _Dots(count: pages.length, active: _page),
            Padding(
              padding: const EdgeInsets.all(NoctaSpace.s5),
              child: NButton(
                key: const Key('onboarding-cta'),
                label: _page >= last ? l10n.onboardingStart : l10n.onboardingNext,
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
    required this.title,
    required this.body,
  });

  final LinearGradient gradient;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: NoctaSpace.s5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          // Marka görseli: arketip gradyanından bir "gece küresi" — ekstra asset gerektirmez.
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: gradient),
          ),
          const SizedBox(height: NoctaSpace.s6),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: NoctaFontSize.h1,
              color: NoctaColors.inkPrimary,
            ),
          ),
          const SizedBox(height: NoctaSpace.s3),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: NoctaFontSize.body,
              color: NoctaColors.inkSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List<Widget>.generate(count, (i) {
        final on = i == active;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: on ? 20 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: on ? NoctaColors.accentAurora : NoctaColors.inkFaint,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
