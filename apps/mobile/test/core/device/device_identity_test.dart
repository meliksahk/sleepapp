import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/core/device/device_identity.dart';
import 'package:nocta/core/storage/key_value_store.dart';

void main() {
  test('getOrCreate 32-karakter hex üretir ve kalıcı saklar', () async {
    final store = InMemoryKeyValueStore();
    final identity = DeviceIdentity(store, random: Random(42));

    final id = await identity.getOrCreate();
    expect(id, matches(RegExp(r'^[0-9a-f]{32}$')));
    expect(await store.read('nocta.device_id'), id); // kalıcı
  });

  test('ikinci getOrCreate aynı id\'yi döner (yeni üretmez)', () async {
    final store = InMemoryKeyValueStore();
    final identity = DeviceIdentity(store, random: Random(1));

    final first = await identity.getOrCreate();
    final second = await identity.getOrCreate();
    expect(second, first);
  });

  test('kayıtlı değer varsa onu döner', () async {
    final store = InMemoryKeyValueStore();
    await store.write('nocta.device_id', 'seeded-device-id');
    final identity = DeviceIdentity(store);

    expect(await identity.getOrCreate(), 'seeded-device-id');
  });
}
