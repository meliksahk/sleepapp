import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/session.dart' show ApiException;
import '../auth/auth_providers.dart';
import 'community_share_service.dart';
import 'presentation/my_shares_screen.dart';

/// Topluluk paylaşım servisi — yetkili POST, oturum zincirinden bağlanır.
final communityShareServiceProvider = Provider<CommunityShareService>((ref) {
  final api = ref.read(apiClientProvider);
  final auth = ref.read(authControllerProvider);
  return CommunityShareService(
    post: (String path, Object body) =>
        auth.authorizedRequest((token) => api.postAuthed(path, token, body)),
  );
});

/// Kullanıcının kendi paylaşımları — 401 refresh akışı [AuthController] üzerinden.
final mySharesProvider = FutureProvider.autoDispose<List<MyShare>>((ref) async {
  final api = ref.read(apiClientProvider);
  final auth = ref.read(authControllerProvider);
  final res = await auth.authorizedRequest(
    (token) => api.getAuthed('/v1/me/sounds', token),
  );
  if (res.statusCode != 200) {
    throw ApiException(res.statusCode, res.body);
  }
  final list = jsonDecode(res.body) as List<dynamic>;
  return list
      .map((e) => MyShare.fromJson(e as Map<String, dynamic>))
      .toList(growable: false);
});
