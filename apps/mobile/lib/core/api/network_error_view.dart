import 'package:flutter/material.dart';

import '../../app/flavor.dart';
import '../../l10n/app_localizations.dart';
import '../design_system/design_system.dart';

/// Sunucudan veri gelmeyince gösterilen hal — **ağ katmanının durumuna göre**.
///
/// **NEDEN VAR (F0):** dokuz ekran da tek bir metni gösteriyordu: "Bağlantını
/// kontrol edip tekrar dene." Kurulu APK'da ağ katmanı KAPALI (`apiBaseUrl: ''`,
/// bkz. `NoctaApiClient.isEnabled`) — yani kontrol edilecek bir bağlantı yok,
/// Wi-Fi'ı düzelten kullanıcı hiçbir şey kazanmıyor ve "yeniden dene" düğmesi
/// her basışta aynı hatayı veriyor. Kullanıcıya yalan söylüyorduk.
///
/// Ağ açıkken davranış aynen eskisi gibi (gerçek bağlantı hatası + yeniden dene).
/// Kapalıyken metin doğruyu söyler ve **yeniden dene düğmesi gizlenir** — işe
/// yaramayacak bir düğme sunmak, hatanın kendisinden daha kötü bir deneyimdir.
class NetworkErrorView extends StatelessWidget {
  const NetworkErrorView({super.key, required this.onRetry, this.retryKey});

  final VoidCallback onRetry;

  /// Mevcut ekran testleri düğmeyi key ile buluyor.
  final Key? retryKey;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    // Flavor bootstrap edilmemişse (izole widget testi) ESKİ davranış: ağ açık
    // varsayılır. "Bilmiyorum"u "sunucu yok" diye okumak yanlış olurdu.
    final bool hasApi = FlavorConfig.currentOrNull?.hasApi ?? true;
    return NErrorState(
      retryKey: retryKey,
      message: hasApi ? l10n.loadFailed : l10n.loadFailedNoServer,
      retryLabel: l10n.offlineRetry,
      onRetry: hasApi ? onRetry : null,
    );
  }
}
