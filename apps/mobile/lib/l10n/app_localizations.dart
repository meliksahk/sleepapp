import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

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
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

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

  /// On-device türetilmiş hareket olayı sayısı
  ///
  /// In en, this message translates to:
  /// **'Movement events'**
  String get nightReportMovementEvents;

  /// On-device türetilmiş ses olayı sayısı
  ///
  /// In en, this message translates to:
  /// **'Sound events'**
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

  /// Paylaşım hatası
  ///
  /// In en, this message translates to:
  /// **'Could not share'**
  String get shareFailed;
}

class _AppL10nDelegate extends LocalizationsDelegate<AppL10n> {
  const _AppL10nDelegate();

  @override
  Future<AppL10n> load(Locale locale) {
    return SynchronousFuture<AppL10n>(lookupAppL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppL10nDelegate old) => false;
}

AppL10n lookupAppL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppL10nEn();
  }

  throw FlutterError(
    'AppL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
