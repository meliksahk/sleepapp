import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;

import 'package:shared_preferences/shared_preferences.dart';

import '../archetype_models.dart';

/// Arketip sonuçlarının CİHAZDAKİ kalıcı kaydı.
///
/// **NEDEN shared_preferences, NEDEN drift DEĞİL (CLAUDE.md §3.1):** kural
/// "yapısal veri drift, basit ayar prefs". Arketip sonucu tek küçük bir kayıt ve
/// geçmiş de kısa bir liste; sorgulanmıyor, ilişkisi yok, birleştirilmiyor. Bunun
/// için bir SQL şeması + migration açmak, taşıdığı veriden ağır bir bakım yükü
/// olurdu.
///
/// **NEDEN secure storage DEĞİL:** arketip sonucu hassas veri değil — kullanıcı
/// onu zaten sosyal medyada PAYLAŞMAK için üretiyor (viral kanca #1). Keychain
/// erişimi bedava değil ve burada koruduğu bir şey yok.
abstract class LocalArchetypeStore {
  Future<ArchetypeResult?> latest();
  Future<List<ArchetypeResult>> history();

  /// Sonucu kaydeder ve geçmişin başına ekler (yeniden eskiye).
  Future<void> save(ArchetypeResult result);

  Future<void> clear();
}

/// Üretim uygulaması — shared_preferences.
class PrefsArchetypeStore implements LocalArchetypeStore {
  PrefsArchetypeStore({Future<SharedPreferences> Function()? prefs})
      : _prefs = prefs ?? SharedPreferences.getInstance;

  final Future<SharedPreferences> Function() _prefs;

  static const String historyKey = 'archetype_history_v1';

  /// Geçmişte tutulan azami kayıt. Sınırsız bırakmak, testi her gün tekrar eden
  /// bir kullanıcıda prefs kaydını sessizce şişirirdi; 50 kayıt hem geçmiş
  /// ekranı için fazlasıyla yeterli hem de birkaç KB.
  static const int maxHistory = 50;

  @override
  Future<ArchetypeResult?> latest() async {
    final list = await history();
    return list.isEmpty ? null : list.first;
  }

  @override
  Future<List<ArchetypeResult>> history() async {
    final prefs = await _prefs();
    final raw = prefs.getString(historyKey);
    if (raw == null || raw.isEmpty) return const <ArchetypeResult>[];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return <ArchetypeResult>[
        for (final e in list) ArchetypeResult.fromJson(e as Map<String, dynamic>),
      ];
    } catch (e, st) {
      // Bozuk kayıt (elle kurcalanmış, yarım yazılmış, ESKİ ŞEMA): kullanıcıyı
      // patlatmak yerine "geçmiş yok" say. Kayıt bir sonraki testte üzerine yazılır.
      //
      // **NEDEN `FormatException` DEĞİL — ÖLÇÜLDÜ.** Başta yalnızca FormatException
      // yakalanıyordu ve yorumu "eski şema tolere edilir" diyordu; bu YANLIŞTI.
      // Geçerli JSON ama yanlış ŞEKİL olan kayıtlar (eksik alan, dizi yerine obje,
      // yanlış tipte `scores`) `TypeError` atıyor ve bu hata history() → latest()
      // → servis → ekran zincirinde yukarı sızıyordu. Yerel depo artık kanca #1'in
      // TEK doğruluk kaynağı olduğu için (sunucu yok) TEK bozuk kayıt özelliği o
      // cihazda KİLİTLİYORDU. Şema kayması ayrıca beklenen bir şey: fromJson zaten
      // `userId` için tolerans taşıyor.
      //
      // Geniş catch bilinçli ama SESSİZ DEĞİL: hata loglanıyor (CLAUDE.md §4).
      debugPrint('nocta.archetype: yerel geçmiş okunamadı, sıfırlanıyor: $e\n$st');
      return const <ArchetypeResult>[];
    }
  }

  @override
  Future<void> save(ArchetypeResult result) async {
    final prefs = await _prefs();
    final current = await history();
    final next = <ArchetypeResult>[result, ...current].take(maxHistory).toList();
    await prefs.setString(
      historyKey,
      jsonEncode(<Map<String, dynamic>>[for (final r in next) r.toJson()]),
    );
  }

  @override
  Future<void> clear() async {
    final prefs = await _prefs();
    await prefs.remove(historyKey);
  }
}

/// Test/mock — bellekte.
class InMemoryArchetypeStore implements LocalArchetypeStore {
  final List<ArchetypeResult> _items = <ArchetypeResult>[];

  @override
  Future<ArchetypeResult?> latest() async => _items.isEmpty ? null : _items.first;

  @override
  Future<List<ArchetypeResult>> history() async => List.unmodifiable(_items);

  @override
  Future<void> save(ArchetypeResult result) async => _items.insert(0, result);

  @override
  Future<void> clear() async => _items.clear();
}
