import 'package:flutter/material.dart';

import '../../../../core/design_system/design_system.dart';

/// Uyku modunun merkezindeki **nefes alan küre**.
///
/// Tasarımda (Elegy §12) ekranın tamamı bu kürenin etrafında kurulu: başka
/// hiçbir şey hareket etmez. Nefes döngüsü 8 sn — docs/06'nın "her şey nefes alır,
/// 6–8 sn" kuralı.
///
/// **Hareket azaltma açıksa nefes DURUR** ama küre kaybolmaz: ekranın odağı o.
class NightOrb extends StatefulWidget {
  const NightOrb({super.key, this.size = 240});

  final double size;

  @override
  State<NightOrb> createState() => _NightOrbState();
}

class _NightOrbState extends State<NightOrb> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  );

  @override
  void initState() {
    super.initState();
    _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool reduce = MediaQuery.maybeDisableAnimationsOf(context) ??
        MediaQuery.maybeOf(context)?.disableAnimations ??
        false;

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final double t = reduce ? 0.5 : Curves.easeInOut.transform(_c.value);
          return Transform.scale(
            scale: 0.94 + t * 0.08,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: <Color>[
                    NoctaColors.nightInk.withValues(alpha: 0.20 + t * 0.10),
                    NoctaColors.bgNight,
                  ],
                  stops: const <double>[0.15, 1],
                ),
                border: Border.all(
                  color: NoctaColors.nightLine.withValues(alpha: 0.5 + t * 0.3),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
