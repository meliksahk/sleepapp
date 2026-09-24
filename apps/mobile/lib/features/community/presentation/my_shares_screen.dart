import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/network_error_view.dart';
import '../../../core/design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';
import '../community_providers.dart';

/// Kullanıcının topluluk paylaşımları ve DURUMLARI (3b).
///
/// Red gerekçesi burada GÖRÜNÜR — moderasyonun sessiz sansüre dönüşmemesi
/// için pazarlıksız kuraldır: red kararı her zaman gerekçeyle gelir (DB CHECK)
/// ve sahibi okur.
class MyShare {
  const MyShare({
    required this.id,
    required this.title,
    required this.status,
    required this.rejectionReason,
    required this.durationSeconds,
  });

  factory MyShare.fromJson(Map<String, dynamic> json) => MyShare(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        status: json['status'] as String? ?? 'pending',
        rejectionReason: json['rejectionReason'] as String?,
        durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      );

  final String id;
  final String title;
  final String status;
  final String? rejectionReason;
  final int durationSeconds;
}

class MySharesScreen extends ConsumerWidget {
  const MySharesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final shares = ref.watch(mySharesProvider);

    return Scaffold(
      backgroundColor: NoctaColors.bgBase,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: NoctaColors.inkPrimary,
        title: Text(
          l10n.mySharesTitle,
          style: TextStyle(
            fontFamily: NoctaFont.mono,
            fontSize: NoctaFontSize.h2,
            color: NoctaColors.inkPrimary,
          ),
        ),
      ),
      body: shares.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(key: Key('my-shares-loading'))),
        // Ağ katmanı kapalıyken (kurulu APK'nın bugünkü hâli) "yüklenemedi +
        // yeniden dene" yanıltıcıydı: sunucu yok, yeniden deneme her seferinde
        // aynı hatayı verir. NetworkErrorView ağ kapalıyken dürüst metni
        // gösterir ve düğmeyi gizler; ağ açıkken bu ekranın kendi metni kalır.
        error: (_, _) => NetworkErrorView(
          retryKey: const Key('my-shares-retry'),
          onlineMessage: l10n.mySharesLoadFailed,
          onRetry: () => ref.invalidate(mySharesProvider),
        ),
        data: (items) => items.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(NoctaSpace.s6),
                  child: Text(
                    l10n.mySharesEmpty,
                    key: const Key('my-shares-empty'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: NoctaFontSize.body,
                      color: NoctaColors.inkSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              )
            : RefreshIndicator(
                onRefresh: () async => ref.refresh(mySharesProvider.future),
                child: ListView.builder(
                  key: const Key('my-shares-list'),
                  padding: const EdgeInsets.all(NoctaSpace.s5),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final s = items[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: NoctaSpace.s3),
                      child: NCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    s.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: NoctaFontSize.body,
                                      color: NoctaColors.inkPrimary,
                                    ),
                                  ),
                                ),
                                _statusChip(l10n, s.status),
                              ],
                            ),
                            const SizedBox(height: NoctaSpace.s1),
                            Text(
                              '${s.durationSeconds ~/ 60} min',
                              style: TextStyle(
                                fontSize: NoctaFontSize.caption,
                                color: NoctaColors.inkFaint,
                              ),
                            ),
                            if (s.status == 'rejected' &&
                                (s.rejectionReason?.isNotEmpty ?? false)) ...<Widget>[
                              const SizedBox(height: NoctaSpace.s2),
                              Text(
                                // Gerekçe SAHİBİNE gösterilir — sessiz red yok.
                                l10n.mySharesRejectionReason(s.rejectionReason!),
                                style: TextStyle(
                                  fontSize: NoctaFontSize.caption,
                                  color: NoctaColors.accentDawn,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }

  Widget _statusChip(AppL10n l10n, String status) {
    final (label, color) = switch (status) {
      'approved' => (l10n.shareStatusApproved, NoctaColors.accentAurora),
      'rejected' => (l10n.shareStatusRejected, NoctaColors.danger),
      _ => (l10n.shareStatusPending, NoctaColors.accentDawn),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: NoctaSpace.s2, vertical: NoctaSpace.s1),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: NoctaFont.mono,
          fontSize: NoctaFontSize.micro,
          letterSpacing: NoctaTrack.tight,
          color: color,
        ),
      ),
    );
  }
}
