import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/core/sleep_tracking/sleep_session_builder.dart';
import 'package:nocta/core/sleep_tracking/sleep_session_queue.dart';
import 'package:nocta/core/storage/key_value_store.dart';

/// Çevrimdışı gece kuyruğu (#177) — kayıp-önleme mantığı. En pahalı hata "gece
/// SESSİZCE kaybolur": testlerin ağırlığı orada (başarısız→kuyrukta, drain→boşalır).
SleepSessionDraft draft(int min) => SleepSessionDraft(
      startedAt: DateTime.utc(2026, 7, 18, 0, 0),
      endedAt: DateTime.utc(2026, 7, 18, 0, min),
      movementEvents: min,
      soundEvents: min * 2,
    );

void main() {
  late InMemoryKeyValueStore store;
  late SleepSessionQueue queue;

  setUp(() {
    store = InMemoryKeyValueStore();
    queue = SleepSessionQueue(store);
  });

  test('SleepSessionDraft JSON round-trip kayıpsız (gövde birebir)', () {
    final d = draft(42);
    final back = SleepSessionDraft.fromJson(d.toJson());
    expect(back.toJson(), d.toJson());
  });

  test('ÇEKİRDEK: enqueue kuyruğa alır, pending sayar', () async {
    expect(await queue.pending(), 0);
    await queue.enqueue(draft(1));
    await queue.enqueue(draft(2));
    expect(await queue.pending(), 2);
  });

  test('ÇEKİRDEK: drain başarılıysa kuyruk BOŞALIR', () async {
    await queue.enqueue(draft(1));
    await queue.enqueue(draft(2));
    final uploaded = <SleepSessionDraft>[];
    final n = await queue.drain((d) async => uploaded.add(d));
    expect(n, 2);
    expect(uploaded.length, 2);
    expect(await queue.pending(), 0);
  });

  test('ÇEKİRDEK: drain başarısızsa gece KUYRUKTA KALIR (kaybolmaz)', () async {
    await queue.enqueue(draft(1));
    final n = await queue.drain((d) async => throw Exception('çevrimdışı'));
    expect(n, 0);
    expect(await queue.pending(), 1); // gece korundu — asıl mesele bu
  });

  test('drain İLK başarısızlıkta durur, sıra korunur (en eski önce)', () async {
    await queue.enqueue(draft(1));
    await queue.enqueue(draft(2));
    await queue.enqueue(draft(3));
    var call = 0;
    // 1. başarılı, 2. başarısız → 3. hiç denenmez (hâlâ çevrimdışı varsayımı).
    final n = await queue.drain((d) async {
      call++;
      if (call == 2) throw Exception('koptu');
    });
    expect(n, 1);
    expect(call, 2); // 3. denenmedi
    expect(await queue.pending(), 2); // 2 ve 3 korundu
  });

  test('maxEntries aşılırsa en ESKİ düşer (taban sınırsız büyümez)', () async {
    final q = SleepSessionQueue(store, maxEntries: 2);
    await q.enqueue(draft(1));
    await q.enqueue(draft(2));
    await q.enqueue(draft(3)); // 1 düşmeli
    expect(await q.pending(), 2);
    // Kalanların en yenisi 3 olmalı: drain sırasına bak.
    final drained = <int>[];
    await q.drain((d) async => drained.add(d.movementEvents));
    expect(drained, [2, 3]);
  });

  test('bozuk veri → tanımlı sıfırlama (sessiz çökme yok)', () async {
    await store.write('sleep_session_queue', 'çöp{[');
    expect(await queue.pending(), 0);
  });
}
