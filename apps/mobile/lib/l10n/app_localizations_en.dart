// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppL10nEn extends AppL10n {
  AppL10nEn([String locale = 'en']) : super(locale);

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
  String get shareFailed => 'Could not share';
}
