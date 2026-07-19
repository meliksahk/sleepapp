import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/features/content/content_models.dart';

/// Sunucu sözleşmesi → istemci modeli. Gerçek yanıt gövdeleri kullanılıyor
/// (curl çıktısından alındı) — uydurulmuş bir şekle karşı test yazmak,
/// sözleşmenin doğruluğunu değil kendi hayalimizi doğrular.
void main() {
  test('liste öğesi ayrıştırılır', () {
    final a = AudioAsset.fromJson(const <String, dynamic>{
      'id': '57b6ec43-3def-459b-ac64-50cf3f01e41e',
      'title': 'Pad + Fire (demo)',
      'genre': 'ambient',
      'mood': <dynamic>['calm', 'sleep'],
      'durationSeconds': 10,
      'license': 'self-produced',
      'source': 'NOCTA audio engine',
    });
    expect(a.id, '57b6ec43-3def-459b-ac64-50cf3f01e41e');
    expect(a.mood, <String>['calm', 'sleep']);
    expect(a.durationSeconds, 10);
    expect(a.license, 'self-produced');
  });

  test('mood alanı eksikse boş listeye düşer (çökmez)', () {
    final a = AudioAsset.fromJson(const <String, dynamic>{
      'id': 'x',
      'title': 'X',
      'genre': 'ambient',
      'durationSeconds': 5,
      'license': 'CC0',
      'source': 's',
    });
    expect(a.mood, isEmpty);
  });

  test('detay → çalınabilir AssetLayer', () {
    final d = AudioAssetDetail.fromJson(const <String, dynamic>{
      'asset': <String, dynamic>{
        'id': 'asset-1',
        'title': 'Pad + Fire (demo)',
        'genre': 'ambient',
        'mood': <dynamic>['calm'],
        'durationSeconds': 10,
        'license': 'self-produced',
        'source': 's',
      },
      'url': 'http://localhost:9000/audio-assets/demo/pad-fire-demo.wav?X-Amz-Signature=abc',
      'expiresInSeconds': 21600,
    });

    final layer = d.toLayer();
    expect(layer.id, 'asset-1');
    expect(layer.title, 'Pad + Fire (demo)');
    expect(layer.url, contains('X-Amz-Signature'));
    // Varsayılan kazanç DÜŞÜK: eklenen dosya çalan mix'in üstüne bindirmemeli.
    expect(layer.gain, lessThanOrEqualTo(0.3));
  });
}
