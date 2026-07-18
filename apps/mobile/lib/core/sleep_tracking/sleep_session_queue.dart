import 'dart:convert';

import '../storage/key_value_store.dart';
import 'sleep_session_builder.dart';

/// Çevrimdışı biten gecelerin **kayıp-önleyici kuyruğu** (#177).
///
/// ## Neden var
///
/// `recordSession` sunucuya yazamazsa (uçak modu / DND / bağlantı yok — sabah 06:00'da
/// EN YAYGIN durum) gece sunucu tarafında sessizce kaybolurdu (`sleep_mode_controller`
/// eski `catch` yalnızca hata gösteriyordu). Bir uyku app'inin gecesini kaybetmesi
/// gerçek ürün hatası. Burası draft'ı yerelde tutar; bağlantı gelince yüklenir.
///
/// ## Neden `KeyValueStore`, drift değil
///
/// Küçük bir JSON draft listesi için ilişkisel DB (drift/sqflite) ağır bağımlılık olurdu.
/// Var olan `KeyValueStore` (flutter_secure_storage) soyutlaması yeter; test in-memory,
/// üretim Keychain/Keystore. Draft ham ses/olay içermez (yalnızca sayı+zaman, §6) →
/// secure storage'da tutmak gizlilik açısından da güvenli.
///
/// **CANLI DRAIN ŞART (yoksa ölü kod):** kuyruğa yazıp hiç boşaltmayan kod işe yaramaz.
/// `drain` controller init'te ve her başarılı kayıttan sonra çağrılır (bkz.
/// `SleepModeController._drainQueue`).
class SleepSessionQueue {
  SleepSessionQueue(this._store, {this.maxEntries = 30});

  static const String _key = 'sleep_session_queue';

  final KeyValueStore _store;

  /// Taban dolmasın: en fazla bu kadar gece tutulur; aşılırsa en ESKİ düşer.
  /// 30 gece = ~1 ay çevrimdışı; bundan fazlası gerçekçi değil, sınırsız büyüme riski.
  final int maxEntries;

  Future<List<SleepSessionDraft>> _load() async {
    final raw = await _store.read(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => SleepSessionDraft.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Bozuk/eski format → tanımlı sıfırlama (nadirdir). Sessiz çökme yerine temiz
      // başlangıç; kaybedilen tek şey zaten okunamayan veridir.
      await _store.write(_key, '[]');
      return [];
    }
  }

  Future<void> _save(List<SleepSessionDraft> drafts) async {
    final trimmed =
        drafts.length > maxEntries ? drafts.sublist(drafts.length - maxEntries) : drafts;
    await _store.write(_key, jsonEncode(trimmed.map((d) => d.toJson()).toList()));
  }

  /// Bir geceyi kuyruğa alır (kayıt başarısız olduğunda).
  Future<void> enqueue(SleepSessionDraft draft) async {
    final drafts = await _load()..add(draft);
    await _save(drafts);
  }

  /// Kuyruktaki gece sayısı (test + teşhis).
  Future<int> pending() async => (await _load()).length;

  /// Kuyruğu boşaltmayı dener: her draft [upload] ile gönderilir. Başarılılar
  /// kuyruktan ÇIKAR; **ilk başarısızlıkta durur** — hâlâ çevrimdışıysak gerisini
  /// denemek boşuna, ve sıra korunur (en eski gece önce). Yüklenen sayısını döner.
  Future<int> drain(Future<void> Function(SleepSessionDraft) upload) async {
    final drafts = await _load();
    if (drafts.isEmpty) return 0;

    var uploaded = 0;
    var stop = false;
    final remaining = <SleepSessionDraft>[];
    for (final draft in drafts) {
      if (stop) {
        remaining.add(draft);
        continue;
      }
      try {
        await upload(draft);
        uploaded++;
      } catch (_) {
        remaining.add(draft);
        stop = true; // muhtemelen hâlâ çevrimdışı → kalanları koru, sonra dene
      }
    }
    await _save(remaining);
    return uploaded;
  }
}
