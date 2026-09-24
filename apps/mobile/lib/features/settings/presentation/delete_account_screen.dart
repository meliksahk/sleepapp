import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/auth_providers.dart';

/// **Hesap silme** (Elegy §21) — App Store'un pazarlıksız şartı.
///
/// Sunucu tarafı (`DELETE /v1/auth/me`, kaskad) aylardır hazırdı; eksik olan tek
/// şey buydu: kullanıcının ona ulaşabildiği bir ekran. Uç yazılıp ekranı
/// yazılmayan bir özellik, olmayan bir özelliktir.
///
/// **İki kapı:** onay kutusu işaretlenmeden buton pasiftir. "Emin misiniz?"
/// diyaloğu YOK — diyalog, yarı okunan bir metnin üstüne binen ikinci bir yarı
/// okunan metindir. Burada kullanıcı NE silineceğini listede görür ve bunu
/// bilerek onaylar.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  bool _confirmed = false;
  bool _busy = false;

  Future<void> _delete() async {
    if (!_confirmed || _busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final l10n = AppL10n.of(context); // await'ten ÖNCE (context async gap)
    try {
      await ref.read(authControllerProvider).deleteAccount();
      // Oturum gitti: köke dön. Kabuk oturumsuz durumu görüp karşılamayı kurar.
      router.go('/');
    } catch (_) {
      // "Hiçbir şey kaldırılmadı" cümlesi bilinçli: sunucu 4xx/5xx döndüyse
      // hesap DURUYOR. Belirsiz bir "bir şeyler ters gitti", kullanıcıyı
      // hesabının yarı silinmiş olabileceği korkusunda bırakırdı.
      messenger.showSnackBar(SnackBar(content: Text(l10n.deleteAccountFailed)));
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Scaffold(
      appBar: AppBar(title: NMono(l10n.privacyDeleteEntry)),
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
                      // Yıkıcı ekranın lekesi: kızıl çerçeveli boş oval.
                      Container(
                        width: 120,
                        height: 156,
                        decoration: BoxDecoration(
                          color: NoctaColors.bgDanger,
                          border: Border.all(color: NoctaColors.lineDanger),
                          borderRadius: BorderRadius.circular(NoctaRadius.full),
                        ),
                      ),
                      const SizedBox(height: NoctaSpace.s8),
                      NDisplay(
                        l10n.deleteAccountTitle,
                        key: const Key('delete-account-title'),
                        size: NoctaFontSize.h1,
                        height: 1.1,
                      ),
                      const SizedBox(height: NoctaSpace.s4),
                      Text(
                        l10n.deleteAccountBody,
                        style: const TextStyle(
                          fontSize: NoctaFontSize.body,
                          height: 1.7,
                          color: NoctaColors.inkSecondary,
                        ),
                      ),
                      const SizedBox(height: NoctaSpace.s6),
                      for (final item in <String>[
                        l10n.deleteAccountItemNights,
                        l10n.deleteAccountItemMixes,
                        l10n.deleteAccountItemIdentity,
                        l10n.deleteAccountItemDevices,
                      ])
                        Padding(
                          padding: const EdgeInsets.only(bottom: NoctaSpace.s3),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Container(
                                width: 12,
                                height: 1,
                                margin: const EdgeInsets.only(top: 9),
                                color: NoctaColors.lineDanger,
                              ),
                              const SizedBox(width: NoctaSpace.s3),
                              Expanded(
                                child: NMono(
                                  item,
                                  color: NoctaColors.inkSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: NoctaSpace.s5),
                      _ConfirmRow(
                        checked: _confirmed,
                        label: l10n.deleteAccountConfirm,
                        onTap: _busy
                            ? null
                            : () => setState(() => _confirmed = !_confirmed),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: NoctaSpace.s5),
              // Onay kutusu işaretlenmeden `onPressed` NULL → buton pasif.
              // Bu, "yanlışlıkla iki dokunuş" senaryosunun tek savunması.
              NButton(
                key: const Key('delete-account-cta'),
                label: _busy
                    ? l10n.deleteAccountDeleting
                    : l10n.deleteAccountCta,
                onPressed: _confirmed && !_busy ? _delete : null,
                expand: true,
                rule: true,
              ),
              const SizedBox(height: NoctaSpace.s3),
              NButton(
                key: const Key('delete-account-cancel'),
                label: l10n.deleteAccountCancel,
                variant: NButtonVariant.ghost,
                onPressed: _busy ? null : () => context.pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Onay kutusu — Material `Checkbox` değil: Elegy'de kutu yuvarlatılmaz ve
/// işaret tik değil DOLU BLOKtur. Dokunma hedefi satırın tamamı (≥44px).
class _ConfirmRow extends StatelessWidget {
  const _ConfirmRow({
    required this.checked,
    required this.label,
    required this.onTap,
  });

  final bool checked;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: checked,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.centerLeft,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                key: const Key('delete-account-confirm'),
                width: 22,
                height: 22,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  color: checked
                      ? NoctaColors.accentAurora
                      : Colors.transparent,
                  border: Border.all(
                    color: checked
                        ? NoctaColors.accentAurora
                        : NoctaColors.lineStrong,
                  ),
                ),
              ),
              const SizedBox(width: NoctaSpace.s3),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: NoctaFontSize.caption,
                    height: 1.5,
                    color: NoctaColors.inkSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
