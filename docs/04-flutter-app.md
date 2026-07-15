# 04 — Flutter Uygulaması: Mimari ve Faz Planı

## 1. Mimari Karar

**Feature-first Clean Architecture + Riverpod.** Gerekçe:

- Feature-first: ekip gelince feature = sahiplik birimi; yatay katman klasörleri (tüm bloclar bir yerde) 20+ ekranda çöker.
- Clean Architecture (feature içinde 3 katman): ses motoru, uyku analizi ve skorlama gibi _gerçek domain mantığı olan_ bir uygulama bu; UI'dan bağımsız test edilebilir domain katmanı burada süs değil ihtiyaç.
- Riverpod (codegen): compile-time güvenli DI + state; BLoC'a göre daha az tören, GetX gibi anti-pattern değil. Tek desen kuralı CLAUDE.md'de.

### 1.1 Klasör Yapısı

```
apps/mobile/
├── lib/
│   ├── app/                      # MaterialApp, go_router, ProviderScope, bootstrap
│   ├── core/                     # feature'ların paylaştığı altyapı
│   │   ├── audio_engine/         # ★ jeneratif motor cephesi (aşağıda)
│   │   ├── design_system/        # token'lardan üretilen ThemeData + Nocta bileşenleri
│   │   ├── api/                  # üretilen Dart client + auth interceptor + offline kuyruk
│   │   ├── storage/              # drift DB, secure storage, prefs sarmalayıcıları
│   │   ├── analytics/            # PostHog cephesi (event sözlüğüne bağlı, tipli)
│   │   ├── entitlement/          # EntitlementService arayüzü (dev'de stub; IAP en son fazda takılır)
│   │   ├── notifications/        # push + local notification (alarm)
│   │   └── media/                # kart render (widget→image), video export cephesi
│   └── features/
│       ├── onboarding/           # archetype testi + kimlik kartı
│       ├── mixer/                # ses mikseri + preset'ler
│       ├── session/              # uyku modu ekranı, mikrofon takip, akıllı alarm
│       ├── report/               # gece raporu + paylaşım
│       ├── library/              # soundscape feed, haftalık içerik, favoriler
│       ├── habit/                # streak, ritüel hatırlatıcıları
│       ├── share_studio/         # mix-to-video export
│       ├── paywall/              # deneme, satın alma, restore
│       └── settings/             # profil, hesap silme, izinler, dil
├── packages/
│   └── api_client/               # OpenAPI'den üretilen (elle dokunulmaz)
├── ios/  android/                # native ses/alarm kodu burada yaşar
└── test/  integration_test/
```

Her feature içi:

```
features/report/
├── domain/        # NightReport entity, GenerateReportInsight use case, ReportRepository (arayüz)
├── data/          # ReportDto, ReportApiDatasource, ReportLocalDatasource(drift), ReportRepositoryImpl
└── presentation/  # report_screen.dart, report_controller.dart (riverpod), widgets/
```

