// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppL10nTr extends AppL10n {
  AppL10nTr([String locale = 'tr']) : super(locale);

  @override
  String get shareIdentityCta => 'Kimliğini paylaş';

  @override
  String get sharePreparing => 'Hazırlanıyor…';

  @override
  String shareIdentityText(String name) {
    return 'Uyku kimliğim: $name.';
  }

  @override
  String get sleepModeNotificationTitle => 'Geceni dinliyor';

  @override
  String get sleepModeNotificationBody =>
      'Telefonunda analiz ediliyor. Açmak için dokun.';

  @override
  String get sleepModeServiceFailed =>
      'Arka planda dinlemeye devam edilemedi. Gecen kaydedilemezdi.';

  @override
  String get sleepModeExportEnvelope => 'Gece tanılamalarını paylaş';

  @override
  String get sleepModeExportHint =>
      'Saniye saniye ses düzeyi özeti — kayıt değil. Algılamayı ayarlamamıza yardım eder.';

  @override
  String get sleepModeTitle => 'Uyku modu';

  @override
  String get sleepModeStart => 'Geceyi başlat';

  @override
  String get sleepModeStop => 'Geceyi bitir';

  @override
  String get sleepModeRecording => 'Dinliyor…';

  @override
  String sleepModeEvents(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Şu ana kadar $count ses',
      one: 'Şu ana kadar 1 ses',
      zero: 'Henüz ses yok',
    );
    return '$_temp0';
  }

  @override
  String get sleepModePrivacy =>
      'Ses telefonunda analiz edilir ve telefondan asla çıkmaz. Yalnızca süre ve bir sayı kaydedilir.';

  @override
  String get sleepModePermissionDenied =>
      'Geceni dinlemek için mikrofon erişimi gerekiyor.';

  @override
  String sleepModeSaved(int hours, int minutes) {
    return 'Gece kaydedildi: ${hours}sa ${minutes}dk';
  }

  @override
  String get sleepModeSaveFailed =>
      'Telefonuna kaydedildi ama sunucuya ulaşılamadı.';

  @override
  String get homeSleepMode => 'Uyku modu';

  @override
  String get offlineBanner =>
      'Çevrimdışı — bazı özellikler bağlantı gerektirir';

  @override
  String get offlineRetry => 'Yeniden dene';

  @override
  String get homeOpenMixer => 'Mikseri aç';

  @override
  String get mixerTitle => 'Mikser';

  @override
  String get mixerPlay => 'Çal';

  @override
  String get mixerPause => 'Duraklat';

  @override
  String get mixerPreparing => 'Ses hazırlanıyor…';

  @override
  String get mixerLayerWhite => 'Beyaz gürültü';

  @override
  String get mixerLayerPink => 'Pembe gürültü';

  @override
  String get mixerLayerBrown => 'Kahverengi gürültü';

  @override
  String mixerGainPercent(int percent) {
    return '%$percent';
  }

  @override
  String get mixerStopgapNotice =>
      'Erken sürüm: yerelde üretilip döngüleniyor. Ses kalitesi nihai değil.';

  @override
  String get mixerFailed => 'Ses başlatılamadı.';

  @override
  String get mixerExportVideo => 'Video olarak paylaş';

  @override
  String mixerExporting(int percent) {
    return 'Video oluşturuluyor… %$percent';
  }

  @override
  String get mixerExportFailed => 'Video oluşturulamadı.';

  @override
  String get mixerExportShareText => 'Uyku miksim — NOCTA ile yapıldı';

  @override
  String get mixerVideoTitle => 'Bu gecenin miksi';

  @override
  String get alarmSectionTitle => 'Akıllı alarm';

  @override
  String get alarmOff => 'Kapalı';

  @override
  String alarmSet(String time) {
    return 'Beni en geç $time uyandır';
  }

  @override
  String alarmExplain(int minutes) {
    return 'Öncesindeki $minutes dakikada daha hafif bir an arayacağız ve en geç o zaman seni uyandıracağız.';
  }

  @override
  String get alarmChoose => 'Alarm kur';

  @override
  String get alarmClear => 'Kapat';

  @override
  String get alarmRingingLightSleep => 'Kıpırdandın — uyanmak için iyi bir an.';

  @override
  String get alarmRingingDeadline => 'Uyanma zamanı.';

  @override
  String get alarmDismiss => 'Alarmı durdur';

  @override
  String get reportCardHeader => 'Gece makbuzu';

  @override
  String reportCardDuration(int hours, int minutes) {
    return '${hours}sa ${minutes}dk';
  }

  @override
  String get reportCardCalm => 'Dinginlik';

  @override
  String get reportCardLoud => 'Yüksek anlar';

  @override
  String get reportCardStreak => 'Gece serisi';

  @override
  String get reportCardIdentity => 'Kimlik';

  @override
  String get reportCardDisclaimer =>
      'Uyku ritüelin için uygulama içi bir dinginlik ölçüsü. Sağlık skoru değil.';

  @override
  String get reportShareText => 'NOCTA’daki gecem';

  @override
  String get nightReportTitle => 'Gece raporu';

  @override
  String get nightReportEmpty => 'Bu gece için uyku kaydı yok';

  @override
  String nightReportCalm(int score) {
    return 'Dinginlik $score/100';
  }

  @override
  String get nightReportCalmDisclaimer =>
      'Ritüelin için uygulama içi bir dinginlik ölçüsü — sağlık skoru değil.';

  @override
  String get nightReportSessions => 'Oturumlar';

  @override
  String get nightReportLoudHint =>
      'Uygulamanın duyduğu kısa ses patlamaları. Hareket değil — onu ölçmüyoruz.';

  @override
  String get nightReportMovementEvents => 'Hareket olayları';

  @override
  String get nightReportSoundEvents => 'Yüksek anlar';

  @override
  String get nightReportShare => 'Bu geceyi paylaş';

  @override
  String get nightReportSharing => 'Paylaşılıyor…';

  @override
  String get nightReportNoShareCard => 'Bu gece için rapor yok';

  @override
  String get shareLinkCopied => 'Bağlantı kopyalandı';

  @override
  String get homeTagline => 'Gecenin bir kimliği var';

  @override
  String get homeIdentityCardLabel => 'Uyku kimliğin';

  @override
  String homeIdentityHistoryLink(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Zaman içinde $count kimlik',
    );
    return '$_temp0';
  }

  @override
  String homeStreakLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'gece serisi',
      one: 'gece serisi',
    );
    return '$_temp0';
  }

  @override
  String homeStreakBest(int count) {
    return 'En iyi $count';
  }

  @override
  String get homeWeeklyLabel => 'Bu hafta';

  @override
  String homeWeeklyCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Bu hafta $count soundscape',
      one: 'Bu hafta 1 soundscape',
    );
    return '$_temp0';
  }

  @override
  String get homeFindIdentity => 'Uyku kimliğini keşfet';

  @override
  String get homeRetakeTest => 'Testi tekrar yap';

  @override
  String get homeBrowseSoundscapes => 'Soundscape’lere göz at';

  @override
  String get sleepHistoryTitle => 'Uyku geçmişi';

  @override
  String get settingsTitle => 'Ayarlar';

  @override
  String get settingsNotificationsSection => 'Bildirimler';

  @override
  String get settingsMembershipSection => 'Üyelik';

  @override
  String get membershipPremium => 'Premium — tüm özellikler açık';

  @override
  String get membershipFree => 'Ücretsiz plan';

  @override
  String get paywallTitle => 'NOCTA Premium';

  @override
  String get paywallTagline => 'Uyku ritüelinden daha fazlası.';

  @override
  String get paywallBenefitTrends => 'Haftalık uyku trendleri';

  @override
  String get paywallBenefitMore => 'Daha fazla premium özellik yolda';

  @override
  String get paywallCta => 'Premium\'a geç';

  @override
  String get paywallComingSoon => 'Premium çok yakında.';

  @override
  String get paywallLater => 'Belki sonra';

  @override
  String get trendLockText => 'Haftalık trendler bir Premium özelliği.';

  @override
  String get trendLockCta => 'Premium ile aç';

  @override
  String get settingsPushNotifications => 'Anlık bildirimler';

  @override
  String get settingsNotificationsUpdateFailed =>
      'Bildirim ayarı güncellenemedi';

  @override
  String get settingsAccountSecuritySection => 'Hesap güvenliği';

  @override
  String settingsActiveDevices(int count) {
    return 'Etkin cihazlar: $count';
  }

  @override
  String get settingsLogOutOthers => 'Diğer cihazlardan çık';

  @override
  String get settingsSigningOut => 'Çıkış yapılıyor…';

  @override
  String settingsDevicesSignedOut(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count diğer cihazın oturumu kapatıldı',
      one: '1 diğer cihazın oturumu kapatıldı',
    );
    return '$_temp0';
  }

  @override
  String get settingsSignOutOthersFailed =>
      'Diğer cihazlardan çıkış yapılamadı';

  @override
  String get archetypeTestTitle => 'Uyku Kimliği Testi';

  @override
  String get archetypeTestScoring => 'Puanlanıyor…';

  @override
  String get archetypeTestSeeResult => 'Sonucumu gör';

  @override
  String get archetypeYourSleepIdentity => 'Uyku kimliğin';

  @override
  String get archetypeTestIntro =>
      'Doğru cevap yok. Gecelerine en yakın geleni seç.';

  @override
  String archetypeTestProgress(int answered, int total) {
    return '$total sorudan $answered tanesi cevaplandı';
  }

  @override
  String get archetypeTestPreparing => 'Soruların hazırlanıyor…';

  @override
  String get archetypeShareCopied => 'Bağlantı kopyalandı';

  @override
  String get archetypeShareFailed => 'Paylaşılamadı';

  @override
  String get archetypeShareButton => 'Kimliğimi paylaş';

  @override
  String get archetypeShareSharing => 'Paylaşılıyor…';

  @override
  String get archetypeRetakeTest => 'Testi tekrar yap';

  @override
  String get archetypeDetailTitle => 'Uyku kimliği';

  @override
  String get archetypeUnknown => 'Bilinmeyen kimlik';

  @override
  String get archetypeSoundsThatSuitYou => 'Sana uygun sesler';

  @override
  String get identityHistoryTitle => 'Zaman içinde kimliğin';

  @override
  String get identityHistoryEmpty => 'Henüz test sonucu yok';

  @override
  String get identityHistoryCurrent => 'Güncel';

  @override
  String get libraryTitle => 'Soundscape’ler';

  @override
  String get libraryEmpty => 'Henüz soundscape yok';

  @override
  String libraryAffinity(String names) {
    return '$names için';
  }

  @override
  String get soundscapeDetailTitle => 'Soundscape';

  @override
  String get soundscapeNotFound => 'Soundscape bulunamadı';

  @override
  String get soundscapePreviewAvailable => 'Önizleme mevcut';

  @override
  String sleepHistoryStats(int count, String avg) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count gece · ort $avg',
      one: '1 gece · ort $avg',
    );
    return '$_temp0';
  }

  @override
  String get sleepHistoryEmpty => 'Henüz uyku kaydı yok';

  @override
  String get shareFailed => 'Paylaşılamadı';

  @override
  String get onboardingSkip => 'Atla';

  @override
  String get onboardingNext => 'Devam';

  @override
  String get onboardingStart => 'Başla';

  @override
  String get onboardingIdentityTitle => 'Gecenin bir kimliği var';

  @override
  String get onboardingIdentityBody =>
      'Ücretsiz uyku arketipi testini çöz, gecelerinin gerçekte nasıl işlediğini gör. Hesap gerekmez.';

  @override
  String get onboardingRitualTitle => 'Gece ritüelini kur';

  @override
  String get onboardingRitualBody =>
      'Jeneratif sesleri kendin miksle — yağmur, drone, yumuşak gürültü. Her şey telefonunda üretilir ve internetsiz çalışır.';

  @override
  String get onboardingAlarmTitle => 'Nazikçe uyan';

  @override
  String get onboardingAlarmBody =>
      'İzin verirsen NOCTA alarmı zamanlamak için hafif uykuyu dinler. Analiz telefonunda yapılır — ham ses hiçbir yere gitmez.';

  @override
  String get homeTonightLabel => 'Bu gece';

  @override
  String get homeRitualTitle => 'Gece ritüelini başlat';

  @override
  String get homeRitualSubtitle =>
      'Ses ve daha yumuşak bir uyanış. Bağlantı gerekmez.';

  @override
  String get homeStartRitual => 'Bu geceyi başlat';

  @override
  String get homeIdentityInviteBody =>
      'İki dakika, hesap gerekmez. Gecelerini paylaşabileceğin bir karta dönüştür.';

  @override
  String get homeSectionExplore => 'Keşfet';

  @override
  String get settingsSignatureSound => 'Açılış sesi';

  @override
  String get settingsSignatureSoundHint =>
      'Uygulama açılırken kısa bir atmosfer.';

  @override
  String get settingsSoundSection => 'Ses';

  @override
  String get loadFailed =>
      'Bu yüklenemedi. Bağlantını kontrol edip tekrar dene.';

  @override
  String get settingsLanguageSection => 'Dil';

  @override
  String get settingsLanguageSystem => 'Sistem';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageTurkish => 'Türkçe';
}
