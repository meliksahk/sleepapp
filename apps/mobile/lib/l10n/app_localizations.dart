import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppL10n
/// returned by `AppL10n.of(context)`.
///
/// Applications need to include `AppL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppL10n.localizationsDelegates,
///   supportedLocales: AppL10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppL10n.supportedLocales
/// property.
abstract class AppL10n {
  AppL10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppL10n of(BuildContext context) {
    return Localizations.of<AppL10n>(context, AppL10n)!;
  }

  static const LocalizationsDelegate<AppL10n> delegate = _AppL10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('tr'),
  ];

  /// Kimlik kartını paylaş butonu
  ///
  /// In en, this message translates to:
  /// **'Share your identity'**
  String get shareIdentityCta;

  /// Kart render edilirken buton metni
  ///
  /// In en, this message translates to:
  /// **'Preparing…'**
  String get sharePreparing;

  /// Paylaşım sayfasına giden metin
  ///
  /// In en, this message translates to:
  /// **'My sleep identity is {name}.'**
  String shareIdentityText(String name);

  /// Gece boyu duran bildirim başlığı — kullanıcı mikrofonun açık olduğunu GÖRÜR
  ///
  /// In en, this message translates to:
  /// **'Listening to your night'**
  String get sleepModeNotificationTitle;

  /// Gece bildirimi gövdesi
  ///
  /// In en, this message translates to:
  /// **'Analysed on your phone. Tap to open.'**
  String get sleepModeNotificationBody;

  /// Foreground servis başlatılamadı — kayıt başlatılmadı
  ///
  /// In en, this message translates to:
  /// **'Could not keep listening in the background. Your night would not be recorded.'**
  String get sleepModeServiceFailed;

  /// dB zarfını paylaş — eşik ayarı fixture'ı (docs/04 §120)
  ///
  /// In en, this message translates to:
  /// **'Share night diagnostics'**
  String get sleepModeExportEnvelope;

  /// Zarfın ne olduğu — kullanıcı paylaşmadan önce bilmeli
  ///
  /// In en, this message translates to:
  /// **'A per-second loudness summary — not a recording. Helps us tune detection.'**
  String get sleepModeExportHint;

  /// Uyku modu ekranı başlığı
  ///
  /// In en, this message translates to:
  /// **'Sleep mode'**
  String get sleepModeTitle;

  /// Kaydı başlat
  ///
  /// In en, this message translates to:
  /// **'Start the night'**
  String get sleepModeStart;

  /// Kaydı bitir ve kaydet
  ///
  /// In en, this message translates to:
  /// **'End the night'**
  String get sleepModeStop;

  /// Kayıt sürerken durum
  ///
  /// In en, this message translates to:
  /// **'Listening…'**
  String get sleepModeRecording;

  /// Canlı olay sayacı. ICU plural — Türkçe İngilizce -s mantığını izlemez.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No sounds yet} =1{1 sound so far} other{{count} sounds so far}}'**
  String sleepModeEvents(int count);

  /// Gizlilik notu — CLAUDE.md §6'nın kullanıcıya söylenmiş hali
  ///
  /// In en, this message translates to:
  /// **'Audio is analysed on your phone and never leaves it. Only the time and a count are saved.'**
  String get sleepModePrivacy;

  /// İzin reddedildiğinde
  ///
  /// In en, this message translates to:
  /// **'Microphone access is needed to listen to your night.'**
  String get sleepModePermissionDenied;

  /// Kayıt bittiğinde özet
  ///
  /// In en, this message translates to:
  /// **'Night saved: {hours}h {minutes}m'**
  String sleepModeSaved(int hours, int minutes);

  /// Sunucuya yazılamadı ama gece yok sayılmadı
  ///
  /// In en, this message translates to:
  /// **'Saved on your phone, but could not reach the server.'**
  String get sleepModeSaveFailed;

  /// Kabuk şeridi — süren gece HER ekranda görünür. 'Dinliyor…' tek başına mikser ekranında çalan sesle karışırdı
  ///
  /// In en, this message translates to:
  /// **'Tracking your night'**
  String get sleepStripActive;

  /// Kabuk şeridinin erişilebilirlik etiketi — şerit dokunulabilir bir kısayoldur
  ///
  /// In en, this message translates to:
  /// **'Open sleep mode'**
  String get sleepStripOpen;

  /// Ana ekrandan uyku moduna giden buton
  ///
  /// In en, this message translates to:
  /// **'Sleep mode'**
  String get homeSleepMode;

  /// Oturum kurulamadığında üstte görünen çubuk
  ///
  /// In en, this message translates to:
  /// **'Offline — some features need a connection'**
  String get offlineBanner;

  /// Çevrimdışı çubuğundaki yeniden dene
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get offlineRetry;

  /// Ana ekrandan miksere giden buton
  ///
  /// In en, this message translates to:
  /// **'Open mixer'**
  String get homeOpenMixer;

  /// Mikser ekranı başlığı
  ///
  /// In en, this message translates to:
  /// **'Mixer'**
  String get mixerTitle;

  /// Sesi başlat
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get mixerPlay;

  /// Sesi duraklat
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get mixerPause;

  /// Katmanlar render edilirken
  ///
  /// In en, this message translates to:
  /// **'Preparing sound…'**
  String get mixerPreparing;

  /// Player hero'sunda adın üstündeki etiket. 'Now playing' DEĞİL: ses duraklatılmışken yalan olurdu
  ///
  /// In en, this message translates to:
  /// **'Tonight\'s sound'**
  String get mixerSoundLabel;

  /// Player durum satırı — ses çalıyor
  ///
  /// In en, this message translates to:
  /// **'Playing'**
  String get mixerStatusPlaying;

  /// Player durum satırı — ses duraklatıldı
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get mixerStatusPaused;

  /// Kontrol sayfasındaki sürgü listesinin başlığı
  ///
  /// In en, this message translates to:
  /// **'Layers'**
  String get mixerLayersLabel;

  /// Beyaz gürültü katmanı adı
  ///
  /// In en, this message translates to:
  /// **'White noise'**
  String get mixerLayerWhite;

  /// Pembe gürültü katmanı adı
  ///
  /// In en, this message translates to:
  /// **'Pink noise'**
  String get mixerLayerPink;

  /// Kahverengi gürültü katmanı adı
  ///
  /// In en, this message translates to:
  /// **'Brown noise'**
  String get mixerLayerBrown;

  /// Dalga katmanı adı (sentezlenmiş)
  ///
  /// In en, this message translates to:
  /// **'Ocean waves'**
  String get mixerLayerWaves;

  /// Ateş katmanı adı (sentezlenmiş)
  ///
  /// In en, this message translates to:
  /// **'Crackling fire'**
  String get mixerLayerFire;

  /// Yağmur katmanı adı (sentezlenmiş)
  ///
  /// In en, this message translates to:
  /// **'Rainfall'**
  String get mixerLayerRain;

  /// Melodik pad katmanı adı (sentezlenmiş)
  ///
  /// In en, this message translates to:
  /// **'Warm pad'**
  String get mixerLayerPad;

  /// Katman kazancı yüzdesi — erişilebilirlik etiketi. YERELLEŞTİRİLEBİLİR: İngilizce '30%' yazar, Türkçe '%30'. Literal bırakmak yanlış olurdu.
  ///
  /// In en, this message translates to:
  /// **'{percent}%'**
  String mixerGainPercent(int percent);

  /// Bu ses yolunun geçici olduğunu kullanıcıya söyleyen not — nihai native motor değil
  ///
  /// In en, this message translates to:
  /// **'Early build: generated locally, looped. Sound quality is not final.'**
  String get mixerStopgapNotice;

  /// Ses başlatılamadığında
  ///
  /// In en, this message translates to:
  /// **'Sound could not start.'**
  String get mixerFailed;

  /// Dosya katmanının döngü dikişi crossfade'lenemiyor (PCM'e erişim yok) — dürüstlük dipnotu
  ///
  /// In en, this message translates to:
  /// **'Audio files repeat as-is; you may hear a short click at the loop point.'**
  String get mixerAssetLoopNotice;

  /// Asset katmanı yüklenemedi ama mix çalıyor — hata değil, dipnot
  ///
  /// In en, this message translates to:
  /// **'An audio file could not be loaded; the rest of the mix is still playing.'**
  String get mixerAssetUnavailable;

  /// Katman listesinin başlığındaki eylem — ses dosyası kataloğunu açar
  ///
  /// In en, this message translates to:
  /// **'Add sound'**
  String get mixerAddSound;

  /// Ses dosyası kataloğu sayfasının başlığı
  ///
  /// In en, this message translates to:
  /// **'Your sounds'**
  String get mixerAssetCatalogTitle;

  /// Katalog boş — kullanıcı henüz dosya yüklememiş
  ///
  /// In en, this message translates to:
  /// **'No audio files yet.'**
  String get mixerAssetCatalogEmpty;

  /// Boş katalogda NE YAPILACAĞI: dosya nereye konur + hangi komut çalıştırılır. Yol ve komut çevrilmez, cümle çevrilir
  ///
  /// In en, this message translates to:
  /// **'Drop files into apps/api/assets-inbox/<category>/<name>.mp3 with a matching <name>.json holding title, mood, license and source. Then run pnpm assets:upload — they show up here.'**
  String get mixerAssetCatalogEmptyHow;

  /// Katalogdan seçilen dosyanın adresi çözülemedi (404/401/ağ yok) — katman eklenmedi ama mix çalıyor
  ///
  /// In en, this message translates to:
  /// **'That sound could not be added. The mix is still playing.'**
  String get mixerAssetAddFailed;

  /// Dosya katmanını kaldırma düğmesinin erişilebilirlik etiketi. {name} içerik adıdır, çevrilmez
  ///
  /// In en, this message translates to:
  /// **'Remove {name}'**
  String mixerRemoveLayer(String name);

  /// Kalıcı dipnot: renderMix asset katmanlarını atlar — paylaşılan videoda dosyalar duyulmaz
  ///
  /// In en, this message translates to:
  /// **'Audio files you added are not recorded in the video.'**
  String get mixerExportAssetWarning;

  /// Export onay diyaloğunun gövdesi — dipnotun uzun hâli
  ///
  /// In en, this message translates to:
  /// **'The video only records generated layers. Audio files you added will not be heard in it.'**
  String get mixerExportAssetWarningLong;

  /// Export onay diyaloğunda devam et
  ///
  /// In en, this message translates to:
  /// **'Make video anyway'**
  String get mixerExportAnyway;

  /// Diyaloglarda vazgeç
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// Mix-to-video export butonu — viral kanca #3
  ///
  /// In en, this message translates to:
  /// **'Share as video'**
  String get mixerExportVideo;

  /// Export sürerken buton metni; export saniyeler sürer, kullanıcı beklediğini bilmeli
  ///
  /// In en, this message translates to:
  /// **'Making video… {percent}%'**
  String mixerExporting(int percent);

  /// Export patladığında gösterilen sade metin — teknik detay loglanır, kullanıcıya gitmez
  ///
  /// In en, this message translates to:
  /// **'Video could not be created.'**
  String get mixerExportFailed;

  /// Videoyla birlikte paylaşılan metin; viral döngüyü kapatır
  ///
  /// In en, this message translates to:
  /// **'My sleep mix — made with NOCTA'**
  String get mixerExportShareText;

  /// Videonun üstünde görünen başlık
  ///
  /// In en, this message translates to:
  /// **'Tonight\'s mix'**
  String get mixerVideoTitle;

  /// Uyku modundaki alarm bölümü başlığı
  ///
  /// In en, this message translates to:
  /// **'Smart alarm'**
  String get alarmSectionTitle;

  /// Alarm kurulu değil — varsayılan (opt-in)
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get alarmOff;

  /// Kurulu alarm. 'by' bilinçli: bu bir son tarih, tam saat değil — pencerede daha erken çalabilir
  ///
  /// In en, this message translates to:
  /// **'Wake me by {time}'**
  String alarmSet(String time);

  /// Alarmın ne yaptığını dürüstçe anlatır: sezgisel + son tarih garantisi. Uyku evresi İDDİASI yok (CLAUDE.md §1.1)
  ///
  /// In en, this message translates to:
  /// **'We\'ll look for a lighter moment in the {minutes} minutes before, and wake you by then at the latest.'**
  String alarmExplain(int minutes);

  /// Alarm saati seçme butonu
  ///
  /// In en, this message translates to:
  /// **'Set alarm'**
  String get alarmChoose;

  /// Alarmı kaldır
  ///
  /// In en, this message translates to:
  /// **'Turn off'**
  String get alarmClear;

  /// Alarm hafif uyku sinyaliyle çaldı. 'stirred' = gözlemlediğimiz şey; uyku evresi iddiası DEĞİL
  ///
  /// In en, this message translates to:
  /// **'You stirred — good moment to wake up.'**
  String get alarmRingingLightSleep;

  /// Alarm son tarihte çaldı (hafif uyku sinyali hiç görülmedi)
  ///
  /// In en, this message translates to:
  /// **'Time to wake up.'**
  String get alarmRingingDeadline;

  /// Alarmı susturur; gece kaydı devam eder
  ///
  /// In en, this message translates to:
  /// **'Stop alarm'**
  String get alarmDismiss;

  /// Gece raporu kartı başlığı — 'makbuz' metaforu: iddia taşımaz, kayıt tutar
  ///
  /// In en, this message translates to:
  /// **'Night receipt'**
  String get reportCardHeader;

  /// Kartta süre — biçim yerele bağlı
  ///
  /// In en, this message translates to:
  /// **'{hours}h {minutes}m'**
  String reportCardDuration(int hours, int minutes);

  /// Kartta dinginlik satırı etiketi
  ///
  /// In en, this message translates to:
  /// **'Calm'**
  String get reportCardCalm;

  /// D-10: ölçtüğümüz şey bu — 'hareket' değil
  ///
  /// In en, this message translates to:
  /// **'Louder moments'**
  String get reportCardLoud;

  /// Kartta seri satırı
  ///
  /// In en, this message translates to:
  /// **'Night streak'**
  String get reportCardStreak;

  /// Kartta uyku kimliği satırı
  ///
  /// In en, this message translates to:
  /// **'Identity'**
  String get reportCardIdentity;

  /// CLAUDE.md §1.1 — kart paylaşılıyor, uyarı kartın ÜSTÜNDE olmalı
  ///
  /// In en, this message translates to:
  /// **'An in-app calm measure for your sleep ritual. Not a health score.'**
  String get reportCardDisclaimer;

  /// Gece raporu paylaşım metni
  ///
  /// In en, this message translates to:
  /// **'My night on NOCTA'**
  String get reportShareText;

  /// Gece raporu ekranı başlığı
  ///
  /// In en, this message translates to:
  /// **'Night report'**
  String get nightReportTitle;

  /// O gece için oturum yokken gösterilen boş durum
  ///
  /// In en, this message translates to:
  /// **'No sleep recorded for this night'**
  String get nightReportEmpty;

  /// Uygulama-içi göreli dinginlik ölçüsü (SAĞLIK ÖLÇÜSÜ DEĞİL)
  ///
  /// In en, this message translates to:
  /// **'Calm {score}/100'**
  String nightReportCalm(int score);

  /// Sağlık iddiası feragati (CLAUDE.md §1.1) — çeviride de KORUNMALI
  ///
  /// In en, this message translates to:
  /// **'An in-app calm measure for your ritual — not a health score.'**
  String get nightReportCalmDisclaimer;

  /// O gecedeki uyku oturumu sayısı etiketi
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get nightReportSessions;

  /// D-10: ölçtüğümüz şeyin ne olduğunu açıkça söyler
  ///
  /// In en, this message translates to:
  /// **'Short bursts of sound the app heard. Not movement — we don’t measure that.'**
  String get nightReportLoudHint;

  /// On-device türetilmiş hareket olayı sayısı
  ///
  /// In en, this message translates to:
  /// **'Movement events'**
  String get nightReportMovementEvents;

  /// On-device türetilmiş ses olayı sayısı
  ///
  /// In en, this message translates to:
  /// **'Louder moments'**
  String get nightReportSoundEvents;

  /// Gece raporu paylaşım butonu (viral kanca #2)
  ///
  /// In en, this message translates to:
  /// **'Share this night'**
  String get nightReportShare;

  /// Paylaşım sürerken buton etiketi
  ///
  /// In en, this message translates to:
  /// **'Sharing…'**
  String get nightReportSharing;

  /// Paylaşım kartı yokken (404) bilgilendirme
  ///
  /// In en, this message translates to:
  /// **'No report for this night'**
  String get nightReportNoShareCard;

  /// Paylaşım başarılı (interim: panoya kopyalanır)
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get shareLinkCopied;

  /// Home ekranı alt başlığı (marka sözü)
  ///
  /// In en, this message translates to:
  /// **'Your night has an identity'**
  String get homeTagline;

  /// Kimlik kartı üst etiketi
  ///
  /// In en, this message translates to:
  /// **'Your sleep identity'**
  String get homeIdentityCardLabel;

  /// Kimlik gecmisi baglantisi; yalnizca 2+ sonucta gosterilir
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{{count} identities over time}}'**
  String homeIdentityHistoryLink(int count);

  /// Streak etiketi. COGUL ICU ile: Ingilizce -s mantigi koda gomulemez (TR'de calismaz)
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{night streak} other{nights streak}}'**
  String homeStreakLabel(int count);

  /// Kisisel rekor (en uzun seri); yalnizca guncelden buyukse
  ///
  /// In en, this message translates to:
  /// **'Best {count}'**
  String homeStreakBest(int count);

  /// Haftalik yayin karti ust etiketi
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get homeWeeklyLabel;

  /// Haftalik yayin notu yoksa yedek metin. COGUL ICU ile.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 soundscape this week} other{{count} soundscapes this week}}'**
  String homeWeeklyCount(int count);

  /// Henuz test yapilmamisken ana CTA
  ///
  /// In en, this message translates to:
  /// **'Find your sleep identity'**
  String get homeFindIdentity;

  /// Sonuc varken ana CTA
  ///
  /// In en, this message translates to:
  /// **'Retake the test'**
  String get homeRetakeTest;

  /// Kutuphaneye git
  ///
  /// In en, this message translates to:
  /// **'Browse soundscapes'**
  String get homeBrowseSoundscapes;

  /// Uyku gecmisi ekrani basligi / home butonu
  ///
  /// In en, this message translates to:
  /// **'Sleep history'**
  String get sleepHistoryTitle;

  /// Ayarlar ekrani basligi / home butonu
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Ayarlar bolum basligi
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotificationsSection;

  /// Ayarlar üyelik/premium bölüm başlığı
  ///
  /// In en, this message translates to:
  /// **'Membership'**
  String get settingsMembershipSection;

  /// Kullanıcı premium olduğunda; SAĞLIK İDDİASI DEĞİL, sadece özellik erişimi
  ///
  /// In en, this message translates to:
  /// **'Premium — all features unlocked'**
  String get membershipPremium;

  /// Kullanıcı ücretsiz katmandayken
  ///
  /// In en, this message translates to:
  /// **'Free plan'**
  String get membershipFree;

  /// Paywall ekranı başlığı
  ///
  /// In en, this message translates to:
  /// **'NOCTA Premium'**
  String get paywallTitle;

  /// Paywall alt başlığı — SAĞLIK İDDİASI DEĞİL, 'ritual' konumlandırması (§1.1)
  ///
  /// In en, this message translates to:
  /// **'More from your sleep ritual.'**
  String get paywallTagline;

  /// Premium fayda: haftalık trend grafiği
  ///
  /// In en, this message translates to:
  /// **'Weekly sleep trends'**
  String get paywallBenefitTrends;

  /// Premium fayda: gelecek özellikler (dürüst — bugün yalnız trend gated)
  ///
  /// In en, this message translates to:
  /// **'More premium features on the way'**
  String get paywallBenefitMore;

  /// Paywall ana buton — gerçek IAP en son faz, şimdilik 'yakında'
  ///
  /// In en, this message translates to:
  /// **'Get Premium'**
  String get paywallCta;

  /// CTA'ya basınca — satın alma henüz yok (§6)
  ///
  /// In en, this message translates to:
  /// **'Premium is coming soon.'**
  String get paywallComingSoon;

  /// Paywall'ı kapat
  ///
  /// In en, this message translates to:
  /// **'Maybe later'**
  String get paywallLater;

  /// Free kullanıcıya trend yerine gösterilen kilit metni
  ///
  /// In en, this message translates to:
  /// **'Weekly trends are a Premium feature.'**
  String get trendLockText;

  /// Kilit CTA'sı — paywall'ı açar
  ///
  /// In en, this message translates to:
  /// **'Unlock with Premium'**
  String get trendLockCta;

  /// Bildirim ac/kapa anahtari etiketi
  ///
  /// In en, this message translates to:
  /// **'Push notifications'**
  String get settingsPushNotifications;

  /// Bildirim tercihi PATCH hatasi
  ///
  /// In en, this message translates to:
  /// **'Could not update notification setting'**
  String get settingsNotificationsUpdateFailed;

  /// Ayarlar bolum basligi
  ///
  /// In en, this message translates to:
  /// **'Account security'**
  String get settingsAccountSecuritySection;

  /// Aktif oturum sayisi
  ///
  /// In en, this message translates to:
  /// **'Active devices: {count}'**
  String settingsActiveDevices(int count);

  /// Diger cihazlardan cikis butonu
  ///
  /// In en, this message translates to:
  /// **'Log out other devices'**
  String get settingsLogOutOthers;

  /// Cikis islemi surerken buton etiketi
  ///
  /// In en, this message translates to:
  /// **'Signing out…'**
  String get settingsSigningOut;

  /// Cikis sonucu. COGUL ICU ile: eski kod elle -s ekliyordu, TR'de yanlis olurdu.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 other device signed out} other{{count} other devices signed out}}'**
  String settingsDevicesSignedOut(int count);

  /// Diger cihazlardan cikis hatasi
  ///
  /// In en, this message translates to:
  /// **'Could not sign out other devices'**
  String get settingsSignOutOthersFailed;

  /// Archetype testi ekrani basligi
  ///
  /// In en, this message translates to:
  /// **'Sleep Identity Test'**
  String get archetypeTestTitle;

  /// Cevaplar gonderilirken buton etiketi
  ///
  /// In en, this message translates to:
  /// **'Scoring…'**
  String get archetypeTestScoring;

  /// Testi bitirme butonu
  ///
  /// In en, this message translates to:
  /// **'See my result'**
  String get archetypeTestSeeResult;

  /// Sonuc kartinin ustundeki etiket
  ///
  /// In en, this message translates to:
  /// **'Your sleep identity'**
  String get archetypeYourSleepIdentity;

  /// Test sihirbazi ust bilgi metni
  ///
  /// In en, this message translates to:
  /// **'There are no right answers. Pick whichever feels closest to your nights.'**
  String get archetypeTestIntro;

  /// Kac sorudan kaci cevaplandi gostergesi
  ///
  /// In en, this message translates to:
  /// **'{answered} of {total} answered'**
  String archetypeTestProgress(int answered, int total);

  /// Sorular yuklenirken gosterilen metin
  ///
  /// In en, this message translates to:
  /// **'Preparing your questions…'**
  String get archetypeTestPreparing;

  /// Paylasim linki panoya kopyalandi bildirimi
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get archetypeShareCopied;

  /// Paylasim basarisiz bildirimi
  ///
  /// In en, this message translates to:
  /// **'Could not share'**
  String get archetypeShareFailed;

  /// Archetype karti paylasim butonu (viral kanca #1)
  ///
  /// In en, this message translates to:
  /// **'Share my identity'**
  String get archetypeShareButton;

  /// Archetype paylasimi surerken buton etiketi
  ///
  /// In en, this message translates to:
  /// **'Sharing…'**
  String get archetypeShareSharing;

  /// Sonuc ekraninda testi tekrarla
  ///
  /// In en, this message translates to:
  /// **'Retake test'**
  String get archetypeRetakeTest;

  /// Archetype detay ekrani basligi
  ///
  /// In en, this message translates to:
  /// **'Sleep identity'**
  String get archetypeDetailTitle;

  /// Bilinmeyen slug icin detay ekrani
  ///
  /// In en, this message translates to:
  /// **'Unknown identity'**
  String get archetypeUnknown;

  /// Detayda uygun sesler bolum basligi
  ///
  /// In en, this message translates to:
  /// **'Sounds that suit you'**
  String get archetypeSoundsThatSuitYou;

  /// Kimlik gecmisi ekrani basligi
  ///
  /// In en, this message translates to:
  /// **'Your identity over time'**
  String get identityHistoryTitle;

  /// Hic test yapilmamisken bos durum
  ///
  /// In en, this message translates to:
  /// **'No test results yet'**
  String get identityHistoryEmpty;

  /// En yeni sonuc rozeti
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get identityHistoryCurrent;

  /// Soundscape kutuphanesi ekrani basligi
  ///
  /// In en, this message translates to:
  /// **'Soundscapes'**
  String get libraryTitle;

  /// Feed bosken
  ///
  /// In en, this message translates to:
  /// **'No soundscapes yet'**
  String get libraryEmpty;

  /// Soundscape hangi uyku kimligine uygun (archetype adlari)
  ///
  /// In en, this message translates to:
  /// **'For {names}'**
  String libraryAffinity(String names);

  /// Soundscape detay ekrani basligi
  ///
  /// In en, this message translates to:
  /// **'Soundscape'**
  String get soundscapeDetailTitle;

  /// Yayinlanmamis/olmayan soundscape
  ///
  /// In en, this message translates to:
  /// **'Soundscape not found'**
  String get soundscapeNotFound;

  /// Onizleme URL'i varken bilgi
  ///
  /// In en, this message translates to:
  /// **'Preview available'**
  String get soundscapePreviewAvailable;

  /// Uyku gecmisi ust bilgisi. COGUL ICU ile (kodda -s eklenemez).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 night · avg {avg}} other{{count} nights · avg {avg}}}'**
  String sleepHistoryStats(int count, String avg);

  /// Hic uyku kaydi yokken bos durum
  ///
  /// In en, this message translates to:
  /// **'No sleep recorded yet'**
  String get sleepHistoryEmpty;

  /// Paylaşım hatası
  ///
  /// In en, this message translates to:
  /// **'Could not share'**
  String get shareFailed;

  /// Karşılama akışını atla
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingSkip;

  /// Karşılama akışında sonraki sayfa
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboardingNext;

  /// Karşılama akışını bitir ve uygulamaya gir
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get onboardingStart;

  /// Karşılama 1 — kimlik
  ///
  /// In en, this message translates to:
  /// **'Your night has an identity'**
  String get onboardingIdentityTitle;

  /// Karşılama 1 gövde
  ///
  /// In en, this message translates to:
  /// **'Take the free sleep archetype test and see how your nights actually work. No account needed.'**
  String get onboardingIdentityBody;

  /// Karşılama 2 — ritüel/ses
  ///
  /// In en, this message translates to:
  /// **'Build your night ritual'**
  String get onboardingRitualTitle;

  /// Karşılama 2 gövde
  ///
  /// In en, this message translates to:
  /// **'Mix generative soundscapes yourself — rain, drones, soft noise. Everything is created on your phone and works offline.'**
  String get onboardingRitualBody;

  /// Karşılama 3 — alarm + mikrofon izni priming
  ///
  /// In en, this message translates to:
  /// **'Wake up gently'**
  String get onboardingAlarmTitle;

  /// Karşılama 3 gövde — gizlilik açıkça belirtilir (§6)
  ///
  /// In en, this message translates to:
  /// **'With your permission, NOCTA listens for lighter sleep to time your alarm. The analysis happens on your phone — raw audio never leaves it.'**
  String get onboardingAlarmBody;

  /// Ana ekran birincil eylem bolumunun etiketi
  ///
  /// In en, this message translates to:
  /// **'Tonight'**
  String get homeTonightLabel;

  /// Ana ekranin tek display basligi; ritual dili, saglik iddiasi yok
  ///
  /// In en, this message translates to:
  /// **'Start your night ritual'**
  String get homeRitualTitle;

  /// Ritualin ne oldugu + cevrimdisi calistigi; ozellik tarifi
  ///
  /// In en, this message translates to:
  /// **'Sound, and a gentler wake-up. Works with no connection.'**
  String get homeRitualSubtitle;

  /// Birincil buton etiketi -> /sleep-mode
  ///
  /// In en, this message translates to:
  /// **'Start tonight'**
  String get homeStartRitual;

  /// Test yapilmamisken davet karti govdesi
  ///
  /// In en, this message translates to:
  /// **'Two minutes, no account. Turn your nights into a card you can share.'**
  String get homeIdentityInviteBody;

  /// Ikincil navigasyon rafinin bolum etiketi
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get homeSectionExplore;

  /// Acilis aurasi anahtari
  ///
  /// In en, this message translates to:
  /// **'Opening sound'**
  String get settingsSignatureSound;

  /// Acilis sesi aciklamasi
  ///
  /// In en, this message translates to:
  /// **'A short ambience when the app opens.'**
  String get settingsSignatureSoundHint;

  /// Ayarlar ses bolumu basligi
  ///
  /// In en, this message translates to:
  /// **'Sound'**
  String get settingsSoundSection;

  /// Genel veri yukleme hatasi metni
  ///
  /// In en, this message translates to:
  /// **'Could not load this. Check your connection and try again.'**
  String get loadFailed;

  /// Ayarlar dil bolumu basligi
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguageSection;

  /// Cihaz dilini kullan
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsLanguageSystem;

  /// Ingilizce secenegi
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// Turkce secenegi (kendi dilinde yazilir)
  ///
  /// In en, this message translates to:
  /// **'Türkçe'**
  String get settingsLanguageTurkish;

  /// Soundscape detayinda birincil eylem: mikseri bu tarifle acar
  ///
  /// In en, this message translates to:
  /// **'Play this sound'**
  String get soundscapePlay;

  /// Slug cozulemedi, mikser varsayilan tarifle acildi
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t load this sound\'s recipe, so your default mix is playing.'**
  String get mixerRecipeUnavailable;
}

class _AppL10nDelegate extends LocalizationsDelegate<AppL10n> {
  const _AppL10nDelegate();

  @override
  Future<AppL10n> load(Locale locale) {
    return SynchronousFuture<AppL10n>(lookupAppL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppL10nDelegate old) => false;
}

AppL10n lookupAppL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppL10nEn();
    case 'tr':
      return AppL10nTr();
  }

  throw FlutterError(
    'AppL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
