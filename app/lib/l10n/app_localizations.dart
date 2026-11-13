import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_nb.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
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
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

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
    Locale('nb'),
  ];

  /// No description provided for @tabFeed.
  ///
  /// In en, this message translates to:
  /// **'Feed'**
  String get tabFeed;

  /// No description provided for @tabHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get tabHistory;

  /// No description provided for @tabCv.
  ///
  /// In en, this message translates to:
  /// **'CV'**
  String get tabCv;

  /// No description provided for @tabTraining.
  ///
  /// In en, this message translates to:
  /// **'Training'**
  String get tabTraining;

  /// Label of the centre button in the tab bar and of empty-state actions.
  ///
  /// In en, this message translates to:
  /// **'Log a session'**
  String get logButton;

  /// No description provided for @feedEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your sessions show up here'**
  String get feedEmptyTitle;

  /// No description provided for @feedEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Log your first session and it appears in your feed. Friends\' sessions join it later.'**
  String get feedEmptyBody;

  /// No description provided for @feedOpenSession.
  ///
  /// In en, this message translates to:
  /// **'Open session'**
  String get feedOpenSession;

  /// Where a session was, when its climbs have no crag.
  ///
  /// In en, this message translates to:
  /// **'{setting, select, outdoor{Outdoors} indoor{Indoors} other{}}'**
  String feedSetting(String setting);

  /// After the day on a feed card, such as '17 Oct 2026 · with Kari'.
  ///
  /// In en, this message translates to:
  /// **'with {names}'**
  String feedWith(String names);

  /// No description provided for @feedMoreClimbs.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{+1 more climb} other{+{count} more climbs}}'**
  String feedMoreClimbs(int count);

  /// No description provided for @feedStatPitches.
  ///
  /// In en, this message translates to:
  /// **'Pitches'**
  String get feedStatPitches;

  /// Under the metres climbed in a session.
  ///
  /// In en, this message translates to:
  /// **'Climbed'**
  String get feedStatClimbed;

  /// No description provided for @feedStatElevation.
  ///
  /// In en, this message translates to:
  /// **'Elevation gain'**
  String get feedStatElevation;

  /// Unit after a number of metres in a stat.
  ///
  /// In en, this message translates to:
  /// **'m'**
  String get feedStatMetres;

  /// No description provided for @historyTitle.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get historyTitle;

  /// No description provided for @historyEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your history starts with one session'**
  String get historyEmptyTitle;

  /// No description provided for @historyEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Days out, grades, pyramids and insights fill in as you log.'**
  String get historyEmptyBody;

  /// No description provided for @cvTitle.
  ///
  /// In en, this message translates to:
  /// **'Climbing CV'**
  String get cvTitle;

  /// No description provided for @cvEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your CV builds itself'**
  String get cvEmptyTitle;

  /// No description provided for @cvEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Every climb you log adds to your levels and experience, and shows what you have not tried yet.'**
  String get cvEmptyBody;

  /// No description provided for @settingsOpen.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsOpen;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// Midnight sun and Daylight are the names of Sva's dark and light themes.
  ///
  /// In en, this message translates to:
  /// **'{theme, select, system{Follow the phone} midnight{Midnight sun} daylight{Daylight} other{}}'**
  String settingsThemeOption(String theme);

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow the phone'**
  String get settingsLanguageSystem;

  /// Always written in Norwegian, so Norwegian speakers find it.
  ///
  /// In en, this message translates to:
  /// **'Norsk (bokmål)'**
  String get settingsLanguageNb;

  /// Always written in English, so English speakers find it.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLanguageEn;

  /// No description provided for @settingsGrades.
  ///
  /// In en, this message translates to:
  /// **'Grades'**
  String get settingsGrades;

  /// No description provided for @settingsGradesNote.
  ///
  /// In en, this message translates to:
  /// **'Grades show in these systems. What you logged is kept as you logged it.'**
  String get settingsGradesNote;

  /// No description provided for @settingsGradeType.
  ///
  /// In en, this message translates to:
  /// **'{type, select, free_route{Routes} boulder{Boulders} ice{Ice} mixed{Mixed} aid{Aid} alpine{Alpine} other{}}'**
  String settingsGradeType(String type);

  /// No description provided for @gradeSystemName.
  ///
  /// In en, this message translates to:
  /// **'{system, select, nor{Norwegian} french{French} yds{YDS} uiaa{UIAA} font{Font} v{V scale} other{}}'**
  String gradeSystemName(String system);

  /// No description provided for @settingsVisibility.
  ///
  /// In en, this message translates to:
  /// **'New sessions are visible to'**
  String get settingsVisibility;

  /// No description provided for @settingsVisibilityOption.
  ///
  /// In en, this message translates to:
  /// **'{visibility, select, private{Only you} friends{Friends} public{Everyone} other{}}'**
  String settingsVisibilityOption(String visibility);

  /// No description provided for @settingsVisibilityNote.
  ///
  /// In en, this message translates to:
  /// **'Nothing leaves this phone until you sign in.'**
  String get settingsVisibilityNote;

  /// No description provided for @settingsGyms.
  ///
  /// In en, this message translates to:
  /// **'Gyms'**
  String get settingsGyms;

  /// No description provided for @settingsGymsNote.
  ///
  /// In en, this message translates to:
  /// **'Set up the gyms you climb in once, so logging there is quick.'**
  String get settingsGymsNote;

  /// No description provided for @settingsGymAdd.
  ///
  /// In en, this message translates to:
  /// **'Add a gym'**
  String get settingsGymAdd;

  /// No description provided for @gymFormNew.
  ///
  /// In en, this message translates to:
  /// **'New gym'**
  String get gymFormNew;

  /// No description provided for @gymFormEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit gym'**
  String get gymFormEdit;

  /// No description provided for @gymFormNotFound.
  ///
  /// In en, this message translates to:
  /// **'This gym isn\'t on this phone. It may have been deleted.'**
  String get gymFormNotFound;

  /// No description provided for @gymFormNameMissing.
  ///
  /// In en, this message translates to:
  /// **'Give the gym a name.'**
  String get gymFormNameMissing;

  /// No description provided for @gymFormMap.
  ///
  /// In en, this message translates to:
  /// **'Map. Tap to place the gym.'**
  String get gymFormMap;

  /// No description provided for @gymFormGrading.
  ///
  /// In en, this message translates to:
  /// **'Grading'**
  String get gymFormGrading;

  /// No description provided for @gymGrading.
  ///
  /// In en, this message translates to:
  /// **'{grading, select, colour{Colour scale} standard{Standard grades} none{Ungraded} other{}}'**
  String gymGrading(String grading);

  /// No description provided for @gymFormWalls.
  ///
  /// In en, this message translates to:
  /// **'Walls'**
  String get gymFormWalls;

  /// No description provided for @gymFormWallsNote.
  ///
  /// In en, this message translates to:
  /// **'Each climb you log on a wall gets its height and starts with its angle. You can change the angle per climb.'**
  String get gymFormWallsNote;

  /// No description provided for @gymFormColours.
  ///
  /// In en, this message translates to:
  /// **'Colours, easiest first'**
  String get gymFormColours;

  /// No description provided for @gymFormColoursNote.
  ///
  /// In en, this message translates to:
  /// **'Ranges are optional. With a range, climbs on that colour join grade charts at the middle of it. Without one, they still count in volume, angle and hold stats.'**
  String get gymFormColoursNote;

  /// No description provided for @gymFormColourAdd.
  ///
  /// In en, this message translates to:
  /// **'Add a colour'**
  String get gymFormColourAdd;

  /// No description provided for @gymFormColourName.
  ///
  /// In en, this message translates to:
  /// **'Colour name'**
  String get gymFormColourName;

  /// No description provided for @gymFormColourNameMissing.
  ///
  /// In en, this message translates to:
  /// **'Give the colour a name.'**
  String get gymFormColourNameMissing;

  /// No description provided for @gymFormColourPick.
  ///
  /// In en, this message translates to:
  /// **'Pick the colour for {name}'**
  String gymFormColourPick(String name);

  /// No description provided for @gymFormColourEasier.
  ///
  /// In en, this message translates to:
  /// **'Move {name} up'**
  String gymFormColourEasier(String name);

  /// No description provided for @gymFormColourRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}'**
  String gymFormColourRemove(String name);

  /// No description provided for @gymFormColourBoulders.
  ///
  /// In en, this message translates to:
  /// **'Boulders'**
  String get gymFormColourBoulders;

  /// No description provided for @gymFormColourRoutes.
  ///
  /// In en, this message translates to:
  /// **'Routes'**
  String get gymFormColourRoutes;

  /// No description provided for @gymFormColourUnmapped.
  ///
  /// In en, this message translates to:
  /// **'Not mapped'**
  String get gymFormColourUnmapped;

  /// No description provided for @gymFormColourTo.
  ///
  /// In en, this message translates to:
  /// **'to'**
  String get gymFormColourTo;

  /// No description provided for @gymFormColourRangeFrom.
  ///
  /// In en, this message translates to:
  /// **'Easiest grade for {name} ({kind})'**
  String gymFormColourRangeFrom(String name, String kind);

  /// No description provided for @gymFormColourRangeTo.
  ///
  /// In en, this message translates to:
  /// **'Hardest grade for {name} ({kind})'**
  String gymFormColourRangeTo(String name, String kind);

  /// No description provided for @gymColourGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get gymColourGreen;

  /// No description provided for @gymColourBlue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get gymColourBlue;

  /// No description provided for @gymColourNew.
  ///
  /// In en, this message translates to:
  /// **'Colour {number}'**
  String gymColourNew(int number);

  /// No description provided for @gymFormWallAdd.
  ///
  /// In en, this message translates to:
  /// **'Add a wall'**
  String get gymFormWallAdd;

  /// No description provided for @gymFormWallName.
  ///
  /// In en, this message translates to:
  /// **'Wall name'**
  String get gymFormWallName;

  /// No description provided for @gymFormWallNameMissing.
  ///
  /// In en, this message translates to:
  /// **'Give the wall a name.'**
  String get gymFormWallNameMissing;

  /// No description provided for @gymFormWallHeight.
  ///
  /// In en, this message translates to:
  /// **'Height in metres'**
  String get gymFormWallHeight;

  /// No description provided for @gymFormWallHeightInvalid.
  ///
  /// In en, this message translates to:
  /// **'Use a height from 1 to 60 m, or leave it empty.'**
  String get gymFormWallHeightInvalid;

  /// No description provided for @gymFormWallKind.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get gymFormWallKind;

  /// No description provided for @gymWallKind.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, rope{Rope} boulder{Boulder} other{}}'**
  String gymWallKind(String kind);

  /// No description provided for @gymFormWallAngle.
  ///
  /// In en, this message translates to:
  /// **'Angle'**
  String get gymFormWallAngle;

  /// Optional field for a wall's exact angle.
  ///
  /// In en, this message translates to:
  /// **'Degrees past vertical'**
  String get gymFormWallDegrees;

  /// No description provided for @gymFormWallDegreesHelp.
  ///
  /// In en, this message translates to:
  /// **'Optional. Negative for slabs. Sets the angle for you.'**
  String get gymFormWallDegreesHelp;

  /// No description provided for @gymFormWallDegreesInvalid.
  ///
  /// In en, this message translates to:
  /// **'Use whole degrees from -45 to 90, or leave it empty.'**
  String get gymFormWallDegreesInvalid;

  /// A wall's angle type with its degrees, such as 'Overhang 30°'.
  ///
  /// In en, this message translates to:
  /// **'{angle} {degrees}°'**
  String wallAngleDegrees(String angle, int degrees);

  /// No description provided for @gymFormWallRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}'**
  String gymFormWallRemove(String name);

  /// No description provided for @gymFormWallDefaultRope.
  ///
  /// In en, this message translates to:
  /// **'Main wall'**
  String get gymFormWallDefaultRope;

  /// No description provided for @gymFormWallDefaultBoulder.
  ///
  /// In en, this message translates to:
  /// **'Boulder area'**
  String get gymFormWallDefaultBoulder;

  /// No description provided for @gymFormWallDefault.
  ///
  /// In en, this message translates to:
  /// **'Wall {number}'**
  String gymFormWallDefault(int number);

  /// No description provided for @gymFormWallReset.
  ///
  /// In en, this message translates to:
  /// **'Reset today'**
  String get gymFormWallReset;

  /// No description provided for @gymFormWallResetLabel.
  ///
  /// In en, this message translates to:
  /// **'Mark {name} as reset today'**
  String gymFormWallResetLabel(String name);

  /// No description provided for @gymFormWallResetOn.
  ///
  /// In en, this message translates to:
  /// **'Last reset {date}'**
  String gymFormWallResetOn(String date);

  /// No description provided for @gymFormWallNeverReset.
  ///
  /// In en, this message translates to:
  /// **'Not reset yet'**
  String get gymFormWallNeverReset;

  /// No description provided for @gymFormWallResetDone.
  ///
  /// In en, this message translates to:
  /// **'{name} is marked as reset today. Its old routes are no longer suggested.'**
  String gymFormWallResetDone(String name);

  /// No description provided for @gymFormWallResetTitle.
  ///
  /// In en, this message translates to:
  /// **'Mark {name} as reset today?'**
  String gymFormWallResetTitle(String name);

  /// No description provided for @gymFormWallResetBody.
  ///
  /// In en, this message translates to:
  /// **'Routes on {name} that you haven\'t sent end as projects and are no longer suggested. Your climbs on them stay in your log.'**
  String gymFormWallResetBody(String name);

  /// No description provided for @gymFormWallResetCancel.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get gymFormWallResetCancel;

  /// No description provided for @gymFormWallResetConfirm.
  ///
  /// In en, this message translates to:
  /// **'Mark as reset'**
  String get gymFormWallResetConfirm;

  /// No description provided for @gymFormSave.
  ///
  /// In en, this message translates to:
  /// **'Save gym'**
  String get gymFormSave;

  /// No description provided for @gymFormNotYours.
  ///
  /// In en, this message translates to:
  /// **'This gym is shared, so only your walls can be changed here.'**
  String get gymFormNotYours;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get settingsVersion;

  /// No description provided for @settingsLicences.
  ///
  /// In en, this message translates to:
  /// **'Licences'**
  String get settingsLicences;

  /// No description provided for @settingsSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the setting. Try again.'**
  String get settingsSaveFailed;

  /// No description provided for @trainingTitle.
  ///
  /// In en, this message translates to:
  /// **'Training'**
  String get trainingTitle;

  /// No description provided for @trainingEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Track strength and mobility'**
  String get trainingEmptyTitle;

  /// No description provided for @trainingEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Finger strength, pulling, core and mobility tests arrive here, with your progress over time.'**
  String get trainingEmptyBody;

  /// No description provided for @logSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Log a session'**
  String get logSheetTitle;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @notFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'This page doesn\'t exist'**
  String get notFoundTitle;

  /// No description provided for @notFoundBody.
  ///
  /// In en, this message translates to:
  /// **'The link may be old or mistyped.'**
  String get notFoundBody;

  /// No description provided for @notFoundAction.
  ///
  /// In en, this message translates to:
  /// **'Go to the feed'**
  String get notFoundAction;

  /// Tooltip of the search button on the History tab.
  ///
  /// In en, this message translates to:
  /// **'Find a route'**
  String get routeSearchOpen;

  /// No description provided for @routeSearchTitle.
  ///
  /// In en, this message translates to:
  /// **'Find a route'**
  String get routeSearchTitle;

  /// Label of the search field.
  ///
  /// In en, this message translates to:
  /// **'Route or crag'**
  String get routeSearchField;

  /// No description provided for @routeSearchNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No routes match \"{term}\".'**
  String routeSearchNoMatch(String term);

  /// No description provided for @routeSearchEmpty.
  ///
  /// In en, this message translates to:
  /// **'Routes you add and climb show up here.'**
  String get routeSearchEmpty;

  /// No description provided for @routeNotFound.
  ///
  /// In en, this message translates to:
  /// **'This route is gone or private.'**
  String get routeNotFound;

  /// No description provided for @routeUngraded.
  ///
  /// In en, this message translates to:
  /// **'Ungraded'**
  String get routeUngraded;

  /// No description provided for @routeLength.
  ///
  /// In en, this message translates to:
  /// **'{metres} m'**
  String routeLength(int metres);

  /// No description provided for @routePitches.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 pitch} other{{count} pitches}}'**
  String routePitches(int count);

  /// No description provided for @routeRopeLength.
  ///
  /// In en, this message translates to:
  /// **'{metres} m rope'**
  String routeRopeLength(int metres);

  /// No description provided for @routeDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get routeDetails;

  /// No description provided for @routeYourClimbs.
  ///
  /// In en, this message translates to:
  /// **'Your climbs'**
  String get routeYourClimbs;

  /// No description provided for @routeNotClimbed.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t logged this route yet.'**
  String get routeNotClimbed;

  /// No description provided for @routeLastClimbed.
  ///
  /// In en, this message translates to:
  /// **'Last climbed {date}'**
  String routeLastClimbed(String date);

  /// A route's discipline, by its stable key.
  ///
  /// In en, this message translates to:
  /// **'{discipline, select, sport{Sport} trad{Trad} boulder{Boulder} alpine{Alpine} ice{Ice} mixed{Mixed} aid{Aid} dws{Deep water solo} other{}}'**
  String discipline(String discipline);

  /// A climb's style, by its stable key.
  ///
  /// In en, this message translates to:
  /// **'{style, select, onsight{Onsight} flash{Flash} redpoint{Redpoint} repeat{Repeat} attempt{Attempt} other{}}'**
  String ascentStyle(String style);

  /// No description provided for @ascentTries.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 try} other{{count} tries}}'**
  String ascentTries(int count);

  /// Which way a crag faces, by compass key.
  ///
  /// In en, this message translates to:
  /// **'{direction, select, N{Faces north} NE{Faces northeast} E{Faces east} SE{Faces southeast} S{Faces south} SW{Faces southwest} W{Faces west} NW{Faces northwest} other{}}'**
  String aspect(String direction);

  /// A route detail by its stable key, with the dot replaced by an underscore (hold.crimp is hold_crimp). Empty for unknown keys.
  ///
  /// In en, this message translates to:
  /// **'{value, select, rock_granite{Granite} rock_gneiss{Gneiss} rock_limestone{Limestone} rock_sandstone{Sandstone} rock_basalt{Basalt} rock_conglomerate{Conglomerate} rock_quartzite{Quartzite} rock_schist{Schist} rock_dolerite{Dolerite} angle_slab{Slab} angle_vertical{Vertical} angle_overhang{Overhang} angle_roof{Roof} feature_face{Face} feature_finger_crack{Finger crack} feature_hand_crack{Hand crack} feature_offwidth{Offwidth} feature_chimney{Chimney} feature_corner{Corner} feature_arete{Arête} feature_tufa{Tufa} feature_ice_pillar{Ice pillar} feature_ice_curtain{Ice curtain} feature_mixed_dry_tool{Dry tooling} hold_crimp{Crimps} hold_pocket{Pockets} hold_pinch{Pinches} hold_sloper{Slopers} hold_jug{Jugs} hold_undercling{Underclings} hold_sidepull{Sidepulls} protection_bolted{Bolted} protection_trad{Trad gear} protection_mixed{Mixed protection} protection_runout{Runout} protection_none{No protection} protection_pads{Pads} protection_ice_screws{Ice screws} descent_lower_off{Lower off} descent_rappel{Rappel} descent_walk_off{Walk off} descent_downclimb{Downclimb} descent_swim{Swim} feel_very_soft{Very soft} feel_soft{Soft} feel_fair{Fair} feel_hard{Hard} feel_very_hard{Very hard} tag_pumpy{Pumpy} tag_techy{Technical} tag_powerful{Powerful} tag_scary{Scary} tag_sustained{Sustained} tag_reachy{Reachy} tag_polished{Polished} tag_great_rock{Great rock} tag_heady{Heady} tag_balancy{Balancy} condition_perfect{Perfect} condition_dry{Dry} condition_humid{Humid} condition_damp{Damp} condition_wet{Wet} condition_icy{Icy} condition_windy{Windy} condition_cold{Cold} condition_hot{Hot} other{}}'**
  String attributeValue(String value);

  /// No description provided for @routeAdd.
  ///
  /// In en, this message translates to:
  /// **'Add a route'**
  String get routeAdd;

  /// No description provided for @routeFormTitle.
  ///
  /// In en, this message translates to:
  /// **'New route'**
  String get routeFormTitle;

  /// No description provided for @formName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get formName;

  /// No description provided for @routeFormNameMissing.
  ///
  /// In en, this message translates to:
  /// **'Give the route a name.'**
  String get routeFormNameMissing;

  /// No description provided for @routeFormCrag.
  ///
  /// In en, this message translates to:
  /// **'Crag'**
  String get routeFormCrag;

  /// No description provided for @routeFormCragMissing.
  ///
  /// In en, this message translates to:
  /// **'Pick the crag the route is in.'**
  String get routeFormCragMissing;

  /// No description provided for @routeFormRockFromCrag.
  ///
  /// In en, this message translates to:
  /// **'Rock type comes from the crag: {rock}.'**
  String routeFormRockFromCrag(String rock);

  /// No description provided for @routeFormDiscipline.
  ///
  /// In en, this message translates to:
  /// **'Discipline'**
  String get routeFormDiscipline;

  /// No description provided for @routeFormGrade.
  ///
  /// In en, this message translates to:
  /// **'Grade ({system})'**
  String routeFormGrade(String system);

  /// No description provided for @routeFormNoGrade.
  ///
  /// In en, this message translates to:
  /// **'No grade yet'**
  String get routeFormNoGrade;

  /// No description provided for @routeFormLength.
  ///
  /// In en, this message translates to:
  /// **'Length in metres'**
  String get routeFormLength;

  /// No description provided for @routeFormPitches.
  ///
  /// In en, this message translates to:
  /// **'Pitches'**
  String get routeFormPitches;

  /// No description provided for @routeFormPitch.
  ///
  /// In en, this message translates to:
  /// **'Pitch {number}'**
  String routeFormPitch(int number);

  /// No description provided for @formNumberInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a number from 1 to {max}.'**
  String formNumberInvalid(int max);

  /// No description provided for @routeFormAngle.
  ///
  /// In en, this message translates to:
  /// **'Angle'**
  String get routeFormAngle;

  /// No description provided for @routeFormFeatures.
  ///
  /// In en, this message translates to:
  /// **'Features'**
  String get routeFormFeatures;

  /// No description provided for @routeFormHolds.
  ///
  /// In en, this message translates to:
  /// **'Holds'**
  String get routeFormHolds;

  /// No description provided for @routeFormProtection.
  ///
  /// In en, this message translates to:
  /// **'Protection'**
  String get routeFormProtection;

  /// No description provided for @routeFormDescent.
  ///
  /// In en, this message translates to:
  /// **'Descent'**
  String get routeFormDescent;

  /// No description provided for @routeFormRope.
  ///
  /// In en, this message translates to:
  /// **'Rope needed'**
  String get routeFormRope;

  /// No description provided for @routeFormFirstAscent.
  ///
  /// In en, this message translates to:
  /// **'First ascent'**
  String get routeFormFirstAscent;

  /// No description provided for @routeFormFirstAscentHint.
  ///
  /// In en, this message translates to:
  /// **'Names and year'**
  String get routeFormFirstAscentHint;

  /// No description provided for @routeFormSave.
  ///
  /// In en, this message translates to:
  /// **'Save route'**
  String get routeFormSave;

  /// No description provided for @formSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save. Check the fields and try again.'**
  String get formSaveFailed;

  /// No description provided for @cragAdd.
  ///
  /// In en, this message translates to:
  /// **'New crag'**
  String get cragAdd;

  /// No description provided for @cragFormTitle.
  ///
  /// In en, this message translates to:
  /// **'New crag'**
  String get cragFormTitle;

  /// No description provided for @cragFormNameMissing.
  ///
  /// In en, this message translates to:
  /// **'Give the crag a name.'**
  String get cragFormNameMissing;

  /// No description provided for @cragFormCountry.
  ///
  /// In en, this message translates to:
  /// **'Country code'**
  String get cragFormCountry;

  /// No description provided for @cragFormCountryInvalid.
  ///
  /// In en, this message translates to:
  /// **'Use two letters, such as NO.'**
  String get cragFormCountryInvalid;

  /// No description provided for @cragFormRock.
  ///
  /// In en, this message translates to:
  /// **'Rock type'**
  String get cragFormRock;

  /// No description provided for @cragFormLatitude.
  ///
  /// In en, this message translates to:
  /// **'Latitude'**
  String get cragFormLatitude;

  /// No description provided for @cragFormLongitude.
  ///
  /// In en, this message translates to:
  /// **'Longitude'**
  String get cragFormLongitude;

  /// No description provided for @cragFormLocationHint.
  ///
  /// In en, this message translates to:
  /// **'Decimal degrees, such as 59.92 and 10.50. Leave both empty if you are not sure.'**
  String get cragFormLocationHint;

  /// No description provided for @cragFormLocationInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter both, as decimal degrees.'**
  String get cragFormLocationInvalid;

  /// No description provided for @cragFormSave.
  ///
  /// In en, this message translates to:
  /// **'Save crag'**
  String get cragFormSave;

  /// No description provided for @formLengthInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a length in metres, up to {max}.'**
  String formLengthInvalid(int max);

  /// No description provided for @logWhere.
  ///
  /// In en, this message translates to:
  /// **'Where did you climb?'**
  String get logWhere;

  /// No description provided for @logOutdoor.
  ///
  /// In en, this message translates to:
  /// **'Outdoor'**
  String get logOutdoor;

  /// No description provided for @logOutdoorHint.
  ///
  /// In en, this message translates to:
  /// **'Crags and mountains'**
  String get logOutdoorHint;

  /// No description provided for @logIndoor.
  ///
  /// In en, this message translates to:
  /// **'Indoor gym'**
  String get logIndoor;

  /// No description provided for @logIndoorHint.
  ///
  /// In en, this message translates to:
  /// **'Walls and boards'**
  String get logIndoorHint;

  /// No description provided for @logIndoorNoTiles.
  ///
  /// In en, this message translates to:
  /// **'Nothing to tap yet. Add colours or choose a grading for this gym in Settings, under Gyms.'**
  String get logIndoorNoTiles;

  /// No description provided for @logIndoorLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your gyms. Close the log and try again.'**
  String get logIndoorLoadFailed;

  /// Lower case, inside a sentence such as 'Topped Blue, boulder'.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, boulder{boulder} rope{rope} other{}}'**
  String logIndoorKind(String kind);

  /// No description provided for @logIndoorNoGym.
  ///
  /// In en, this message translates to:
  /// **'Set up your gym first: its walls and colours.'**
  String get logIndoorNoGym;

  /// No description provided for @logIndoorNoWalls.
  ///
  /// In en, this message translates to:
  /// **'This gym has no walls yet. Add them in Settings, under Gyms.'**
  String get logIndoorNoWalls;

  /// No description provided for @logIndoorGym.
  ///
  /// In en, this message translates to:
  /// **'Gym'**
  String get logIndoorGym;

  /// No description provided for @logIndoorFoundHere.
  ///
  /// In en, this message translates to:
  /// **'Found from your location'**
  String get logIndoorFoundHere;

  /// No description provided for @logIndoorWall.
  ///
  /// In en, this message translates to:
  /// **'Wall'**
  String get logIndoorWall;

  /// No description provided for @logIndoorTapHint.
  ///
  /// In en, this message translates to:
  /// **'Tap a colour each time you top it.'**
  String get logIndoorTapHint;

  /// No description provided for @logIndoorUngraded.
  ///
  /// In en, this message translates to:
  /// **'Climb'**
  String get logIndoorUngraded;

  /// No description provided for @logIndoorTopped.
  ///
  /// In en, this message translates to:
  /// **'Topped {colour}, {kind}'**
  String logIndoorTopped(String colour, String kind);

  /// No description provided for @logIndoorAddedSend.
  ///
  /// In en, this message translates to:
  /// **'{colour}: send added'**
  String logIndoorAddedSend(String colour);

  /// No description provided for @logIndoorAddedAttempt.
  ///
  /// In en, this message translates to:
  /// **'{colour}: attempt added'**
  String logIndoorAddedAttempt(String colour);

  /// No description provided for @logIndoorUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get logIndoorUndo;

  /// No description provided for @logIndoorDidntTop.
  ///
  /// In en, this message translates to:
  /// **'Didn\'t top'**
  String get logIndoorDidntTop;

  /// No description provided for @logIndoorToppedIt.
  ///
  /// In en, this message translates to:
  /// **'Topped it'**
  String get logIndoorToppedIt;

  /// No description provided for @logIndoorTries.
  ///
  /// In en, this message translates to:
  /// **'Tries'**
  String get logIndoorTries;

  /// No description provided for @logIndoorFewerTries.
  ///
  /// In en, this message translates to:
  /// **'Fewer tries'**
  String get logIndoorFewerTries;

  /// No description provided for @logIndoorMoreTries.
  ///
  /// In en, this message translates to:
  /// **'More tries'**
  String get logIndoorMoreTries;

  /// No description provided for @logIndoorRopeType.
  ///
  /// In en, this message translates to:
  /// **'On the rope'**
  String get logIndoorRopeType;

  /// No description provided for @logIndoorThisSession.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{This session · 1 climb} other{This session · {count} climbs}}'**
  String logIndoorThisSession(int count);

  /// No description provided for @logRoute.
  ///
  /// In en, this message translates to:
  /// **'Route or problem'**
  String get logRoute;

  /// No description provided for @logChangeRoute.
  ///
  /// In en, this message translates to:
  /// **'Change route'**
  String get logChangeRoute;

  /// No description provided for @logStyle.
  ///
  /// In en, this message translates to:
  /// **'Style'**
  String get logStyle;

  /// No description provided for @logTries.
  ///
  /// In en, this message translates to:
  /// **'Tries'**
  String get logTries;

  /// No description provided for @logTriesFewer.
  ///
  /// In en, this message translates to:
  /// **'Fewer tries'**
  String get logTriesFewer;

  /// No description provided for @logTriesMore.
  ///
  /// In en, this message translates to:
  /// **'More tries'**
  String get logTriesMore;

  /// No description provided for @logHintSent.
  ///
  /// In en, this message translates to:
  /// **'You have sent this route, so it logs as a repeat or an attempt.'**
  String get logHintSent;

  /// No description provided for @logHintTried.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{You have 1 earlier try on this route, so onsight and flash are not possible.} other{You have {count} earlier tries on this route, so onsight and flash are not possible.}}'**
  String logHintTried(int count);

  /// No description provided for @logHintBoulder.
  ///
  /// In en, this message translates to:
  /// **'Boulders are flashed, not onsighted.'**
  String get logHintBoulder;

  /// No description provided for @logRope.
  ///
  /// In en, this message translates to:
  /// **'Rope'**
  String get logRope;

  /// How a climb was climbed, by its stable key.
  ///
  /// In en, this message translates to:
  /// **'{type, select, lead{Lead} follow{Follow} toprope{Top rope} solo{Solo} boulder{Boulder} other{}}'**
  String ascentType(String type);

  /// No description provided for @logFeel.
  ///
  /// In en, this message translates to:
  /// **'How it felt for the grade'**
  String get logFeel;

  /// No description provided for @logPersonalGrade.
  ///
  /// In en, this message translates to:
  /// **'Your grade'**
  String get logPersonalGrade;

  /// No description provided for @logPersonalGradeNone.
  ///
  /// In en, this message translates to:
  /// **'Same as the route'**
  String get logPersonalGradeNone;

  /// No description provided for @logTags.
  ///
  /// In en, this message translates to:
  /// **'Describe it'**
  String get logTags;

  /// No description provided for @logQuality.
  ///
  /// In en, this message translates to:
  /// **'Quality'**
  String get logQuality;

  /// No description provided for @logQualityLevel.
  ///
  /// In en, this message translates to:
  /// **'{level, select, q1{Good} q2{Great} q3{Classic} other{}}'**
  String logQualityLevel(String level);

  /// No description provided for @logAddClimb.
  ///
  /// In en, this message translates to:
  /// **'Add climb and log another'**
  String get logAddClimb;

  /// No description provided for @logClimbCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 climb} other{{count} climbs}}'**
  String logClimbCount(int count);

  /// No description provided for @logRemoveClimb.
  ///
  /// In en, this message translates to:
  /// **'Remove {route}'**
  String logRemoveClimb(String route);

  /// No description provided for @logSession.
  ///
  /// In en, this message translates to:
  /// **'Session'**
  String get logSession;

  /// No description provided for @logDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get logDate;

  /// No description provided for @logTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get logTitle;

  /// No description provided for @logDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get logDescription;

  /// No description provided for @logConditions.
  ///
  /// In en, this message translates to:
  /// **'Conditions'**
  String get logConditions;

  /// No description provided for @logPartners.
  ///
  /// In en, this message translates to:
  /// **'Partners'**
  String get logPartners;

  /// No description provided for @logPartnersHint.
  ///
  /// In en, this message translates to:
  /// **'Names, separated by commas'**
  String get logPartnersHint;

  /// No description provided for @logSave.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Save session} other{Save session ({count} climbs)}}'**
  String logSave(int count);

  /// No description provided for @logSaved.
  ///
  /// In en, this message translates to:
  /// **'Session saved'**
  String get logSaved;

  /// No description provided for @logClimbRejected.
  ///
  /// In en, this message translates to:
  /// **'Climb {number} no longer fits the style and tries rules. Check it and try again.'**
  String logClimbRejected(int number);

  /// No description provided for @logLaterClimbsRemoved.
  ///
  /// In en, this message translates to:
  /// **'Later climbs on that route no longer fit the rules, so they were removed too.'**
  String get logLaterClimbsRemoved;

  /// No description provided for @routeYourGrade.
  ///
  /// In en, this message translates to:
  /// **'Your grade: {grade}'**
  String routeYourGrade(String grade);

  /// No description provided for @routeYourFeel.
  ///
  /// In en, this message translates to:
  /// **'How it felt: {feel}'**
  String routeYourFeel(String feel);

  /// On a climb in a route's history, when the route has been regraded since.
  ///
  /// In en, this message translates to:
  /// **'graded {grade} then'**
  String routeLoggedAt(String grade);

  /// No description provided for @cragFormMap.
  ///
  /// In en, this message translates to:
  /// **'Map. Tap to place the crag.'**
  String get cragFormMap;

  /// No description provided for @cragFormLocationHintMap.
  ///
  /// In en, this message translates to:
  /// **'Tap the map, or type decimal degrees such as 59.92 and 10.50. Leave both empty if you are not sure.'**
  String get cragFormLocationHintMap;

  /// A season by name (spring, summer, autumn, winter).
  ///
  /// In en, this message translates to:
  /// **'{season, select, spring{Spring} summer{Summer} autumn{Autumn} winter{Winter} other{}}'**
  String season(String season);

  /// No description provided for @weatherTemp.
  ///
  /// In en, this message translates to:
  /// **'{temp} °C'**
  String weatherTemp(String temp);

  /// No description provided for @weatherRain.
  ///
  /// In en, this message translates to:
  /// **'{mm} mm rain'**
  String weatherRain(String mm);

  /// No description provided for @weatherWind.
  ///
  /// In en, this message translates to:
  /// **'{speed} m/s wind'**
  String weatherWind(String speed);

  /// No description provided for @sessionNotFound.
  ///
  /// In en, this message translates to:
  /// **'This session isn\'t on this phone. It may have been deleted.'**
  String get sessionNotFound;

  /// No description provided for @sessionWith.
  ///
  /// In en, this message translates to:
  /// **'With {names}'**
  String sessionWith(String names);

  /// No description provided for @sessionClimbs.
  ///
  /// In en, this message translates to:
  /// **'Climbs'**
  String get sessionClimbs;

  /// No description provided for @sessionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit session'**
  String get sessionEdit;

  /// No description provided for @sessionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete session'**
  String get sessionDelete;

  /// No description provided for @sessionDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this session?'**
  String get sessionDeleteTitle;

  /// No description provided for @sessionDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Its climbs and partners are deleted with it. Later climbs on the same routes are recounted.'**
  String get sessionDeleteBody;

  /// No description provided for @sessionDeleteLastBody.
  ///
  /// In en, this message translates to:
  /// **'This is the session\'s last climb, so saving deletes the whole session.'**
  String get sessionDeleteLastBody;

  /// No description provided for @sessionDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get sessionDeleteConfirm;

  /// No description provided for @sessionKeep.
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get sessionKeep;

  /// No description provided for @sessionDeleted.
  ///
  /// In en, this message translates to:
  /// **'Session deleted'**
  String get sessionDeleted;

  /// No description provided for @logEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit session'**
  String get logEditTitle;

  /// No description provided for @logEditExisting.
  ///
  /// In en, this message translates to:
  /// **'In this session'**
  String get logEditExisting;

  /// No description provided for @logEditForgotten.
  ///
  /// In en, this message translates to:
  /// **'Add a climb you forgot'**
  String get logEditForgotten;

  /// No description provided for @logEditMarked.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 climb is removed when you save.} other{{count} climbs are removed when you save.}}'**
  String logEditMarked(int count);

  /// No description provided for @logEditKeep.
  ///
  /// In en, this message translates to:
  /// **'Keep {route}'**
  String logEditKeep(String route);

  /// No description provided for @logEditSave.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get logEditSave;

  /// No description provided for @logEditSaved.
  ///
  /// In en, this message translates to:
  /// **'Changes saved'**
  String get logEditSaved;

  /// No description provided for @logLaterClimbRejected.
  ///
  /// In en, this message translates to:
  /// **'A later climb on the same route depends on this one. Change or remove that climb first.'**
  String get logLaterClimbRejected;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'nb'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'nb':
      return AppLocalizationsNb();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
