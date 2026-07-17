import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/core/sleep_tracking/mic_source.dart';
import 'package:nocta/core/share/sharer.dart';
import 'package:nocta/core/sleep_tracking/night_service.dart';
import 'package:nocta/core/sleep_tracking/sleep_recorder.dart';
import 'package:nocta/core/sleep_tracking/sleep_session_builder.dart';
import 'package:nocta/features/sleep/presentation/sleep_mode_screen.dart';
import 'package:nocta/features/sleep/sleep_controller.dart';
import 'package:nocta/features/sleep/sleep_models.dart';
import 'package:nocta/features/sleep/sleep_mode_controller.dart';
import 'package:nocta/l10n/app_localizations.dart';

/// Uyku modu ekranı — kullanıcının mikrofona ULAŞTIĞI yer.
///
/// #128–#132'de uyku takibi mantığı yazıldı, test edildi, yeşil geçti — ve kullanıcı
/// ona hiç ulaşamadı. Bu ekran o kapı; testler de kapının gerçekten açıldığını
/// kanıtlıyor.
class _RecordingSharer implements Sharer {
  ShareContent? last;
  @override
  Future<void> share(ShareContent content) async => last = content;
}

class _FakeSleep implements SleepController {
  final List<SleepSessionDraft> saved = [];
  Object? throwOnSave;

