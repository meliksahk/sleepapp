import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/features/archetype/archetype_models.dart';
import 'package:nocta/features/archetype/data/local_archetype_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// REGRESYON KİLİTLERİ — üçü de adversaryal denetimde ÖLÇÜLEREK bulundu.
///
/// Bu iterasyonun tüm iddiası "arketip testi backend olmadan uçtan uca çalışır".
/// Denetim, iddianın iki noktada pratikte çürüdüğünü gösterdi (5 sn sessiz bekleme)
/// ve bir noktada tek bozuk kaydın özelliği cihazda kilitlediğini gösterdi.
void main() {
  ArchetypeResult result() => ArchetypeResult(
        userId: 'u1',
        archetypeSlug: 'deep-ocean',
        scores: const {'deep-ocean': 6},
        version: 1,
        createdAt: '2026-07-18T00:00:00.000Z',
      );

  group('yerel depo bozuk kayda DAYANIKLI', () {
    // Depo artık kanca #1'in TEK doğruluk kaynağı (sunucu yok). Tek bozuk kayıt
    // özelliği o cihazda kilitlerse kullanıcının yapabileceği hiçbir şey yok —
    // uygulamayı silmekten başka.
    Future<void> expectTolerated(String rawHistory, String label) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        PrefsArchetypeStore.historyKey: rawHistory,
      });
      final store = PrefsArchetypeStore();

      expect(
        await store.history(),
        isEmpty,
        reason: '$label → patlamak yerine "geçmiş yok" sayılmalı',
      );
      expect(await store.latest(), isNull, reason: '$label → latest() de patlamamalı');

      // KRİTİK: bozuk kayıt YAZMAYI da engellememeli, yoksa kullanıcı testi
      // yeniden yapsa bile sonucu kaydedilemezdi.
      await store.save(result());
      expect((await store.latest())?.archetypeSlug, 'deep-ocean');
    }

    test('bozuk JSON', () => expectTolerated('{bozuk', 'bozuk JSON'));

    test('ESKİ ŞEMA (geçerli JSON, eksik alan)', () {
      // Denetimin yakaladığı asıl vaka: eski kod yalnızca FormatException
      // yakalıyordu, bu kayıt TypeError atıyor ve ekrana kadar sızıyordu.
      return expectTolerated(
        '[{"archetypeSlug":"deep-ocean","version":1}]',
        'eski şema',
      );
    });

    test('dizi yerine obje', () => expectTolerated('{"a":1}', 'kök obje'));

    test('yanlış tipte scores', () {
      final bad = jsonEncode(<dynamic>[
        <String, dynamic>{
          'userId': 'u1',
          'archetypeSlug': 'deep-ocean',
          'scores': 'NAN',
          'version': 1,
          'createdAt': '2026-07-18T00:00:00.000Z',
        },
      ]);
      return expectTolerated(bad, 'yanlış tipli alan');
    });
  });

  test('bozuk kayıt SESSİZCE yutulmaz — hata loglanır (CLAUDE.md §4)', () {
    // Geniş catch bilinçli, ama teşhis edilemez olmamalı. debugPrint yakalanır.
    SharedPreferences.setMockInitialValues(<String, Object>{
      PrefsArchetypeStore.historyKey: '{bozuk',
    });
    final logs = <String>[];
    final original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) => logs.add(message ?? '');
    addTearDown(() => debugPrint = original);

    return PrefsArchetypeStore().history().then((_) {
      expect(
        logs.any((l) => l.contains('yerel geçmiş okunamadı')),
        isTrue,
        reason: 'bozuk kayıt sessizce yutulmamalı',
      );
    });
  });
}
