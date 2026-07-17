// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppL10nEn extends AppL10n {
  AppL10nEn([String locale = 'en']) : super(locale);

  @override
  String get shareIdentityCta => 'Share your identity';

  @override
  String get sharePreparing => 'Preparing…';

  @override
  String shareIdentityText(String name) {
    return 'My sleep identity is $name.';
  }

  @override
  String get sleepModeTitle => 'Sleep mode';

  @override
  String get sleepModeStart => 'Start the night';

  @override
  String get sleepModeStop => 'End the night';

  @override
  String get sleepModeRecording => 'Listening…';

  @override
  String sleepModeEvents(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sounds so far',
      one: '1 sound so far',
      zero: 'No sounds yet',
    );
    return '$_temp0';
  }

  @override
  String get sleepModePrivacy =>
      'Audio is analysed on your phone and never leaves it. Only the time and a count are saved.';

  @override
  String get sleepModePermissionDenied =>
      'Microphone access is needed to listen to your night.';

  @override
  String sleepModeSaved(int hours, int minutes) {
    return 'Night saved: ${hours}h ${minutes}m';
  }

  @override
  String get sleepModeSaveFailed =>
      'Saved on your phone, but could not reach the server.';

  @override
  String get homeSleepMode => 'Sleep mode';

  @override
  String get offlineBanner => 'Offline — some features need a connection';

  @override
  String get offlineRetry => 'Retry';

  @override
  String get homeOpenMixer => 'Open mixer';

  @override
  String get mixerTitle => 'Mixer';

  @override
  String get mixerPlay => 'Play';

  @override
  String get mixerPause => 'Pause';

  @override
  String get mixerPreparing => 'Preparing sound…';

  @override
  String get mixerLayerWhite => 'White noise';

  @override
  String get mixerLayerPink => 'Pink noise';

  @override
  String get mixerLayerBrown => 'Brown noise';

  @override
  String mixerGainPercent(int percent) {
    return '$percent%';
  }

  @override
  String get mixerStopgapNotice =>
      'Early build: generated locally, looped. Sound quality is not final.';

  @override
  String get mixerFailed => 'Sound could not start.';

  @override
  String get nightReportTitle => 'Night report';

  @override
  String get nightReportEmpty => 'No sleep recorded for this night';

  @override
  String nightReportCalm(int score) {
    return 'Calm $score/100';
  }

  @override
  String get nightReportCalmDisclaimer =>
      'An in-app calm measure for your ritual — not a health score.';

  @override
  String get nightReportSessions => 'Sessions';

  @override
  String get nightReportMovementEvents => 'Movement events';

  @override
  String get nightReportSoundEvents => 'Sound events';

  @override
  String get nightReportShare => 'Share this night';

  @override
  String get nightReportSharing => 'Sharing…';

  @override
  String get nightReportNoShareCard => 'No report for this night';

  @override
  String get shareLinkCopied => 'Link copied';

  @override
  String get homeTagline => 'Your night has an identity';

  @override
  String get homeIdentityCardLabel => 'Your sleep identity';

  @override
  String homeIdentityHistoryLink(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count identities over time',
    );
    return '$_temp0';
  }

  @override
  String homeStreakLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'nights streak',
      one: 'night streak',
    );
    return '$_temp0';
  }

  @override
  String homeStreakBest(int count) {
    return 'Best $count';
  }

  @override
  String get homeWeeklyLabel => 'This week';

  @override
  String homeWeeklyCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count soundscapes this week',
      one: '1 soundscape this week',
    );
    return '$_temp0';
  }

  @override
  String get homeFindIdentity => 'Find your sleep identity';

  @override
  String get homeRetakeTest => 'Retake the test';

  @override
  String get homeBrowseSoundscapes => 'Browse soundscapes';

  @override
  String get sleepHistoryTitle => 'Sleep history';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsNotificationsSection => 'Notifications';

  @override
  String get settingsPushNotifications => 'Push notifications';

  @override
  String get settingsNotificationsUpdateFailed =>
      'Could not update notification setting';

  @override
  String get settingsAccountSecuritySection => 'Account security';

  @override
  String settingsActiveDevices(int count) {
    return 'Active devices: $count';
  }

  @override
  String get settingsLogOutOthers => 'Log out other devices';

  @override
  String get settingsSigningOut => 'Signing out…';

  @override
  String settingsDevicesSignedOut(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count other devices signed out',
      one: '1 other device signed out',
    );
    return '$_temp0';
  }

  @override
  String get settingsSignOutOthersFailed => 'Could not sign out other devices';

  @override
  String get archetypeTestTitle => 'Sleep Identity Test';

  @override
  String get archetypeTestScoring => 'Scoring…';

  @override
  String get archetypeTestSeeResult => 'See my result';

  @override
  String get archetypeYourSleepIdentity => 'Your sleep identity';

  @override
  String get archetypeShareCopied => 'Link copied';

  @override
  String get archetypeShareFailed => 'Could not share';

  @override
  String get archetypeShareButton => 'Share my identity';

  @override
  String get archetypeShareSharing => 'Sharing…';

  @override
  String get archetypeRetakeTest => 'Retake test';

  @override
  String get archetypeDetailTitle => 'Sleep identity';

  @override
  String get archetypeUnknown => 'Unknown identity';

  @override
  String get archetypeSoundsThatSuitYou => 'Sounds that suit you';

  @override
  String get identityHistoryTitle => 'Your identity over time';

  @override
  String get identityHistoryEmpty => 'No test results yet';

  @override
  String get identityHistoryCurrent => 'Current';

  @override
  String get libraryTitle => 'Soundscapes';

  @override
  String get libraryEmpty => 'No soundscapes yet';

  @override
  String libraryAffinity(String names) {
    return 'For $names';
  }

  @override
  String get soundscapeDetailTitle => 'Soundscape';

  @override
  String get soundscapeNotFound => 'Soundscape not found';

  @override
  String get soundscapePreviewAvailable => 'Preview available';

  @override
  String sleepHistoryStats(int count, String avg) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nights · avg $avg',
      one: '1 night · avg $avg',
    );
    return '$_temp0';
  }

  @override
  String get sleepHistoryEmpty => 'No sleep recorded yet';

  @override
  String get shareFailed => 'Could not share';
}
