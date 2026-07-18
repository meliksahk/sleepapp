import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../domain/archetype_matrix.dart';

/// Gömülü arketip matrisinin asset yolu. Üretilen dosya — bkz.
/// `tooling/gen-archetype-matrix.mjs` ve drift kapısı.
const String archetypeMatrixAsset = 'assets/archetype/matrix.json';

/// Matrisi asset'ten okur.
///
/// **ÖNBELLEK:** matris uygulama ömrü boyunca değişmez (build'e gömülü); her
/// ekran açılışında 30KB JSON'u yeniden ayrıştırmak boşuna iş. Ayrıştırma bir
/// kez yapılır ve `Future` paylaşılır — eşzamanlı iki çağrı da tek okuma yapar.
class ArchetypeMatrixSource {
  ArchetypeMatrixSource({Future<String> Function(String key)? loadAsset})
      : _loadAsset = loadAsset ?? rootBundle.loadString;

  final Future<String> Function(String key) _loadAsset;

  Future<ArchetypeMatrix>? _pending;

  Future<ArchetypeMatrix> load() {
    return _pending ??= _read();
  }

  Future<ArchetypeMatrix> _read() async {
    try {
      final raw = await _loadAsset(archetypeMatrixAsset);
      return ArchetypeMatrix.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      // Başarısız Future'ı ÖNBELLEKTE BIRAKMA: bir kerelik bir hata (ör. asset
      // henüz hazır değil) kalıcı olurdu ve kullanıcı uygulamayı kapatana kadar
      // testi bir daha açamazdı.
      _pending = null;
      // Boş catch YASAK (CLAUDE.md §4): hata yutulmuyor, bağlam eklenip iletiliyor.
      throw StateError(
        'Arketip matrisi okunamadı ($archetypeMatrixAsset): $e — '
        'asset pubspec.yaml\'da bildirilmiş mi? (pnpm gen:archetype)',
      );
    }
  }
}
