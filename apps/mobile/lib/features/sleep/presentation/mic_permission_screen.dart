import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';

/// **Mikrofon izin gerekçesi** (Elegy §13) — sistem izin kutusundan ÖNCE.
///
/// **Neden var:** iOS/Android'in izin kutusu tek satırlık bir gerekçe gösterir ve
/// kullanıcı "uyku uygulaması mikrofonumu neden istiyor" sorusunu orada cevapsız
/// yaşar. Cevapsız soru = "İzin verme". Bir kez reddedilen izni geri almak, sistem
/// ayarlarına gitmeyi gerektirir — yani ilk kutu, tek şansımız.
///
/// Bu ekran izin İSTEMEZ; yalnızca anlatır. Sistem kutusu bundan sonra, kayıt
/// başlarken çıkar. Ekran hiçbir söz vermez ki tutamayacağı bir şey söylemesin.
class MicPermissionScreen extends StatelessWidget {
  const MicPermissionScreen({super.key, this.denied = false});

  /// Kullanıcı daha önce reddettiyse: ekran bu kez "ne kaybettiğini" de söyler.
  final bool denied;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(NoctaSpace.s6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      // Olay çubukları: mikrofonun ne "duyduğunu" değil, ne
                      // SAYDIĞINI anlatan soyut bir işaret. Dalga formu çizmek
                      // sesin kaydedildiğini ima ederdi — tam tersini söylüyoruz.
                      const _EventTicks(),
                      const SizedBox(height: NoctaSpace.s8),
                      NDisplay(
                        l10n.micPermissionTitle,
                        key: const Key('mic-permission-title'),
                        size: NoctaFontSize.h1,
                        height: 1.12,
                      ),
                      const SizedBox(height: NoctaSpace.s6),
                      for (final fact in <String>[
                        l10n.micPermissionFactCounts,
                        l10n.micPermissionFactLocal,
                        l10n.micPermissionFactOptional,
                      ])
                        Padding(
                          padding: const EdgeInsets.only(bottom: NoctaSpace.s4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Container(
                                width: 10,
                                height: 10,
                                margin: const EdgeInsets.only(top: 7),
                                color: NoctaColors.accentAurora,
                              ),
                              const SizedBox(width: NoctaSpace.s4),
                              Expanded(
                                child: Text(
                                  fact,
                                  style: const TextStyle(
                                    fontSize: NoctaFontSize.caption,
                                    height: 1.7,
                                    color: NoctaColors.inkSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (denied) ...<Widget>[
                        const SizedBox(height: NoctaSpace.s4),
                        Container(
                          key: const Key('mic-permission-denied'),
                          padding: const EdgeInsets.all(NoctaSpace.s4),
                          decoration: BoxDecoration(
                            color: NoctaColors.bgDanger,
                            border: Border.all(color: NoctaColors.lineDanger),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              NMono(
                                l10n.micPermissionDeniedTitle,
                                color: NoctaColors.accentAuroraInk,
                              ),
                              const SizedBox(height: NoctaSpace.s2),
                              Text(
                                l10n.micPermissionDeniedBody,
                                style: const TextStyle(
                                  fontSize: NoctaFontSize.caption,
                                  height: 1.6,
                                  color: NoctaColors.inkSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: NoctaSpace.s5),
              // `pop(true)` → çağıran ritüeli başlatır (ve sistem kutusu çıkar).
              NButton(
                key: const Key('mic-permission-allow'),
                label: l10n.micPermissionAllow,
                expand: true,
                rule: true,
                onPressed: () => context.pop(true),
              ),
              const SizedBox(height: NoctaSpace.s3),
              // "Şimdi değil" bir ÇIKMAZ değil: ritüel izinsiz de çalışır.
              NButton(
                key: const Key('mic-permission-skip'),
                label: l10n.micPermissionSkip,
                variant: NButtonVariant.ghost,
                onPressed: () => context.pop(false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sayılan olayların soyut işareti — deterministik, animasyonsuz.
class _EventTicks extends StatelessWidget {
  const _EventTicks();

  /// Sabit desen: her açılışta aynı. Rastgele olsaydı ekran her girişte başka
  /// bir "ölçüm" gösterir, sanki gerçek veriymiş gibi okunurdu.
  static const List<double> _heights = <double>[
    12, 34, 18, 52, 26, 14, 40, 22, 64, 30, 16, 44, 20, 36, 12,
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          for (final h in _heights)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Container(
                  height: h,
                  color: h > 40
                      ? NoctaColors.accentAurora
                      : NoctaColors.lineStrong,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
