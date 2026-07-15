import 'dart:math';
import '../storage/key_value_store.dart';

/// Anonim, cihaz-kapsamlı stabil kimlik (docs/04 M0). İlk açılışta üretilip
/// kalıcı saklanır; sonraki açılışlarda aynı değer döner. Rastgeledir → PII
/// değildir; sunucuya yalnızca anonim cihaz kaydı (fingerprint) olarak gider,
/// mikrofon/kişisel veri asla (CLAUDE.md §6).
class DeviceIdentity {
  DeviceIdentity(this._store, {Random? random}) : _random = random ?? Random.secure();

  static const _key = 'nocta.device_id';
  final KeyValueStore _store;
  final Random _random;

  /// Kayıtlı device-id'yi döner; yoksa üretip kalıcı saklar (get-or-create).
  Future<String> getOrCreate() async {
    final existing = await _store.read(_key);
    if (existing != null && existing.isNotEmpty) return existing;
    final id = _generate();
    await _store.write(_key, id);
    return id;
  }

  /// 16 rastgele bayt → 32 karakter hex. uuid bağımlılığı gerektirmez.
  String _generate() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
