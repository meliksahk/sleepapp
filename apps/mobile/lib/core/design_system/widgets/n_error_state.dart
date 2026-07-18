import 'package:flutter/material.dart';

import '../generated/nocta_tokens.dart';
import 'n_button.dart';

/// Paylaşılan hata durumu — **çıplak refresh ikonunun yerine**.
///
/// **Neden var:** beş ekranda hata hali tek başına bir `IconButton(Icons.refresh)`
/// idi. Kullanıcı NE olduğunu, verinin neden gelmediğini, tekrar denemenin işe
/// yarayıp yaramayacağını bilmiyordu — bitmemiş bir uygulama izlenimi veriyordu.
/// Bir hata ekranı en az üç şey söylemeli: ne oldu, ne yapabilirim, umut var mı.
///
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
  final VoidCallback onRetry;
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
          children: <Widget>[
            Icon(icon, size: 40, color: NoctaColors.inkFaint),
            const SizedBox(height: NoctaSpace.s4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: NoctaFontSize.body,
                color: NoctaColors.inkSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: NoctaSpace.s5),
            NButton(
              key: retryKey,
              label: retryLabel,
              variant: NButtonVariant.ghost,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
