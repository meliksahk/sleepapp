import 'dart:convert';

import '../storage/key_value_store.dart';
import 'envelope_log.dart';
import 'sleep_session_builder.dart';

/// Bitmiş gecenin zarfını (dB profili) ve taslağını KALICI saklar.
///
/// ## Neden var — gerçek bir veri kaybı düzeltmesi
///
/// Önceden zarf yalnızca BELLEKTE yaşıyordu (`SleepModeController._envelope`).
/// Kullanıcı geceyi bitirip uygulamayı kapatsa (veyar sistem öldürse) 5 saatlik
/// dB verisi SESSİZCE KAYBOLURDU. Kuyrukta draft (süre + olay sayısı) vardı ama
/// horlama kalibrasyonu için gereken dB profili yoktu. Bu sınıf o boşluğu kapatır.
class NightDataStore {
  NightDataStore(this._store);

  final KeyValueStore _store;

  static const String _envKey = 'night_envelope_csv';
  static const String _draftKey = 'night_last_draft';

  /// Kayıt bittikten sonra çağır — zarfı ve draftı diske yazar.
  Future<void> save({
    required EnvelopeLog envelope,
    required SleepSessionDraft draft,
  }) async {
    await _store.write(_envKey, envelope.toCsv());
    await _store.write(_draftKey, jsonEncode(draft.toJson()));
  }

  /// Saklanan zarf CSV'sini döner; yoksa null.
  Future<String?> loadEnvelopeCsv() async => _store.read(_envKey);

  /// Saklanan son draftı döner; yoksa null.
  Future<SleepSessionDraft?> loadLastDraft() async {
    final raw = await _store.read(_draftKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return SleepSessionDraft.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Zarfın var olup olmadığı (hızlı kontrol).
  Future<bool> hasEnvelope() async {
    final v = await _store.read(_envKey);
    return v != null && v.isNotEmpty;
  }
}