**Lint ile zorlanan kurallar:** `domain` → Flutter import edemez; feature'dan feature'a import yasak (ortaklaşan şey `core`'a iner); `presentation` → `data` import edemez (yalnızca domain arayüzü + provider).

### 1.2 Ses Motoru Mimarisi (teknik hendek)

```
┌─ presentation (MixerScreen) ─────────────────────────────┐
│   yalnızca AudioEngineFacade'i görür                     │
├─ core/audio_engine/ (Dart) ─────────────────────────────┤
│  AudioEngineFacade   : play/stop/setLayerVolume/         │
│                        applyPreset/crossfade/sleepTimer  │
│  EngineParams        : soundscapes.engine_params şeması  │
│  MixerState (freezed): katman listesi + değerler         │
│      │ platform channel (method + event channel)         │
├─ native ─────────────────────────────────────────────────┤
│  iOS: AVAudioEngine graph                                │
│    - binaural taşıyıcı: 2x AVAudioSourceNode (sine, L/R  │
│      frekans farkı = beat Hz)                            │
│    - prosedürel katmanlar: buffer loop'ları (yağmur,     │
│      brown noise — noise runtime'da üretilir) + filtre   │
│    - AVAudioSession: .playback, background audio, kesinti│
│      (arama gelirse) yönetimi                            │
│  Android: Oboe (C++/JNI) aynı graph; AAudio exclusive    │
└──────────────────────────────────────────────────────────┘
```

Kritik kurallar:

- Ses üretimi %100 on-device; `engine_params` yalnızca _tarif_ (JSON) — sunucudan MP3 stream edilmez. Küçük örnek dosyalar (kuş sesi gibi kayıtlar) Storage'dan bir kez indirilir, immutable cache'lenir.
- `engine_params` şeması versiyonludur (`schema_version`); eski uygulama yeni şemayı görürse zarifçe eski preset'e düşer (crash değil).
- DSP değişikliklerine golden test: verilen param seti için üretilen 5 sn'lik buffer'ın RMS/spektral istatistikleri snapshot ile karşılaştırılır (birebir örnek eşitliği değil — platform farkı toleransı).
- Pil bütçesi: uyku modunda ekran kapalı CPU hedefi < %4; her motor değişikliğinde gerçek cihazda 8 saatlik gece profili koşulur (Instruments/Perfetto).

### 1.3 Uyku Takibi + Akıllı Alarm

- Mikrofon işleme on-device: dB zarfı + basit olay sınıflandırması (hareket/horlama/gürültü _olay sayısı_); ham ses diske bile yazılmaz (yalnızca RAM ring buffer). Bu hem KVKK/GDPR hem App Store mikrofon gerekçesi açısından savunma hattımızdır.
- Akıllı alarm: alarm penceresi (ör. 06:30–07:00) içinde hafif uyku sinyali (hareket/ses aktivitesi artışı) görülünce local notification + ses motoru "sunrise" rampası. iOS kısıtı dürüstçe kabul edilir: arka planda mikrofonla takip yalnızca uygulama ön planda/audio session aktifken güvenilirdir → ürün kararı: uyku modu = telefon şarjda, uygulama açık, ekran kapalı (kategori standardı; Sleep Cycle da böyle).
- Oturum verisi önce drift'e yazılır, sabah Wi-Fi'da API'ye batch senkron (offline-first).

## 2. Fazlar

### Faz M0 — İskelet + Design System (Hafta 3–5)

- Monorepo içinde Flutter projesi, flavor'lar (dev/staging/prod), CI (analyze+test+build), Sentry. fastlane iskeleti hazırlanır ama TestFlight lane'i dev hesabı ister → docs/10'a; o güne dek dağıtım simülatör + yerel cihaz build'i (sideload).
- `design_system`: token codegen → ThemeData (dark-first), çekirdek bileşenler (NButton, NCard, NSheet, NGauge), typography ölçeği.
- go_router iskeleti, auth akışı: anonim cihaz kaydı ile başla (kendi API'mizin `POST /v1/auth/device` ucu) → sonradan e-posta ile hesaba yükseltme; Apple Sign-In dev hesabı bağlanınca eklenir (docs/10).
- drift kurulumu, offline API kuyruğu iskeleti.
- **Çıkış kriteri:** CI'da build alınan, staging API'ye anonim kayıt olup yetkili istek atabilen boş uygulama.

### Faz M1 — Archetype Testi + Kimlik Kartı (Hafta 5–7) — viral kanca #1

- Onboarding: 60 sn'lik test (soru matrisi API'den, versiyonlu), animasyonlu geçişler, skip yok ama "sonra bitir" var.
- Skorlama use case'i domain'de (web ile aynı matris — kontrat testiyle eşitlik doğrulanır).
- Kimlik kartı: widget → yüksek çözünürlük image render (`RepaintBoundary`), archetype'a özel gradient/desen, köşede logo; Instagram story boyutu (1080×1920) + kare varyant; native share sheet.
- Analytics: test başlama/bitirme/paylaşma funnel'ı.
- **Çıkış kriteri:** testten paylaşıma uçtan uca akış; kart render'ı < 300ms; paylaşım oranı ölçülüyor.

### Faz M2 — Mikser + Jeneratif Motor (Hafta 7–10) — çekirdek değer

- Native motor v1: binaural taşıyıcı + 3 prosedürel katman (brown/pink noise, yağmur sentezi, pad) + 2 örnek-tabanlı katman; katman başına volume/filtre; crossfade; sleep timer (fade-out).
- MixerScreen: katman kartları, tek elle kullanılabilir slider'lar (gece kullanımı → büyük dokunma alanları, kırmızıya kaçmayan loş palet).
- Preset'ler: archetype default'u + kullanıcı mix kaydetme (drift + API senkron).
- Background audio + kilit ekranı kontrolleri + kesinti yönetimi.
- **Çıkış kriteri:** golden audio testleri yeşil; simülatör + eldeki tek cihazda temel çalma/kesinti senaryoları geçiyor. (8 saatlik gerçek-gece pil/kalite testi bilinçli olarak sona, docs/10 lansman kontrol listesine ertelendi — kullanıcı kararı; riski orada kapatılır.)

### Faz M3 — Uyku Modu + Gece Raporu (Hafta 10–13) — viral kanca #2

- Uyku modu ekranı: tek dokunuşla başlat, saat + nefes animasyonu, mikrofon izni gerekçe ekranı (net, dürüst metin).
- On-device analiz + akıllı alarm penceresi.
- Gece Raporu: "gece makbuzu" estetiği — süre, olay zaman çizelgesi (sparkline), archetype'a göre tek cümlelik yorum (yerel kural motoru; LLM yok = maliyet 0), streak durumu; paylaşım kartı + `/r/{slug}` linki.
- **Çıkış kriteri:** kayıtlı/simüle mikrofon beslemeleriyle (fixture gece kayıtları) mantıklı rapor üretimi testle kanıtlı; alarm penceresi mantığı unit+integration testli. (Gerçek gece doğrulaması docs/10 lansman listesinde.)

### Faz M4 — Habit Döngüsü + İçerik (Hafta 13–16)

- Streak + ritüel bildirimleri (yerel), haftalık içerik feed'i (`library`), favoriler.
- Premium gating altyapısı: tier tanımları kodda hazırlanır — cömert free (mikser 3 katman, günlük rapor, temel sesler) / Plus (tüm katmanlar, gelişmiş rapor geçmişi, haftalık yeni içerik) / Lifetime — ama hepsi `EntitlementService` stub'ı üzerinden ve geliştirmede herkes premium. **Paywall UI ve gerçek IAP bu fazda YAZILMAZ** (docs/10 F6'da).
- Feature flag entegrasyonu (gating/deney varyantları flag'le).
- **Çıkış kriteri:** streak/bildirim/feed akışları testli; bir feature'ı free/premium arasında flag+entitlement ile aç-kapa etmek tek satır konfig.

### Faz M5 — Share Studio: Mix-to-Video (Hafta 16–19) — viral kanca #3

- Kullanıcı mix'i → 9:16 loop video: dalga formu/parçacık görselleştirmesi + archetype teması + watermark. Render on-device: görsel kareler `CustomPainter`→frame'ler, ses motorundan offline render edilen loop ile ffmpeg_kit mux (arka planda, ilerleme bildirimli).
- Süre seçenekleri (30 sn / 1 dk / 10 dk loop talimatlı), TikTok/Reels/YouTube boyut preset'leri.
- **Çıkış kriteri:** orta seviye cihazda (iPhone 12) 1 dk video < 90 sn'de üretiliyor; export→paylaşım funnel'ı ölçülüyor.
- ⚠️ Dürüstlük notu: ffmpeg_kit lisansı (LGPL yapılandırması) ve iOS binary boyutu etkisi bu fazda doğrulanacak — alternatif: AVAssetWriter (iOS native) ile mux, Android'de MediaMuxer. Native yol daha çok iş ama sıfır lisans riski; faz başında spike yapılır.

### Faz M6 — Cila (Ay 5+)

- A/B altyapısı: onboarding varyantları (flag tabanlı).
- Widget'lar (iOS kilit ekranı: streak + "uyku modunu başlat"), App Intents/Shortcuts ("Hey Siri, uyku modunu başlat").
- Erişilebilirlik denetimi (VoiceOver ile tam onboarding), ek diller, performans profili.

### Faz M7 — Para + Lansman (dev hesapları bağlandıktan sonra — docs/10'un mobil ayağı)

- Apple Sign-In, push (APNs), TestFlight/fastlane dağıtımı.
- Paywall UI + StoreKit 2 IAP + gerçek 7 gün deneme; metinlerde Anima karşıt-konumu: "kart bilgisi girmeden dene". Watermark kaldırma opsiyonu Plus'ta — watermark default kalır (viral motor).
- Sandbox satın alma/restore/iade üçlüsü; gerçek cihaz gece testleri (8 saat pil/ses + 5 gerçek gece raporu); ASO + `fastlane/metadata` store metinleri.

## 3. Test Stratejisi

- Unit: skorlama matrisi, streak/gün sınırı, rapor kural motoru, mixer state geçişleri, entitlement gating.
- Golden (görsel): kimlik kartı + gece raporu render'ları archetype başına golden dosyalarla.
- Golden (audio): motor buffer istatistik snapshot'ları.
- Integration (patrol): onboarding→kart, mix→kaydet→yeniden yükle, uyku modu→rapor (mock mikrofon beslemesi), satın alma (StoreKit test).
- Gerçek cihaz matrisi: her release öncesi iPhone SE (küçük ekran) + eski bir Android (düşük RAM) manuel duman testi — ses uygulamasında simülatör yeterli DEĞİLDİR.
