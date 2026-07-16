import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/core/audio_engine/dsp/mix_render.dart';
import 'package:nocta/features/content/content_models.dart';

/// `Soundscape.fromJson` — feed'in gerçek şekliyle.
///
/// NEDEN: model `engineParams`'ı TAMAMEN DÜŞÜRÜYORDU ("motor gelince eklenecek"),
/// yani sunucuda kurulan tarif zinciri (#123–#125) istemcinin modeline hiç
/// ulaşmıyordu. Bu testler tarifin geldiğini ve bozuk tarifin KAYDI DÜŞÜRMEDİĞİNİ
/// sabitler.
void main() {
  Map<String, dynamic> feedJson({Object? engineParams}) => jsonDecode(jsonEncode({
        'id': 'id-1',
        'slug': 'deep-ocean-drift',
        'titleI18n': {'en': 'Deep Ocean Drift'},
        'archetypeAffinity': ['deep-ocean'],
        'version': 1,
        'engineParams': ?engineParams,
      })) as Map<String, dynamic>;

  test('feed tarifi modele ULAŞIR (eskiden düşürülüyordu)', () {
    final s = Soundscape.fromJson(feedJson(engineParams: {
      'schemaVersion': 1,
      'layers': [
        {'id': 'base', 'type': 'brown', 'gain': 0.7},
      ],
    }));

    expect(s.mixSpec, isNotNull);
    expect(s.mixSpec!.layers.single.type, NoiseType.brown);
    expect(s.mixSpec!.layers.single.gain, 0.7);
  });

  test('tarifi OLMAYAN kayıt yine de listelenir (taslak/eski kayıt)', () {
    // Tüm kaydı düşürmek kütüphaneyi sessizce boşaltırdı; başlık/affinity geçerli.
    final s = Soundscape.fromJson(feedJson());
    expect(s.mixSpec, isNull);
    expect(s.title('en'), 'Deep Ocean Drift');
    expect(s.affinityLabel(), isNotEmpty);
  });

  test('BOZUK tarif kaydı düşürmez, yalnızca çalınamaz kılar', () {
    final s = Soundscape.fromJson(feedJson(engineParams: {
      'schemaVersion': 1,
      'layers': [
        {'id': 'a', 'type': 'green', 'gain': 0.5},
      ],
    }));
    expect(s.mixSpec, isNull);
    expect(s.slug, 'deep-ocean-drift');
  });

  test('BİLİNMEYEN şema sürümü ÇÖKERTMEZ (docs/04 §79)', () {
    // Uygulama mağazada yıllarca yaşar; bir gün v2 tarif görebilir.
    final s = Soundscape.fromJson(feedJson(engineParams: {
      'schemaVersion': 99,
      'layers': [
        {'id': 'a', 'type': 'pink', 'gain': 0.5},
      ],
    }));
    expect(s.mixSpec, isNull);
    expect(s.title('en'), 'Deep Ocean Drift');
  });

  test('boş tarif (taslağın doğduğu hâl) → mixSpec null', () {
    final s = Soundscape.fromJson(feedJson(engineParams: <String, dynamic>{}));
    expect(s.mixSpec, isNull);
  });
}
