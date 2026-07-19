import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../content_models.dart';

/// Gömülü içerik kütüphanesinin asset yolu. Üretilen dosya — bkz.
/// `tooling/gen-content-library.mjs` ve drift kapısı (`check-content-drift.mjs`).
const String contentLibraryAsset = 'assets/content/library.json';

/// Cihazın tanıdığı kütüphane biçim sürümü (üreticideki `LIBRARY_SCHEMA_VERSION`).
///
/// Uyuşmazsa asset REDDEDİLİR. Sebep: alan yapısı değişmişse "kısmen okumak"
/// sessizce eksik/yanlış bir kütüphane demektir; boş dönüp sunucuya güvenmek
/// dürüst olanıdır.
const int contentLibrarySchemaVersion = 1;

/// APK'ya gömülü kütüphane — soundscape'ler, preset'ler ve haftalık yayın.
///
/// ## NEDEN VAR
///
/// `content_controller.dart`'taki üç uç da KOŞULSUZ ağa gidiyordu ve yerel yedek
/// yoktu: `api.nocta.app` ayakta olmadığı için kurulan prod APK'da kütüphane
/// BOŞTU. CLAUDE.md §3.1 "offline-first" bunu yasaklıyor — mikser ve ses üretimi
/// internetsiz tam çalışmalı, ama çalacak bir tarif yoksa "tam çalışıyor" demek
/// anlamsızdı.
///
/// ## ÖNBELLEK
///
/// Kütüphane uygulama ömrü boyunca değişmez (build'e gömülü); her ekran
/// açılışında JSON'u yeniden ayrıştırmak boşuna iş. Ayrıştırma bir kez yapılır ve
/// `Future` paylaşılır — eşzamanlı iki çağrı da tek okuma yapar
/// (`ArchetypeMatrixSource` ile aynı desen).
class ContentLibrarySource {
  ContentLibrarySource({
    Future<String> Function(String key)? loadAsset,
    DateTime Function()? now,
  })  : _loadAsset = loadAsset ?? rootBundle.loadString,
        _now = now ?? DateTime.now;

  final Future<String> Function(String key) _loadAsset;
  final DateTime Function() _now;

  Future<ContentLibrary>? _pending;

  Future<ContentLibrary> load() => _pending ??= _read();

  Future<ContentLibrary> _read() async {
    try {
      final raw = await _loadAsset(contentLibraryAsset);
      return ContentLibrary.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
        now: _now,
      );
    } catch (e) {
      // Başarısız Future'ı ÖNBELLEKTE BIRAKMA: bir kerelik bir hata kalıcı
      // olurdu ve kullanıcı uygulamayı kapatana dek kütüphaneyi açamazdı.
      _pending = null;
      // Boş catch YASAK (CLAUDE.md §4): hata yutulmuyor, bağlam eklenip iletiliyor.
      throw StateError(
        'Gömülü içerik kütüphanesi okunamadı ($contentLibraryAsset): $e — '
        "asset pubspec.yaml'da bildirilmiş mi? (pnpm gen:content)",
      );
    }
  }
}

/// Ayrıştırılmış gömülü kütüphane.
class ContentLibrary {
  const ContentLibrary({required this.details, required this.weekly});

  /// Yayın sırasıyla soundscape detayları (soundscape + preset'ler).
  final List<SoundscapeDetail> details;

  /// Haftalık yayın; seed'de yoksa null.
  final WeeklyRelease? weekly;

  List<Soundscape> get soundscapes =>
      <Soundscape>[for (final d in details) d.soundscape];

  SoundscapeDetail? detail(String slug) {
    for (final d in details) {
      if (d.soundscape.slug == slug) return d;
    }
    return null;
  }

  factory ContentLibrary.fromJson(
    Map<String, dynamic> json, {
    required DateTime Function() now,
  }) {
    final schema = json['schemaVersion'];
    if (schema != contentLibrarySchemaVersion) {
      throw StateError(
        'Kütüphane biçim sürümü tanınmıyor: $schema '
        '(bu uygulama $contentLibrarySchemaVersion bekliyor).',
      );
    }

    // Sunucu yanıtıyla AYNI biçim → aynı `fromJson`. Ayrı bir ayrıştırıcı yazmak
    // ayrı bir hata yüzeyi olurdu (ör. sunucuda düzeltilen bir kenar durumu
    // burada düzeltilmeden kalırdı).
    final details = <SoundscapeDetail>[
      for (final e in json['soundscapes'] as List<dynamic>)
        SoundscapeDetail.fromJson(e as Map<String, dynamic>),
    ];

    final weeklyJson = json['weekly'] as Map<String, dynamic>?;
    WeeklyRelease? weekly;
    if (weeklyJson != null) {
      final bySlug = <String, Soundscape>{
        for (final d in details) d.soundscape.slug: d.soundscape,
      };
      final items = <Soundscape>[
        for (final slug in weeklyJson['soundscapeSlugs'] as List<dynamic>)
          if (bySlug[slug as String] != null) bySlug[slug]!,
      ];
      weekly = WeeklyRelease(
        // `weekStart` asset'te YOK — bilerek. Seed'de bu alan
        // `date_trunc('week', now())::date`, yani bir tarih değil bir KURAL:
        // "içinde bulunulan haftanın pazartesisi". Üretim anında dondurulsaydı
        // (a) drift kapısı her hafta kırmızı yanardı, (b) APK'daki yayın
        // kurulumdan haftalar sonra "geçmiş hafta" görünürdü. Kural burada,
        // okuma anında uygulanır.
        weekStart: _mondayOfCurrentWeek(now()),
        notes: weeklyJson['notes'] as String?,
        soundscapes: items,
      );
    }

    return ContentLibrary(details: details, weekly: weekly);
  }
}

/// İçinde bulunulan haftanın pazartesisi, `YYYY-MM-DD` (sunucu sözleşmesi:
/// ISO tarih). Postgres'in `date_trunc('week', ...)` davranışıyla aynı — hafta
/// PAZARTESİ başlar.
///
/// **Yerel gün kullanılır, UTC değil:** kullanıcı "bu hafta"yı kendi takviminde
/// yaşar; gece yarısı UTC'ye göre hesaplamak, doğu saat dilimlerinde pazartesi
/// sabahı hâlâ "geçen hafta" gösterirdi.
String _mondayOfCurrentWeek(DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final monday = today.subtract(Duration(days: today.weekday - DateTime.monday));
  final m = monday.month.toString().padLeft(2, '0');
  final d = monday.day.toString().padLeft(2, '0');
  return '${monday.year.toString().padLeft(4, '0')}-$m-$d';
}
