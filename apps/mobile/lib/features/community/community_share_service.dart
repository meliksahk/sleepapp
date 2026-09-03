import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../auth/auth_controller.dart';

/// Paylaşımın sonucu — `bool` DEĞİL: her başarısızlık kullanıcının
/// DÜZELTEBİLECEĞİ ayrı bir nedendir; hepsini tek "olmadı"ya gömmek,
/// kökünü sormayı imkânsız kılar.
enum CommunityShareFailure {
  /// Ağ kapalı (prod ağ katmanı) ya da sunucu erişilemedi.
  offline,

  /// Eşzamanlı bekleyen paylaşım tavanı dolu (sunucu 422).
  pendingLimit,

  /// Başlık/süre meta geçersiz (400) — sürgü/alan düzeltilip tekrar denenebilir.
  invalidMeta,

  /// Dosya depoya yüklenemedi ya da sunucu HEAD doğrulamasını geçemedi (422).
  uploadFailed,

  /// Dosya süresi cihazda okunamadı — sunucu süreyi ZORUNLU kılar; uydurmuyoruz.
  durationUnknown,

  /// Dosya artık diskte yok.
  fileGone,

  /// Oturum yenilenemedi (401 sonrası refresh de patladı).
  unauthorized,

  /// Beklenmeyen sunucu yanıtı — ayrı nedendir çünkü kullanıcıya söylenecek
  /// tek şey "tekrar dene"dir; yukarıdakilerin hiçbiri değil.
  unknown,
}

sealed class CommunityShareOutcome {
  const CommunityShareOutcome();
}

class CommunityShared extends CommunityShareOutcome {
  const CommunityShared(this.soundId);
  final String soundId;
}

class CommunityShareRejected extends CommunityShareOutcome {
  const CommunityShareRejected(this.reason);
  final CommunityShareFailure reason;
}

/// Topluluk paylaşımı — kütüphanedeki yerel dosyayı moderasyona gönderir.
///
/// AKIŞ (üç adım, hiçbiri atlanamaz):
///  1. `POST /v1/me/sounds` → slot + presigned PUT URL
///  2. dosya baytları DOĞRUDAN MinIO'ya PUT edilir (presigned URL'de imza var;
///     Authorization başlığı GEREKMEZ ve eklenmez — imzalı URL'e karışan ek
///     başlık imzayı bozar)
///  3. `POST /v1/me/sounds/:id/uploaded` → sunucu HEAD ile doğrular
///
/// Neden baytlar API'den geçmez: NestJS gövde limiti 64 KB'dır (DoS sertleşmesi)
/// ve proxy'lemek gereksiz sunucu işidir. Presigned PUT tam bu deseni çözer.
typedef AuthedPost = Future<http.Response> Function(String path, Object body);

/// Yetkili POST soyutlaması — [AuthController.authorizedRequest] ile provider
/// düzeyinde bağlanır; servis birim testlerinde gerçek oturum zinciri kurulmaz.
class CommunityShareService {
  CommunityShareService({
    required AuthedPost post,
    http.Client? transport,
  })  : _authedPost = post,
        _httpClient = transport;

  final AuthedPost _authedPost;

  /// null → [http.Client] tembel oluşturulur (testler sahte enjekte eder).
  http.Client? _httpClient;
  http.Client get _http => _httpClient ??= http.Client();

  Future<CommunityShareOutcome> share({
    required String filePath,
    required String title,
    required int sizeBytes,
    required int durationSeconds,
  }) async {
    // ── 1. Slot ──
    final http.Response created;
    try {
      created = await _authedPost('/v1/me/sounds', {
          'title': title,
          'durationSeconds': durationSeconds,
          // Boyutu bildirmek şart değil ama sunucunun tavanı ÖNCEDEN bilmesi
          // yararlıdır; presigned PUT yine de tek doğruluk kaynağıdır.
          'bytes': sizeBytes,
        });
    } on StateError {
      return const CommunityShareRejected(CommunityShareFailure.offline);
    }
    switch (created.statusCode) {
      case 201:
        break;
      case 422:
        return const CommunityShareRejected(CommunityShareFailure.pendingLimit);
      case 503: // NoctaApiClient.serviceUnavailableStatus ile aynı değer
        return const CommunityShareRejected(CommunityShareFailure.offline);
      case 400:
      case 401:
        return const CommunityShareRejected(CommunityShareFailure.invalidMeta);
      default:
        return const CommunityShareRejected(CommunityShareFailure.unknown);
    }
    final slot = jsonDecode(created.body) as Map<String, dynamic>;
    final id = slot['id'] as String?;
    final uploadUrl = slot['uploadUrl'] as String?;
    if (id == null || id.isEmpty || uploadUrl == null || uploadUrl.isEmpty) {
      return const CommunityShareRejected(CommunityShareFailure.unknown);
    }

    // ── 2. Dosyayı depoya PUT et (presigned; auth başlığı YOK) ──
    final Uint8List bytes;
    try {
      bytes = await File(filePath).readAsBytes();
    } on FileSystemException {
      return const CommunityShareRejected(CommunityShareFailure.fileGone);
    }
    if (bytes.isEmpty) {
      return const CommunityShareRejected(CommunityShareFailure.fileGone);
    }

    final http.Response put;
    try {
      put = await _http.put(Uri.parse(uploadUrl), body: bytes);
    } catch (_) {
      return const CommunityShareRejected(CommunityShareFailure.uploadFailed);
    }
    if (put.statusCode != 200) {
      return const CommunityShareRejected(CommunityShareFailure.uploadFailed);
    }

    // ── 3. Sunucu HEAD ile doğrular ──
    final http.Response done;
    try {
      done = await _authedPost('/v1/me/sounds/$id/uploaded', const {});
    } on StateError {
      return const CommunityShareRejected(CommunityShareFailure.offline);
    }
    if (done.statusCode != 200) {
      return CommunityShareRejected(
        done.statusCode == 422
            ? CommunityShareFailure.uploadFailed
            : CommunityShareFailure.unknown,
      );
    }
    return CommunityShared(id);
  }
}
