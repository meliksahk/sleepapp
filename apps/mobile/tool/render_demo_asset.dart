// ÖRNEK SES ÜRETİCİ — geliştirici aracı, üretim kodu değil.
//
// NEDEN VAR: asset zincirini (dosya → MinIO → audio_assets → API → mikser) uçtan
// uca DENEYEBİLMEK için elimizde bir dosya olması gerekiyor. Kullanıcı henüz dosya
// koymadı ve internetten ses İNDİRMEK YASAK (telif + mağaza politikası,
// docs/04 §1.2.0) — indirilen bir dosyanın lisansını kanıtlayamayız.
//
// Çözüm: sesi KENDİ motorumuzla üretiyoruz. Böylece lisans sorusu yok
// ('self-produced') ve üretilen şey gerçekten çalınabilir bir dosya.
//
// Çalıştır: cd apps/mobile && dart run tool/render_demo_asset.dart
// Çalıştır: cd apps/mobile && dart run tool/render_demo_asset.dart pad-only
// Çıktı   : apps/api/assets-inbox/demo/<demo>.wav + .json
//
// `print` kasıtlı: bu bir CLI aracı.
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:nocta/core/audio_engine/dsp/mix_loop.dart';
import 'package:nocta/core/audio_engine/dsp/mix_render.dart';
import 'package:nocta/core/audio_engine/dsp/wav_encoder.dart';

const int sampleRate = 48000;

/// KISA tutuldu (10 sn): bu bir demo, kütüphane içeriği değil. 48 kHz/16-bit
/// mono → ~960 KB. Uzun tutmak depoyu ve yükleme testini gereksiz yavaşlatırdı.
const int seconds = 10;

/// Üretilebilecek demolar.
///
/// **Neden birden fazla — ölçülmüş bir karışıklıktan doğdu.** Tek demo `pad +
/// fire` idi ve kullanıcı onu mikserde çalıp "melodi dışında dipte bir gürültü
/// var, neden?" diye sordu. Cevap: `fire` DOSYANIN İÇİNDE, bir mikser katmanı
/// değil — sürgüyle kapatılamaz, çünkü ithal dosya motor için tek parça opak bir
/// akıştır. Bunu ANLATMAK yerine GÖSTERMEK için yan yana dinlenebilecek temiz
/// bir melodi dosyası gerekiyordu.
const Map<String, ({String slug, String title, MixSpec spec})> demos =
    <String, ({String slug, String title, MixSpec spec})>{
  'pad-fire': (
    slug: 'pad-fire-demo',
    title: 'Pad + Fire (demo)',
    // İkisi bilerek birlikte: motorun İKİ farklı karakterini de taşısın ki
    // "gerçekten ses var mı" sorusu tek bir gürültü tınısıyla değil, duyulur
    // bir yapıyla cevaplansın.
    spec: MixSpec(<MixLayer>[
      MixLayer(id: 'pad', type: LayerSource.pad, gain: 0.55),
      MixLayer(id: 'fire', type: LayerSource.fire, gain: 0.35),
    ]),
  ),
  'pad-only': (
    slug: 'pad-only-demo',
    title: 'Pad (yalnız melodi)',
    // Tek katman, dokusuz. Kazanç 0.55 DEĞİL 0.72: `fire` çıkınca toplam
    // seviye düşer ve iki dosya yan yana dinlenirken biri kısık gelirse
    // karşılaştırma "gürültü mü, seviye mi" sorusuna bulanır.
    spec: MixSpec(<MixLayer>[
      MixLayer(id: 'pad', type: LayerSource.pad, gain: 0.72),
    ]),
  ),
};

void main(List<String> args) {
  final key = args.isEmpty ? 'pad-fire' : args.first;
  final demo = demos[key];
  if (demo == null) {
    print('Bilinmeyen demo: $key');
    print('Seçenekler: ${demos.keys.join(', ')}');
    exitCode = 2;
    return;
  }
  render(demo);
}

void render(({String slug, String title, MixSpec spec}) demo) {
  // apps/mobile'dan apps/api/assets-inbox/demo'ya.
  final outDir = Directory('../api/assets-inbox/demo');
  outDir.createSync(recursive: true);

  print('Render: ${seconds}s @ ${sampleRate}Hz — ${demo.title}…');
  final started = DateTime.now();

  // `renderSeamlessLoop`: dosyanın KENDİSİ dikişsiz döngülensin. Asset katmanında
  // crossfade'i çalma anında uygulayamıyoruz (PCM'e erişim yok — asset_layer.dart),
  // yani dikişsizlik DOSYAYA gömülmek zorunda. Bu demo tam da bunu gösterir:
  // düzgün hazırlanmış bir dosya tıksız döngülenir.
  var clipped = 0;
  final pcm = renderSeamlessLoop(
    demo.spec,
    loopSeconds: seconds,
    sampleRate: sampleRate,
    seed: 20260719,
    onClipReport: (c) => clipped = c,
  );
  final elapsed = DateTime.now().difference(started);

  final wav = encodeWav(pcm, sampleRate: sampleRate);
  final wavPath = '${outDir.path}/${demo.slug}.wav';
  File(wavPath).writeAsBytesSync(wav);

  // Yanındaki meta dosyası — yükleme script'inin okuduğu şey.
  // LİSANS ZORUNLU: bu dosyayı BİZ ürettik, kaynağı da bu script.
  final meta = <String, Object>{
    'title': demo.title,
    'genre': 'ambient',
    'mood': <String>['calm', 'sleep'],
    'license': 'self-produced',
    'source': 'NOCTA audio engine — apps/mobile/tool/render_demo_asset.dart',
    'durationSeconds': seconds,
  };
  final jsonPath = '${outDir.path}/${demo.slug}.json';
  File(jsonPath).writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(meta)}\n',
  );

  print('✓ $wavPath (${(wav.length / 1024).toStringAsFixed(0)} KB)');
  print('✓ $jsonPath');
  print('  render süresi: ${elapsed.inMilliseconds} ms, kırpılan örnek: $clipped');
  if (clipped > 0) {
    // Sessizce geçilmez: kırpma duyulur bir bozulmadır.
    print('  ⚠️ KIRPMA VAR — kazançları düşürmek gerekir.');
  }
}
