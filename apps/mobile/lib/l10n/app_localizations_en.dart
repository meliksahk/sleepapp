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
  String get shareFailed => 'Could not share';
}