  @override
  Future<SleepSession> recordSession(SleepSessionDraft draft) async {
    if (throwOnSave != null) throw throwOnSave!;
    saved.add(draft);
    return SleepSession(
      id: 's1',
      startedAt: draft.startedAt.toIso8601String(),
      endedAt: draft.endedAt.toIso8601String(),
      nightDate: '2026-07-17',
      durationMinutes: draft.duration.inMinutes,
      movementEvents: draft.movementEvents,
      soundEvents: draft.soundEvents,
    );
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  Float32List frame(double a, {int n = 256}) {
    final f = Float32List(n);
    for (var i = 0; i < n; i++) {
      f[i] = i.isEven ? a : -a;
    }
    return f;
  }

  List<Float32List> night({int events = 2}) {
    final out = <Float32List>[];
    out.addAll(List.generate(40, (_) => frame(0.0001)));
    for (var i = 0; i < events; i++) {
      out.addAll(List.generate(5, (_) => frame(0.5)));
      out.addAll(List.generate(30, (_) => frame(0.0001)));
    }
    return out;
  }

  /// `pumpAndSettle` TEK BAŞINA YETMEZ: başlat/bitir zincirleri gerçek async
  /// (akış aboneliği, kayıt) ve mikrotask'ları ancak pump'lar arasında boşalır.
  /// Tek settle ile iddia, `recordSession` hiç çağrılmadan koşuyordu.
  Future<void> settle(WidgetTester t) async {
    for (var i = 0; i < 5; i++) {
      await t.pump(const Duration(milliseconds: 20));
    }
    await t.pumpAndSettle();
  }

  late FakeNightService service;
  late _RecordingSharer sharer;

  Future<SleepModeController> pump(
    WidgetTester t, {
    bool permission = true,
    bool serviceCanStart = true,
    bool logEnvelope = false,
    _FakeSleep? sleep,
    List<Float32List>? frames,
    FakeMicSource? mic,
  }) async {
    service = FakeNightService(canStart: serviceCanStart);
    sharer = _RecordingSharer();
    final controller = SleepModeController(
      recorder: SleepRecorder(
        mic: mic ?? FakeMicSource(frames ?? night(), permission: permission),
        logEnvelope: logEnvelope,
        now: () => DateTime.utc(2026, 7, 17, 23),
      ),
      sleep: sleep ?? _FakeSleep(),
      nightService: service,
      sharer: sharer,
    );
    await t.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: SleepModeScreen(controller: controller),
      ),
    );
    await t.pumpAndSettle();
    return controller;
  }

  testWidgets('ÇEKİRDEK: gizlilik notu mikrofon AÇILMADAN ÖNCE görünür', (t) async {
    await pump(t);

    // Kullanıcı izni verirken ne olduğunu BİLMELİ. Bunu ayarlara gömmek, iznin
    // bilinçli olmasını engellerdi (CLAUDE.md §6'nın kullanıcıya söylenmiş hali).
    expect(find.byKey(const Key('sleep-privacy')), findsOneWidget);
    expect(
      find.textContaining('never leaves'),
      findsOneWidget,
      reason: 'ham sesin cihazdan çıkmadığı AÇIKÇA yazmalı',
    );
  });

  testWidgets('izin reddedilirse HATA gibi gösterilmez, kayıt başlamaz', (t) async {
    final c = await pump(t, permission: false);

    await t.tap(find.byKey(const Key('sleep-toggle')));
    await t.pumpAndSettle();

    expect(find.byKey(const Key('sleep-permission-denied')), findsOneWidget);
    expect(c.state.isRecording, isFalse);
    // "Bir şeyler ters gitti" DEĞİL: kullanıcı bilinçli bir seçim yaptı.
    expect(c.state.error, isNull);
  });

  testWidgets('ÇEKİRDEK: başlat → kayıt sürüyor, geçen süre ve sayaç görünür', (t) async {
    final c = await pump(t);

    await t.tap(find.byKey(const Key('sleep-toggle')));
    await t.pumpAndSettle();

    expect(c.state.isRecording, isTrue);
    expect(find.byKey(const Key('sleep-elapsed')), findsOneWidget);
    // Canlı sayaç: gece kalkan kullanıcı "çalışıyor mu?" sorusunun cevabını görür.
    expect(find.byKey(const Key('sleep-event-count')), findsOneWidget);
  });

  testWidgets('ÇEKİRDEK: bitir → oturum SUNUCUYA yazılır (ölü kod artık canlı)', (t) async {
    final sleep = _FakeSleep();
    await pump(t, sleep: sleep);

    await t.tap(find.byKey(const Key('sleep-toggle')));
    await settle(t);
    await t.tap(find.byKey(const Key('sleep-toggle')));
    await settle(t);

    // `recordSession`ın #131'den beri ilk gerçek çağrısı.
    expect(sleep.saved, hasLength(1));
    expect(find.byKey(const Key('sleep-saved')), findsOneWidget);
  });

  testWidgets('ÇEKİRDEK: sunucuya giden gövdede HAM SES YOK (CLAUDE.md §6)', (t) async {
    final sleep = _FakeSleep();
    await pump(t, sleep: sleep);

    await t.tap(find.byKey(const Key('sleep-toggle')));
    await settle(t);
    await t.tap(find.byKey(const Key('sleep-toggle')));
    await settle(t);

    final body = sleep.saved.single.toJson();
    // Gövde YALNIZCA: zaman + iki sayı. Ses/örnek/frame taşıyan hiçbir alan yok.
    expect(body.keys.toSet(), {'startedAt', 'endedAt', 'movementEvents', 'soundEvents'});
    expect(body.values.whereType<List<dynamic>>(), isEmpty, reason: 'dizi = ham veri şüphesi');
  });

  testWidgets('sunucu hatası geceyi YOK SAYMAZ (özet yine görünür)', (t) async {
    final sleep = _FakeSleep()..throwOnSave = Exception('ağ yok');
    await pump(t, sleep: sleep);

    await t.tap(find.byKey(const Key('sleep-toggle')));
    await settle(t);
    await t.tap(find.byKey(const Key('sleep-toggle')));
    await settle(t);

    // Gece geçti, veri cihazda üretildi: sunucuya yazılamaması onu yok saymaz.
    expect(find.byKey(const Key('sleep-saved')), findsOneWidget);
    expect(find.byKey(const Key('sleep-save-failed')), findsOneWidget);
  });

  testWidgets('ÇEKİRDEK: başlat → foreground SERVİS de başlar (gece hayatta kalsın)', (t) async {
    // Android 14+ arka planda mikrofonu foreground service olmadan ÖLDÜRÜR.
    // Servis başlamazsa kullanıcı "dinliyorum" ekranını görür ve sabah BOŞ raporla
    // uyanır — yarım çalışan gece takibi hiç çalışmayandan beter.
    await pump(t);

    await t.tap(find.byKey(const Key('sleep-toggle')));
    await settle(t);

    expect(service.started, isTrue);
    expect(service.startCalls, 1);
  });

  testWidgets('ÇEKİRDEK: SERVİS başlatılamazsa KAYIT DA başlamaz', (t) async {
    final mic = FakeMicSource(night());
    final c = await pump(t, serviceCanStart: false, mic: mic);

    await t.tap(find.byKey(const Key('sleep-toggle')));
    await settle(t);

    expect(c.state.isRecording, isFalse, reason: 'kayıt başlamamalı');
    expect(find.byKey(const Key('sleep-service-failed')), findsOneWidget);
    // Mikrofon da BIRAKILMALI: boşuna açık kalması pil ve gizlilik sorunu.
    expect(mic.stopped, isTrue, reason: 'mikrofon bırakılmalı');
  });

  testWidgets('servis hatası İZİN REDDİNDEN ayrı gösterilir', (t) async {
    // Biri kullanıcının seçimi, diğeri sistem sorunu — aynı mesaj yanlış olurdu.
    await pump(t, serviceCanStart: false);

    await t.tap(find.byKey(const Key('sleep-toggle')));
    await settle(t);

    expect(find.byKey(const Key('sleep-service-failed')), findsOneWidget);
    expect(find.byKey(const Key('sleep-permission-denied')), findsNothing);
  });

  testWidgets('mikrofon izni YOKSA servis HİÇ başlatılmaz (boş bildirim olmasın)', (t) async {
    await pump(t, permission: false);

    await t.tap(find.byKey(const Key('sleep-toggle')));
    await settle(t);

    // Servis bildirimi gösterip sonra "aslında iznin yok" demek, kullanıcıya
    // anlamsız bir bildirim bırakırdı.
    expect(service.startCalls, 0);
  });

  testWidgets('bitir → SERVİS de durur (bildirim "hâlâ dinliyorum" demesin)', (t) async {
    await pump(t);

    await t.tap(find.byKey(const Key('sleep-toggle')));
    await settle(t);
    await t.tap(find.byKey(const Key('sleep-toggle')));
    await settle(t);

    expect(service.started, isFalse);
    expect(service.stopCalls, greaterThanOrEqualTo(1));
  });

  testWidgets('zarf KAPALIYKEN paylaş düğmesi görünmez (gereksiz veri toplanmaz)', (t) async {
    await pump(t); // logEnvelope: false

    await t.tap(find.byKey(const Key('sleep-toggle')));
    await settle(t);
    await t.tap(find.byKey(const Key('sleep-toggle')));
    await settle(t);

    expect(find.byKey(const Key('sleep-export')), findsNothing);
  });

  testWidgets('ÇEKİRDEK: zarf açıkken gece bitince FIXTURE paylaşılabilir', (t) async {
    await pump(t, logEnvelope: true);

    await t.tap(find.byKey(const Key('sleep-toggle')));
    await settle(t);
    await t.tap(find.byKey(const Key('sleep-toggle')));
    await settle(t);

    // docs/04 §120 fixture'ı: eşikler ancak bu veriyle ayarlanabilir.
    expect(find.byKey(const Key('sleep-export')), findsOneWidget);
    expect(find.byKey(const Key('sleep-export-hint')), findsOneWidget);
  });

  testWidgets('ÇEKİRDEK: paylaşılan fixture CSV — PNG değil, ham ses hiç değil', (t) async {
    await pump(t, logEnvelope: true);

    await t.tap(find.byKey(const Key('sleep-toggle')));
    await settle(t);
    await t.tap(find.byKey(const Key('sleep-toggle')));
    await settle(t);
    await t.tap(find.byKey(const Key('sleep-export')));
    await settle(t);

    final f = sharer.last?.file;
    expect(f, isNotNull);
    // MIME tipi veriyle GELMELİ: başta sabit 'image/png' yazıyordu ve CSV bozuk
    // görsel olarak açılırdı.
    expect(f!.mimeType, 'text/csv');
    expect(f.filename, endsWith('.csv'));
    // `utf8.decode` — `String.fromCharCodes` UTF-8 baytlarını tek tek karakter sanar
    // ve Türkçe'yi bozar. Dosya UTF-8 kodlanmış olmalı (ShareFile.csv öyle yapıyor);
    // `codeUnits` ile kodlasaydık başlıklar alıcı tarafta bozuk çıkardı.
    final csv = utf8.decode(f.bytes);
    expect(csv, contains('second,minDb,meanDb,maxDb,frames'));
    expect(csv, contains('HAM SES DEĞİL'));
  });

  testWidgets('paylaşım OTOMATİK değil — kullanıcı basmadan hiçbir şey gitmez', (t) async {
    await pump(t, logEnvelope: true);

    await t.tap(find.byKey(const Key('sleep-toggle')));
    await settle(t);
    await t.tap(find.byKey(const Key('sleep-toggle')));
    await settle(t);

    // Gece bitti, zarf var — ama kullanıcı paylaş demedi.
    expect(sharer.last, isNull);
  });

  testWidgets('sessiz gecede SIFIR olay raporlanır (hayalet olay yok)', (t) async {
    final sleep = _FakeSleep();
    await pump(t, sleep: sleep, frames: List.generate(80, (_) => frame(0.0001)));

    await t.tap(find.byKey(const Key('sleep-toggle')));
    await settle(t);
    await t.tap(find.byKey(const Key('sleep-toggle')));
    await settle(t);

    expect(sleep.saved.single.soundEvents, 0);
  });
}
