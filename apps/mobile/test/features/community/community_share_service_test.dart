import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nocta/features/community/community_share_service.dart';

/// Paylaşım servisinin ÜÇ adımı ve her başarısızlık dalı — tamamen cihazsız.
///
/// [MockClient] HEM API hem MinIO isteklerini taşır: host'a bakarak ayırır.
/// Yetkili POST, sahte bir [authedPost] ile beslenir (gerçek oturum zinciri
/// kurmadan 401/503 senaryoları dahil test edilebilir).
void main() {
  const minioUrl =
      'https://minio.test/audio-assets/community/u1/slot-1?sig=abc';
  final file = File(
    '${Directory.systemTemp.path}/community-share-test-${DateTime.now().microsecondsSinceEpoch}.wav',
  );

  setUpAll(() async {
    await file.writeAsBytes(List<int>.generate(2048, (i) => i % 256));
  });

  tearDownAll(() async {
    if (await file.exists()) await file.delete();
  });

  // (apiStatus, apiBody) → servis; MinIO PUT her zaman 200 döner.
  CommunityShareService buildWithApi({
    required int status,
    Object? body,
    void Function(http.Response sent)? onCreateSent,
    int minioStatus = 200,
    List<http.MultipartRequest>? unused,
  }) {
    final transport = MockClient((req) async {
      if (req.url.host == 'minio.test') {
        return http.Response('', minioStatus);
      }
      // API yanıtı
      final payload = body == null ? '' : jsonEncode(body);
      final res = http.Response(payload, status);
      onCreateSent?.call(res);
      return res;
    });

    return CommunityShareService(
      post: (String path, _) async {
        expect(path, '/v1/me/sounds');
        return http.Response(
          jsonEncode({
            'id': 'slot-1',
            'uploadUrl': minioUrl,
            'expiresIn': 900,
          }),
          status == 201 ? 201 : status,
        );
      },
      transport: transport,
    );
  }

  test('MUTLU YOL: Shared döner ve PUT doğru URL’e gider', () async {
    String? putPath;
    final transport = MockClient((req) async {
      if (req.url.host == 'minio.test') {
        putPath = req.url.toString();
        expect(req.bodyBytes.length, 2048);
        return http.Response('', 200);
      }
      return http.Response(
        jsonEncode({'id': 'slot-1', 'uploadUrl': minioUrl, 'expiresIn': 900}),
        201,
      );
    });
    final svc = CommunityShareService(
      post: (path, _) async =>
          path.endsWith('/uploaded')
              ? http.Response('{}', 200)
              : http.Response(
                  jsonEncode({'id': 'slot-1', 'uploadUrl': minioUrl, 'expiresIn': 900}),
                  201,
                ),
      transport: transport,
    );

    final out = await svc.share(
      filePath: file.path,
      title: 'Deniz',
      sizeBytes: 2048,
      durationSeconds: 60,
    );

    expect(out, isA<CommunityShared>());
    expect((out as CommunityShared).soundId, 'slot-1');
    // Anahtar yol parçası olarak gider (imza sorgu dizgisinde); bucket + key
    // ikisi de URL'de görünür.
    expect(putPath, contains('/audio-assets/community/u1/slot-1'));
    expect(putPath, contains('sig='));
  });

  test('422 → pendingLimit; 400 → invalidMeta; 503 → offline', () async {
    final cases = <int, CommunityShareFailure>{
      422: CommunityShareFailure.pendingLimit,
      400: CommunityShareFailure.invalidMeta,
      503: CommunityShareFailure.offline,
    };
    for (final entry in cases.entries) {
      final svc = buildWithApi(status: entry.key, body: {'message': 'x'});
      final out = await svc.share(
        filePath: file.path,
        title: 'x',
        sizeBytes: 10,
        durationSeconds: 30,
      );
      expect(
        out,
        isA<CommunityShareRejected>().having(
          (r) => r.reason,
          'reason',
          entry.value,
        ),
        reason: '${entry.key} → ${entry.value} olmalı',
      );
    }
  });

  test('MinIO PUT 200 DÖNMEZSE uploadFailed (uploaded çağrılmaz)', () async {
    var uploadedCalled = false;
    final svc = CommunityShareService(
      post: (String path, _) async {
        if (path.endsWith('/uploaded')) {
          uploadedCalled = true;
          return http.Response('{}', 200);
        }
        return http.Response(
          jsonEncode({'id': 'slot-1', 'uploadUrl': minioUrl, 'expiresIn': 900}),
          201,
        );
      },
      transport: MockClient((req) async =>
          req.url.host == 'minio.test' ? http.Response('', 500) : http.Response('', 200)),
    );

    final out = await svc.share(
      filePath: file.path,
      title: 'x',
      sizeBytes: 10,
      durationSeconds: 30,
    );

    expect(
      out,
      isA<CommunityShareRejected>()
          .having((r) => r.reason, 'reason', CommunityShareFailure.uploadFailed),
    );
    expect(uploadedCalled, isFalse,
        reason: 'PUT başarısızken "yüklendi" bildirimi YAPILMAZ');
  });

  test('dosya YOK → fileGone (PUT hiç denenmez)', () async {
    var touched = false;
    final svc = CommunityShareService(
      post: (_, _) async => http.Response(
        jsonEncode({'id': 's', 'uploadUrl': minioUrl, 'expiresIn': 900}),
        201,
      ),
      transport: MockClient((req) async {
        if (req.url.host == 'minio.test') touched = true;
        return http.Response('', 200);
      }),
    );

    final out = await svc.share(
      filePath: r'C:\no-such-dir\x.wav',
      title: 'x',
      sizeBytes: 1,
      durationSeconds: 5,
    );

    expect(
      out,
      isA<CommunityShareRejected>()
          .having((r) => r.reason, 'reason', CommunityShareFailure.fileGone),
    );
    expect(touched, isFalse);
  });
}
