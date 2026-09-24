import 'package:flutter/material.dart';

import '../generated/nocta_tokens.dart';
import 'n_button.dart';
import 'n_text.dart';

/// Paylaşılan hata durumu — **çıplak refresh ikonunun yerine**.
///
/// **Neden var:** beş ekranda hata hali tek başına bir `IconButton(Icons.refresh)`
/// idi. Kullanıcı NE olduğunu, verinin neden gelmediğini, tekrar denemenin işe
/// yarayıp yaramayacağını bilmiyordu — bitmemiş bir uygulama izlenimi veriyordu.
/// Bir hata ekranı en az üç şey söylemeli: ne oldu, ne yapabilirim, umut var mı.
///
/// **Elegy:** ikon yerine kızıl bir işaret bloğu; çerçeveli koyu şerit.
/// Metin çağırandan gelir (i18n, CLAUDE.md §4); bileşen dizge tutmaz.
class NErrorState extends StatelessWidget {
  const NErrorState({
    super.key,
    required this.message,
    required this.retryLabel,
    required this.onRetry,
    this.icon = Icons.cloud_off,
    this.retryKey,
  });

  final String message;
  final String retryLabel;

  /// null → düğme HİÇ çizilmez. Yeniden denemenin işe yaramayacağı hallerde
  /// (ör. ağ katmanı komple kapalı) düğme göstermek kullanıcıyı oyalar.
  final VoidCallback? onRetry;

  /// Elegy'de kullanılmıyor (işaret bloğu geldi); API kırılmasın diye duruyor.
  final IconData icon;

  /// Mevcut testler retry düğmesini key ile buluyor — çağıran koruyabilsin.
  final Key? retryKey;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(NoctaSpace.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(
              decoration: BoxDecoration(
                color: NoctaColors.bgDanger,
                border: Border.all(color: NoctaColors.lineDanger),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: NoctaSpace.s4,
                vertical: NoctaSpace.s4,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 6),
                    color: NoctaColors.accentAurora,
                  ),
                  const SizedBox(width: NoctaSpace.s3),
                  Expanded(
                    child: Text(
                      message,
                      style: const TextStyle(
                        fontSize: NoctaFontSize.body,
                        color: NoctaColors.inkSecondary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (onRetry != null) ...<Widget>[
              const SizedBox(height: NoctaSpace.s5),
              NButton(
                key: retryKey,
                label: retryLabel,
                variant: NButtonVariant.ghost,
                onPressed: onRetry!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Boş hal — Elegy'de "özür" değil **yönlendirme**: organik leke + serif cümle.
class NEmptyState extends StatelessWidget {
  const NEmptyState({
    super.key,
    required this.title,
    this.body,
    this.actionLabel,
    this.onAction,
  });

  final String title;

  /// Boş bırakılabilir: her boş halin ikinci cümlesi yok, uydurmak yerine sus.
  final String? body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final String? action = actionLabel;
    return Padding(
      padding: const EdgeInsets.all(NoctaSpace.s6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 120,
            height: 156,
            decoration: BoxDecoration(
              border: Border.all(color: NoctaColors.lineSoft),
              borderRadius: BorderRadius.circular(NoctaRadius.full),
            ),
          ),
          const SizedBox(height: NoctaSpace.s8),
          NDisplay(title, size: NoctaFontSize.h2, height: 1.15),
          if (body != null) ...<Widget>[
            const SizedBox(height: NoctaSpace.s3),
            Text(
              body!,
              style: const TextStyle(
                fontSize: NoctaFontSize.caption,
                color: NoctaColors.inkSecondary,
                height: 1.6,
              ),
            ),
          ],
          if (action != null && onAction != null) ...<Widget>[
            const SizedBox(height: NoctaSpace.s6),
            NButton(label: action, onPressed: onAction),
          ],
        ],
      ),
    );
  }
}
