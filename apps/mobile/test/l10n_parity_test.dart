import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// **EN ↔ TR anahtar paritesi kapısı** (CLAUDE.md §4: "EN (birincil), TR").
///
/// ## Neden bu test var
///
/// i18n kuralı "tüm kullanıcı metinleri baştan itibaren i18n dosyalarında" ve
/// başlangıç dilleri **EN + TR**. TR arb dosyası uzun süre HİÇ YOKTU; eklendi.
/// Ama asıl risk eklemek değil, **eşzamanlı tutmak**: biri EN'e yeni bir metin
/// ekleyip TR'yi unutursa, Türkçe cihazda o metin sessizce İngilizce görünür —
/// kimse fark etmez. gen-l10n bunu yalnızca UYARIR (build'i kırmaz), uyarı da
/// kaybolur.
///
/// Bu test iki arb'ın anahtar kümesini birebir eşleştirir: EN'e eklenen her
/// anahtar TR'de de olmak ZORUNDA, tersi de. Eksik çeviri artık KIRMIZI yanar.
///
/// **Sınır (dürüstlük):** bu test anahtarların VARLIĞINI kilitler, çeviri
/// KALİTESİNİ değil. "merhaba" yerine "hello" yazılmış bir TR değeri buradan
/// geçer — onu ancak insan yakalar. Yine de sessiz İngilizce sızıntısını kapatır.
void main() {
  Set<String> messageKeys(String path) {
    final file = File(path);
    expect(file.existsSync(), isTrue, reason: '$path bulunamadı');
    final map = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    // `@@locale` ve `@key` (açıklama) meta anahtarları mesaj değildir.
    return map.keys.where((k) => !k.startsWith('@')).toSet();
  }

  test('ÇEKİRDEK: EN ve TR aynı mesaj anahtarlarını taşır', () {
    final en = messageKeys('lib/l10n/app_en.arb');
    final tr = messageKeys('lib/l10n/app_tr.arb');

    final missingInTr = en.difference(tr);
    final extraInTr = tr.difference(en);

    expect(
      missingInTr,
      isEmpty,
      reason: 'TR\'de EKSİK (Türkçe cihazda İngilizce sızar): $missingInTr',
    );
    expect(
      extraInTr,
      isEmpty,
      reason: 'TR\'de FAZLA (EN\'den silinmiş ya da yazım hatası): $extraInTr',
    );
  });

  test('her iki arb da doğru @@locale bildirir', () {
    final en = jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
        as Map<String, dynamic>;
    final tr = jsonDecode(File('lib/l10n/app_tr.arb').readAsStringSync())
        as Map<String, dynamic>;
    expect(en['@@locale'], 'en');
    expect(tr['@@locale'], 'tr');
  });

  test('ÇEKİRDEK: sağlık iddiası feragatleri TR\'de KORUNMUŞ (CLAUDE.md §1.1)', () {
    // Kart ve rapor paylaşılıyor; "sağlık skoru değil" feragati çeviride
    // düşerse §1.1 ihlali paylaşılan artefakta taşınır.
    final tr = jsonDecode(File('lib/l10n/app_tr.arb').readAsStringSync())
        as Map<String, dynamic>;
    expect(tr['reportCardDisclaimer'], contains('Sağlık skoru değil'));
    expect(tr['nightReportCalmDisclaimer'], contains('sağlık skoru değil'));

    // Yasak sağlık iddiaları TR metinlerine sızmamış olmalı.
    final allTrText = tr.entries
        .where((e) => !e.key.startsWith('@'))
        .map((e) => e.value.toString().toLowerCase())
        .join(' ');
    for (final banned in ['tedavi', 'iyileştir', 'şifa']) {
      expect(allTrText, isNot(contains(banned)),
          reason: 'yasak sağlık iddiası TR metninde: $banned');
    }
  });
}
