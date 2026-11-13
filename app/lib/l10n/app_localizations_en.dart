// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get tabFeed => 'Feed';

  @override
  String get tabHistory => 'History';

  @override
  String get tabCv => 'CV';

  @override
  String get tabTraining => 'Training';

  @override
  String get logButton => 'Log a session';

  @override
  String get feedEmptyTitle => 'Your sessions show up here';

  @override
  String get feedEmptyBody =>
      'Log your first session and it appears in your feed. Friends\' sessions join it later.';

  @override
  String get feedOpenSession => 'Open session';

  @override
  String feedSetting(String setting) {
    String _temp0 = intl.Intl.selectLogic(setting, {
      'outdoor': 'Outdoors',
      'indoor': 'Indoors',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String feedWith(String names) {
    return 'with $names';
  }

  @override
  String feedMoreClimbs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count more climbs',
      one: '+1 more climb',
    );
    return '$_temp0';
  }

  @override
  String get feedStatPitches => 'Pitches';

  @override
  String get feedStatClimbed => 'Climbed';

  @override
  String get feedStatElevation => 'Elevation gain';

  @override
  String get feedStatMetres => 'm';

  @override
  String get historyTitle => 'History';

  @override
  String get historyEmptyTitle => 'Your history starts with one session';

  @override
  String get historyEmptyBody =>
      'Days out, grades, pyramids and insights fill in as you log.';

  @override
  String get cvTitle => 'Climbing CV';

  @override
  String get cvEmptyTitle => 'Your CV builds itself';

  @override
  String get cvEmptyBody =>
      'Every climb you log adds to your levels and experience, and shows what you have not tried yet.';

  @override
  String get settingsOpen => 'Settings';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsTheme => 'Theme';

  @override
  String settingsThemeOption(String theme) {
    String _temp0 = intl.Intl.selectLogic(theme, {
      'system': 'Follow the phone',
      'midnight': 'Midnight sun',
      'daylight': 'Daylight',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSystem => 'Follow the phone';

  @override
  String get settingsLanguageNb => 'Norsk (bokmål)';

  @override
  String get settingsLanguageEn => 'English';

  @override
  String get settingsGrades => 'Grades';

  @override
  String get settingsGradesNote =>
      'Grades show in these systems. What you logged is kept as you logged it.';

  @override
  String settingsGradeType(String type) {
    String _temp0 = intl.Intl.selectLogic(type, {
      'free_route': 'Routes',
      'boulder': 'Boulders',
      'ice': 'Ice',
      'mixed': 'Mixed',
      'aid': 'Aid',
      'alpine': 'Alpine',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String gradeSystemName(String system) {
    String _temp0 = intl.Intl.selectLogic(system, {
      'nor': 'Norwegian',
      'french': 'French',
      'yds': 'YDS',
      'uiaa': 'UIAA',
      'font': 'Font',
      'v': 'V scale',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get settingsVisibility => 'New sessions are visible to';

  @override
  String settingsVisibilityOption(String visibility) {
    String _temp0 = intl.Intl.selectLogic(visibility, {
      'private': 'Only you',
      'friends': 'Friends',
      'public': 'Everyone',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get settingsVisibilityNote =>
      'Nothing leaves this phone until you sign in.';

  @override
  String get settingsGyms => 'Gyms';

  @override
  String get settingsGymsNote =>
      'Set up the gyms you climb in once, so logging there is quick.';

  @override
  String get settingsGymAdd => 'Add a gym';

  @override
  String get gymFormNew => 'New gym';

  @override
  String get gymFormEdit => 'Edit gym';

  @override
  String get gymFormNotFound =>
      'This gym isn\'t on this phone. It may have been deleted.';

  @override
  String get gymFormNameMissing => 'Give the gym a name.';

  @override
  String get gymFormMap => 'Map. Tap to place the gym.';

  @override
  String get gymFormGrading => 'Grading';

  @override
  String gymGrading(String grading) {
    String _temp0 = intl.Intl.selectLogic(grading, {
      'colour': 'Colour scale',
      'standard': 'Standard grades',
      'none': 'Ungraded',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get gymFormWalls => 'Walls';

  @override
  String get gymFormWallsNote =>
      'Each climb you log on a wall gets its height and starts with its angle. You can change the angle per climb.';

  @override
  String get gymFormColours => 'Colours, easiest first';

  @override
  String get gymFormColoursNote =>
      'Ranges are optional. With a range, climbs on that colour join grade charts at the middle of it. Without one, they still count in volume, angle and hold stats.';

  @override
  String get gymFormColourAdd => 'Add a colour';

  @override
  String get gymFormColourName => 'Colour name';

  @override
  String get gymFormColourNameMissing => 'Give the colour a name.';

  @override
  String gymFormColourPick(String name) {
    return 'Pick the colour for $name';
  }

  @override
  String gymFormColourEasier(String name) {
    return 'Move $name up';
  }

  @override
  String gymFormColourRemove(String name) {
    return 'Remove $name';
  }

  @override
  String get gymFormColourBoulders => 'Boulders';

  @override
  String get gymFormColourRoutes => 'Routes';

  @override
  String get gymFormColourUnmapped => 'Not mapped';

  @override
  String get gymFormColourTo => 'to';

  @override
  String gymFormColourRangeFrom(String name, String kind) {
    return 'Easiest grade for $name ($kind)';
  }

  @override
  String gymFormColourRangeTo(String name, String kind) {
    return 'Hardest grade for $name ($kind)';
  }

  @override
  String get gymColourGreen => 'Green';

  @override
  String get gymColourBlue => 'Blue';

  @override
  String gymColourNew(int number) {
    return 'Colour $number';
  }

  @override
  String get gymFormWallAdd => 'Add a wall';

  @override
  String get gymFormWallName => 'Wall name';

  @override
  String get gymFormWallNameMissing => 'Give the wall a name.';

  @override
  String get gymFormWallHeight => 'Height in metres';

  @override
  String get gymFormWallHeightInvalid =>
      'Use a height from 1 to 60 m, or leave it empty.';

  @override
  String get gymFormWallKind => 'Type';

  @override
  String gymWallKind(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'rope': 'Rope',
      'boulder': 'Boulder',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get gymFormWallAngle => 'Angle';

  @override
  String get gymFormWallDegrees => 'Degrees past vertical';

  @override
  String get gymFormWallDegreesHelp =>
      'Optional. Negative for slabs. Sets the angle for you.';

  @override
  String gymFormWallDegreesInvalid(int min, int max) {
    return 'Use whole degrees from $min to $max, or leave it empty.';
  }

  @override
  String wallAngleDegrees(String angle, int degrees) {
    return '$angle $degrees°';
  }

  @override
  String gymFormWallRemove(String name) {
    return 'Remove $name';
  }

  @override
  String get gymFormWallDefaultRope => 'Main wall';

  @override
  String get gymFormWallDefaultBoulder => 'Boulder area';

  @override
  String gymFormWallDefault(int number) {
    return 'Wall $number';
  }

  @override
  String get gymFormWallReset => 'Reset today';

  @override
  String gymFormWallResetLabel(String name) {
    return 'Mark $name as reset today';
  }

  @override
  String gymFormWallResetOn(String date) {
    return 'Last reset $date';
  }

  @override
  String get gymFormWallNeverReset => 'Not reset yet';

  @override
  String gymFormWallResetDone(String name) {
    return '$name is marked as reset today. Its old routes are no longer suggested.';
  }

  @override
  String gymFormWallResetTitle(String name) {
    return 'Mark $name as reset today?';
  }

  @override
  String gymFormWallResetBody(String name) {
    return 'Routes on $name that you haven\'t sent end as projects and are no longer suggested. Your climbs on them stay in your log.';
  }

  @override
  String get gymFormWallResetCancel => 'Not now';

  @override
  String get gymFormWallResetConfirm => 'Mark as reset';

  @override
  String get gymFormSave => 'Save gym';

  @override
  String get gymFormNotYours =>
      'This gym is shared, so only your walls can be changed here.';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsVersion => 'Version';

  @override
  String get settingsLicences => 'Licences';

  @override
  String get settingsSaveFailed => 'Couldn\'t save the setting. Try again.';

  @override
  String get trainingTitle => 'Training';

  @override
  String get trainingEmptyTitle => 'Track strength and mobility';

  @override
  String get trainingEmptyBody =>
      'Finger strength, pulling, core and mobility tests arrive here, with your progress over time.';

  @override
  String get logSheetTitle => 'Log a session';

  @override
  String get close => 'Close';

  @override
  String get notFoundTitle => 'This page doesn\'t exist';

  @override
  String get notFoundBody => 'The link may be old or mistyped.';

  @override
  String get notFoundAction => 'Go to the feed';

  @override
  String get routeSearchOpen => 'Find a route';

  @override
  String get routeSearchTitle => 'Find a route';

  @override
  String get routeSearchField => 'Route or crag';

  @override
  String routeSearchNoMatch(String term) {
    return 'No routes match \"$term\".';
  }

  @override
  String get routeSearchEmpty => 'Routes you add and climb show up here.';

  @override
  String get routeNotFound => 'This route is gone or private.';

  @override
  String get routeUngraded => 'Ungraded';

  @override
  String routeLength(int metres) {
    return '$metres m';
  }

  @override
  String routePitches(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pitches',
      one: '1 pitch',
    );
    return '$_temp0';
  }

  @override
  String routeRopeLength(int metres) {
    return '$metres m rope';
  }

  @override
  String get routeDetails => 'Details';

  @override
  String get routeYourClimbs => 'Your climbs';

  @override
  String get routeNotClimbed => 'You haven\'t logged this route yet.';

  @override
  String routeLastClimbed(String date) {
    return 'Last climbed $date';
  }

  @override
  String discipline(String discipline) {
    String _temp0 = intl.Intl.selectLogic(discipline, {
      'sport': 'Sport',
      'trad': 'Trad',
      'boulder': 'Boulder',
      'alpine': 'Alpine',
      'ice': 'Ice',
      'mixed': 'Mixed',
      'aid': 'Aid',
      'dws': 'Deep water solo',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String ascentStyle(String style) {
    String _temp0 = intl.Intl.selectLogic(style, {
      'onsight': 'Onsight',
      'flash': 'Flash',
      'redpoint': 'Redpoint',
      'repeat': 'Repeat',
      'attempt': 'Attempt',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String ascentTries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tries',
      one: '1 try',
    );
    return '$_temp0';
  }

  @override
  String aspect(String direction) {
    String _temp0 = intl.Intl.selectLogic(direction, {
      'N': 'Faces north',
      'NE': 'Faces northeast',
      'E': 'Faces east',
      'SE': 'Faces southeast',
      'S': 'Faces south',
      'SW': 'Faces southwest',
      'W': 'Faces west',
      'NW': 'Faces northwest',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String attributeValue(String value) {
    String _temp0 = intl.Intl.selectLogic(value, {
      'rock_granite': 'Granite',
      'rock_gneiss': 'Gneiss',
      'rock_limestone': 'Limestone',
      'rock_sandstone': 'Sandstone',
      'rock_basalt': 'Basalt',
      'rock_conglomerate': 'Conglomerate',
      'rock_quartzite': 'Quartzite',
      'rock_schist': 'Schist',
      'rock_dolerite': 'Dolerite',
      'angle_slab': 'Slab',
      'angle_vertical': 'Vertical',
      'angle_overhang': 'Overhang',
      'angle_roof': 'Roof',
      'feature_face': 'Face',
      'feature_finger_crack': 'Finger crack',
      'feature_hand_crack': 'Hand crack',
      'feature_offwidth': 'Offwidth',
      'feature_chimney': 'Chimney',
      'feature_corner': 'Corner',
      'feature_arete': 'Arête',
      'feature_tufa': 'Tufa',
      'feature_ice_pillar': 'Ice pillar',
      'feature_ice_curtain': 'Ice curtain',
      'feature_mixed_dry_tool': 'Dry tooling',
      'hold_crimp': 'Crimps',
      'hold_pocket': 'Pockets',
      'hold_pinch': 'Pinches',
      'hold_sloper': 'Slopers',
      'hold_jug': 'Jugs',
      'hold_undercling': 'Underclings',
      'hold_sidepull': 'Sidepulls',
      'protection_bolted': 'Bolted',
      'protection_trad': 'Trad gear',
      'protection_mixed': 'Mixed protection',
      'protection_runout': 'Runout',
      'protection_none': 'No protection',
      'protection_pads': 'Pads',
      'protection_ice_screws': 'Ice screws',
      'descent_lower_off': 'Lower off',
      'descent_rappel': 'Rappel',
      'descent_walk_off': 'Walk off',
      'descent_downclimb': 'Downclimb',
      'descent_swim': 'Swim',
      'feel_very_soft': 'Very soft',
      'feel_soft': 'Soft',
      'feel_fair': 'Fair',
      'feel_hard': 'Hard',
      'feel_very_hard': 'Very hard',
      'tag_pumpy': 'Pumpy',
      'tag_techy': 'Technical',
      'tag_powerful': 'Powerful',
      'tag_scary': 'Scary',
      'tag_sustained': 'Sustained',
      'tag_reachy': 'Reachy',
      'tag_polished': 'Polished',
      'tag_great_rock': 'Great rock',
      'tag_heady': 'Heady',
      'tag_balancy': 'Balancy',
      'condition_perfect': 'Perfect',
      'condition_dry': 'Dry',
      'condition_humid': 'Humid',
      'condition_damp': 'Damp',
      'condition_wet': 'Wet',
      'condition_icy': 'Icy',
      'condition_windy': 'Windy',
      'condition_cold': 'Cold',
      'condition_hot': 'Hot',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get routeAdd => 'Add a route';

  @override
  String get routeFormTitle => 'New route';

  @override
  String get formName => 'Name';

  @override
  String get routeFormNameMissing => 'Give the route a name.';

  @override
  String get routeFormCrag => 'Crag';

  @override
  String get routeFormCragMissing => 'Pick the crag the route is in.';

  @override
  String routeFormRockFromCrag(String rock) {
    return 'Rock type comes from the crag: $rock.';
  }

  @override
  String get routeFormDiscipline => 'Discipline';

  @override
  String routeFormGrade(String system) {
    return 'Grade ($system)';
  }

  @override
  String get routeFormNoGrade => 'No grade yet';

  @override
  String get routeFormLength => 'Length in metres';

  @override
  String get routeFormPitches => 'Pitches';

  @override
  String routeFormPitch(int number) {
    return 'Pitch $number';
  }

  @override
  String formNumberInvalid(int max) {
    return 'Enter a number from 1 to $max.';
  }

  @override
  String get routeFormAngle => 'Angle';

  @override
  String get routeFormFeatures => 'Features';

  @override
  String get routeFormHolds => 'Holds';

  @override
  String get routeFormProtection => 'Protection';

  @override
  String get routeFormDescent => 'Descent';

  @override
  String get routeFormRope => 'Rope needed';

  @override
  String get routeFormFirstAscent => 'First ascent';

  @override
  String get routeFormFirstAscentHint => 'Names and year';

  @override
  String get routeFormSave => 'Save route';

  @override
  String get formSaveFailed =>
      'Couldn\'t save. Check the fields and try again.';

  @override
  String get cragAdd => 'New crag';

  @override
  String get cragFormTitle => 'New crag';

  @override
  String get cragFormNameMissing => 'Give the crag a name.';

  @override
  String get cragFormCountry => 'Country code';

  @override
  String get cragFormCountryInvalid => 'Use two letters, such as NO.';

  @override
  String get cragFormRock => 'Rock type';

  @override
  String get cragFormLatitude => 'Latitude';

  @override
  String get cragFormLongitude => 'Longitude';

  @override
  String get cragFormLocationHint =>
      'Decimal degrees, such as 59.92 and 10.50. Leave both empty if you are not sure.';

  @override
  String get cragFormLocationInvalid => 'Enter both, as decimal degrees.';

  @override
  String get cragFormSave => 'Save crag';

  @override
  String formLengthInvalid(int max) {
    return 'Enter a length in metres, up to $max.';
  }

  @override
  String get logWhere => 'Where did you climb?';

  @override
  String get logOutdoor => 'Outdoor';

  @override
  String get logOutdoorHint => 'Crags and mountains';

  @override
  String get logIndoor => 'Indoor gym';

  @override
  String get logIndoorHint => 'Walls and boards';

  @override
  String get logIndoorNoTiles =>
      'Nothing to tap yet. Add colours or choose a grading for this gym in Settings, under Gyms.';

  @override
  String get logIndoorLoadFailed =>
      'Couldn\'t load your gyms. Close the log and try again.';

  @override
  String logIndoorKind(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'boulder': 'boulder',
      'rope': 'rope',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get logIndoorNoGym => 'Set up your gym first: its walls and colours.';

  @override
  String get logIndoorNoWalls =>
      'This gym has no walls yet. Add them in Settings, under Gyms.';

  @override
  String get logIndoorGym => 'Gym';

  @override
  String get logIndoorFoundHere => 'Found from your location';

  @override
  String get logIndoorWall => 'Wall';

  @override
  String get logIndoorTapHint => 'Tap a colour each time you top it.';

  @override
  String get logIndoorUngraded => 'Climb';

  @override
  String logIndoorTopped(String colour, String kind) {
    return 'Topped $colour, $kind';
  }

  @override
  String logIndoorAddedSend(String colour) {
    return '$colour: send added';
  }

  @override
  String logIndoorAddedAttempt(String colour) {
    return '$colour: attempt added';
  }

  @override
  String get logIndoorUndo => 'Undo';

  @override
  String get logIndoorDidntTop => 'Didn\'t top';

  @override
  String get logIndoorToppedIt => 'Topped it';

  @override
  String get logIndoorTries => 'Tries';

  @override
  String get logIndoorFewerTries => 'Fewer tries';

  @override
  String get logIndoorMoreTries => 'More tries';

  @override
  String get logIndoorRopeType => 'On the rope';

  @override
  String logIndoorThisSession(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'This session · $count climbs',
      one: 'This session · 1 climb',
    );
    return '$_temp0';
  }

  @override
  String get logRoute => 'Route or problem';

  @override
  String get logChangeRoute => 'Change route';

  @override
  String get logStyle => 'Style';

  @override
  String get logTries => 'Tries';

  @override
  String get logTriesFewer => 'Fewer tries';

  @override
  String get logTriesMore => 'More tries';

  @override
  String get logHintSent =>
      'You have sent this route, so it logs as a repeat or an attempt.';

  @override
  String logHintTried(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'You have $count earlier tries on this route, so onsight and flash are not possible.',
      one: 'You have 1 earlier try on this route, so onsight and flash are not possible.',
    );
    return '$_temp0';
  }

  @override
  String get logHintBoulder => 'Boulders are flashed, not onsighted.';

  @override
  String get logRope => 'Rope';

  @override
  String ascentType(String type) {
    String _temp0 = intl.Intl.selectLogic(type, {
      'lead': 'Lead',
      'follow': 'Follow',
      'toprope': 'Top rope',
      'solo': 'Solo',
      'boulder': 'Boulder',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get logFeel => 'How it felt for the grade';

  @override
  String get logPersonalGrade => 'Your grade';

  @override
  String get logPersonalGradeNone => 'Same as the route';

  @override
  String get logTags => 'Describe it';

  @override
  String get logQuality => 'Quality';

  @override
  String logQualityLevel(String level) {
    String _temp0 = intl.Intl.selectLogic(level, {
      'q1': 'Good',
      'q2': 'Great',
      'q3': 'Classic',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get logAddClimb => 'Add climb and log another';

  @override
  String logClimbCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count climbs',
      one: '1 climb',
    );
    return '$_temp0';
  }

  @override
  String logRemoveClimb(String route) {
    return 'Remove $route';
  }

  @override
  String get logSession => 'Session';

  @override
  String get logDate => 'Date';

  @override
  String get logTitle => 'Title';

  @override
  String get logDescription => 'Description';

  @override
  String get logConditions => 'Conditions';

  @override
  String get logPartners => 'Partners';

  @override
  String get logPartnersHint => 'Names, separated by commas';

  @override
  String logSave(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Save session ($count climbs)',
      one: 'Save session',
    );
    return '$_temp0';
  }

  @override
  String get logSaved => 'Session saved';

  @override
  String logClimbRejected(int number) {
    return 'Climb $number no longer fits the style and tries rules. Check it and try again.';
  }

  @override
  String get logLaterClimbsRemoved =>
      'Later climbs on that route no longer fit the rules, so they were removed too.';

  @override
  String routeYourGrade(String grade) {
    return 'Your grade: $grade';
  }

  @override
  String routeYourFeel(String feel) {
    return 'How it felt: $feel';
  }

  @override
  String routeLoggedAt(String grade) {
    return 'graded $grade then';
  }

  @override
  String get cragFormMap => 'Map. Tap to place the crag.';

  @override
  String get cragFormLocationHintMap =>
      'Tap the map, or type decimal degrees such as 59.92 and 10.50. Leave both empty if you are not sure.';

  @override
  String season(String season) {
    String _temp0 = intl.Intl.selectLogic(season, {
      'spring': 'Spring',
      'summer': 'Summer',
      'autumn': 'Autumn',
      'winter': 'Winter',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String weatherTemp(String temp) {
    return '$temp °C';
  }

  @override
  String weatherRain(String mm) {
    return '$mm mm rain';
  }

  @override
  String weatherWind(String speed) {
    return '$speed m/s wind';
  }

  @override
  String get sessionNotFound =>
      'This session isn\'t on this phone. It may have been deleted.';

  @override
  String sessionWith(String names) {
    return 'With $names';
  }

  @override
  String get sessionClimbs => 'Climbs';

  @override
  String get sessionEdit => 'Edit session';

  @override
  String get sessionDelete => 'Delete session';

  @override
  String get sessionDeleteTitle => 'Delete this session?';

  @override
  String get sessionDeleteBody =>
      'Its climbs and partners are deleted with it. Later climbs on the same routes are recounted.';

  @override
  String get sessionDeleteLastBody =>
      'This is the session\'s last climb, so saving deletes the whole session.';

  @override
  String get sessionDeleteConfirm => 'Delete';

  @override
  String get sessionKeep => 'Keep';

  @override
  String get sessionDeleted => 'Session deleted';

  @override
  String get logEditTitle => 'Edit session';

  @override
  String get logEditExisting => 'In this session';

  @override
  String get logEditForgotten => 'Add a climb you forgot';

  @override
  String logEditMarked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count climbs are removed when you save.',
      one: '1 climb is removed when you save.',
    );
    return '$_temp0';
  }

  @override
  String logEditKeep(String route) {
    return 'Keep $route';
  }

  @override
  String get logEditSave => 'Save changes';

  @override
  String get logEditSaved => 'Changes saved';

  @override
  String get logLaterClimbRejected =>
      'A later climb on the same route depends on this one. Change or remove that climb first.';
}
