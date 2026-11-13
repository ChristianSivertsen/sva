// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Norwegian Bokmål (`nb`).
class AppLocalizationsNb extends AppLocalizations {
  AppLocalizationsNb([String locale = 'nb']) : super(locale);

  @override
  String get tabFeed => 'Feed';

  @override
  String get tabHistory => 'Historikk';

  @override
  String get tabCv => 'CV';

  @override
  String get tabTraining => 'Trening';

  @override
  String get logButton => 'Logg en økt';

  @override
  String get feedEmptyTitle => 'Øktene dine dukker opp her';

  @override
  String get feedEmptyBody =>
      'Logg din første økt, så havner den i feeden din. Øktene til vennene dine kommer senere.';

  @override
  String get feedOpenSession => 'Åpne økta';

  @override
  String feedSetting(String setting) {
    String _temp0 = intl.Intl.selectLogic(setting, {
      'outdoor': 'Ute',
      'indoor': 'Inne',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String feedWith(String names) {
    return 'med $names';
  }

  @override
  String feedMoreClimbs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count klatringer til',
      one: '+1 klatring til',
    );
    return '$_temp0';
  }

  @override
  String get feedStatPitches => 'Taulengder';

  @override
  String get feedStatClimbed => 'Klatret';

  @override
  String get feedStatElevation => 'Høydemeter';

  @override
  String get feedStatMetres => 'm';

  @override
  String get historyTitle => 'Historikk';

  @override
  String get historyEmptyTitle => 'Historikken din starter med én økt';

  @override
  String get historyEmptyBody =>
      'Dager ute, grader, pyramider og innsikt fylles ut etter hvert som du logger.';

  @override
  String get cvTitle => 'Klatre-CV';

  @override
  String get cvEmptyTitle => 'CV-en din bygger seg selv';

  @override
  String get cvEmptyBody =>
      'Hver rute du logger, bygger opp nivåene og erfaringen din og viser hva du ikke har prøvd ennå.';

  @override
  String get settingsOpen => 'Innstillinger';

  @override
  String get settingsTitle => 'Innstillinger';

  @override
  String get settingsTheme => 'Tema';

  @override
  String settingsThemeOption(String theme) {
    String _temp0 = intl.Intl.selectLogic(theme, {
      'system': 'Følg telefonen',
      'midnight': 'Midnattssol',
      'daylight': 'Dagslys',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get settingsLanguage => 'Språk';

  @override
  String get settingsLanguageSystem => 'Følg telefonen';

  @override
  String get settingsLanguageNb => 'Norsk (bokmål)';

  @override
  String get settingsLanguageEn => 'English';

  @override
  String get settingsGrades => 'Grader';

  @override
  String get settingsGradesNote =>
      'Gradene vises i disse systemene. Det du har logget, beholdes slik du logget det.';

  @override
  String settingsGradeType(String type) {
    String _temp0 = intl.Intl.selectLogic(type, {
      'free_route': 'Ruter',
      'boulder': 'Buldring',
      'ice': 'Is',
      'mixed': 'Mixed',
      'aid': 'Aid',
      'alpine': 'Alpint',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String gradeSystemName(String system) {
    String _temp0 = intl.Intl.selectLogic(system, {
      'nor': 'Norsk',
      'french': 'Fransk',
      'yds': 'YDS',
      'uiaa': 'UIAA',
      'font': 'Font',
      'v': 'V-skala',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get settingsVisibility => 'Nye økter er synlige for';

  @override
  String settingsVisibilityOption(String visibility) {
    String _temp0 = intl.Intl.selectLogic(visibility, {
      'private': 'Bare deg',
      'friends': 'Venner',
      'public': 'Alle',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get settingsVisibilityNote =>
      'Ingenting forlater telefonen før du logger inn.';

  @override
  String get settingsGyms => 'Klatresentre';

  @override
  String get settingsGymsNote =>
      'Legg inn klatresentrene du klatrer på én gang, så går loggingen raskt der.';

  @override
  String get settingsGymAdd => 'Legg til klatresenter';

  @override
  String get gymFormNew => 'Nytt klatresenter';

  @override
  String get gymFormEdit => 'Rediger klatresenter';

  @override
  String get gymFormNotFound =>
      'Klatresenteret finnes ikke på denne telefonen. Det kan ha blitt slettet.';

  @override
  String get gymFormNameMissing => 'Gi klatresenteret et navn.';

  @override
  String get gymFormMap => 'Kart. Trykk for å plassere klatresenteret.';

  @override
  String get gymFormGrading => 'Gradering';

  @override
  String gymGrading(String grading) {
    String _temp0 = intl.Intl.selectLogic(grading, {
      'colour': 'Fargeskala',
      'standard': 'Vanlige grader',
      'none': 'Ugradert',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get gymFormWalls => 'Vegger';

  @override
  String get gymFormWallsNote =>
      'Hver klatring du logger på en vegg får veggens høyde og starter med vinkelen. Vinkelen kan endres per klatring.';

  @override
  String get gymFormColours => 'Farger, letteste først';

  @override
  String get gymFormColoursNote =>
      'Gradespenn er valgfritt. Med spenn teller klatringer på fargen med midt i spennet i gradediagrammene. Uten spenn teller de likevel med i volum, vinkel og grep.';

  @override
  String get gymFormColourAdd => 'Legg til farge';

  @override
  String get gymFormColourName => 'Navn på fargen';

  @override
  String get gymFormColourNameMissing => 'Gi fargen et navn.';

  @override
  String gymFormColourPick(String name) {
    return 'Velg farge for $name';
  }

  @override
  String gymFormColourEasier(String name) {
    return 'Flytt $name opp';
  }

  @override
  String gymFormColourRemove(String name) {
    return 'Fjern $name';
  }

  @override
  String get gymFormColourBoulders => 'Buldring';

  @override
  String get gymFormColourRoutes => 'Ruter';

  @override
  String get gymFormColourUnmapped => 'Ikke satt';

  @override
  String get gymFormColourTo => 'til';

  @override
  String gymFormColourRangeFrom(String name, String kind) {
    return 'Letteste grad for $name ($kind)';
  }

  @override
  String gymFormColourRangeTo(String name, String kind) {
    return 'Vanskeligste grad for $name ($kind)';
  }

  @override
  String get gymColourGreen => 'Grønn';

  @override
  String get gymColourBlue => 'Blå';

  @override
  String gymColourNew(int number) {
    return 'Farge $number';
  }

  @override
  String get gymFormWallAdd => 'Legg til vegg';

  @override
  String get gymFormWallName => 'Navn på veggen';

  @override
  String get gymFormWallNameMissing => 'Gi veggen et navn.';

  @override
  String get gymFormWallHeight => 'Høyde i meter';

  @override
  String get gymFormWallHeightInvalid =>
      'Bruk en høyde fra 1 til 60 m, eller la feltet stå tomt.';

  @override
  String get gymFormWallKind => 'Type';

  @override
  String gymWallKind(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'rope': 'Tau',
      'boulder': 'Buldring',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get gymFormWallAngle => 'Vinkel';

  @override
  String get gymFormWallDegrees => 'Grader forbi loddrett';

  @override
  String get gymFormWallDegreesHelp =>
      'Valgfritt. Negativt for plater. Setter vinkelen for deg.';

  @override
  String get gymFormWallDegreesInvalid =>
      'Bruk hele grader fra -45 til 90, eller la feltet stå tomt.';

  @override
  String wallAngleDegrees(String angle, int degrees) {
    return '$angle $degrees°';
  }

  @override
  String gymFormWallRemove(String name) {
    return 'Fjern $name';
  }

  @override
  String get gymFormWallDefaultRope => 'Hovedvegg';

  @override
  String get gymFormWallDefaultBoulder => 'Buldreområde';

  @override
  String gymFormWallDefault(int number) {
    return 'Vegg $number';
  }

  @override
  String get gymFormWallReset => 'Skrudd om i dag';

  @override
  String gymFormWallResetLabel(String name) {
    return 'Merk $name som skrudd om i dag';
  }

  @override
  String gymFormWallResetOn(String date) {
    return 'Sist skrudd om $date';
  }

  @override
  String get gymFormWallNeverReset => 'Ikke skrudd om ennå';

  @override
  String gymFormWallResetDone(String name) {
    return '$name er merket som skrudd om i dag. De gamle rutene foreslås ikke lenger.';
  }

  @override
  String gymFormWallResetTitle(String name) {
    return 'Merke $name som skrudd om i dag?';
  }

  @override
  String gymFormWallResetBody(String name) {
    return 'Ruter på $name som du ikke har klatret til topps, avsluttes som prosjekter og foreslås ikke lenger. Klatringene dine på dem blir værende i loggen.';
  }

  @override
  String get gymFormWallResetCancel => 'Ikke nå';

  @override
  String get gymFormWallResetConfirm => 'Merk som skrudd om';

  @override
  String get gymFormSave => 'Lagre klatresenter';

  @override
  String get gymFormNotYours =>
      'Klatresenteret er delt, så bare veggene dine kan endres her.';

  @override
  String get settingsAbout => 'Om appen';

  @override
  String get settingsVersion => 'Versjon';

  @override
  String get settingsLicences => 'Lisenser';

  @override
  String get settingsSaveFailed =>
      'Kunne ikke lagre innstillingen. Prøv igjen.';

  @override
  String get trainingTitle => 'Trening';

  @override
  String get trainingEmptyTitle => 'Hold oversikt over styrke og bevegelighet';

  @override
  String get trainingEmptyBody =>
      'Tester av fingerstyrke, trekkraft, core og bevegelighet havner her, med fremgangen din over tid.';

  @override
  String get logSheetTitle => 'Logg en økt';

  @override
  String get close => 'Lukk';

  @override
  String get notFoundTitle => 'Denne siden finnes ikke';

  @override
  String get notFoundBody => 'Lenken kan være gammel eller feilskrevet.';

  @override
  String get notFoundAction => 'Gå til feeden';

  @override
  String get routeSearchOpen => 'Finn en rute';

  @override
  String get routeSearchTitle => 'Finn en rute';

  @override
  String get routeSearchField => 'Rute eller felt';

  @override
  String routeSearchNoMatch(String term) {
    return 'Ingen ruter passer til «$term».';
  }

  @override
  String get routeSearchEmpty =>
      'Ruter du legger til og klatrer, dukker opp her.';

  @override
  String get routeNotFound => 'Ruten finnes ikke, eller den er privat.';

  @override
  String get routeUngraded => 'Ugradert';

  @override
  String routeLength(int metres) {
    return '$metres m';
  }

  @override
  String routePitches(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count taulengder',
      one: '1 taulengde',
    );
    return '$_temp0';
  }

  @override
  String routeRopeLength(int metres) {
    return '$metres m tau';
  }

  @override
  String get routeDetails => 'Detaljer';

  @override
  String get routeYourClimbs => 'Dine klatringer';

  @override
  String get routeNotClimbed => 'Du har ikke logget denne ruten ennå.';

  @override
  String routeLastClimbed(String date) {
    return 'Sist klatret $date';
  }

  @override
  String discipline(String discipline) {
    String _temp0 = intl.Intl.selectLogic(discipline, {
      'sport': 'Sport',
      'trad': 'Trad',
      'boulder': 'Buldring',
      'alpine': 'Alpint',
      'ice': 'Is',
      'mixed': 'Mix',
      'aid': 'Teknisk',
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
      'repeat': 'Repetisjon',
      'attempt': 'Forsøk',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String ascentTries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count forsøk',
      one: '1 forsøk',
    );
    return '$_temp0';
  }

  @override
  String aspect(String direction) {
    String _temp0 = intl.Intl.selectLogic(direction, {
      'N': 'Vender mot nord',
      'NE': 'Vender mot nordøst',
      'E': 'Vender mot øst',
      'SE': 'Vender mot sørøst',
      'S': 'Vender mot sør',
      'SW': 'Vender mot sørvest',
      'W': 'Vender mot vest',
      'NW': 'Vender mot nordvest',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String attributeValue(String value) {
    String _temp0 = intl.Intl.selectLogic(value, {
      'rock_granite': 'Granitt',
      'rock_gneiss': 'Gneis',
      'rock_limestone': 'Kalkstein',
      'rock_sandstone': 'Sandstein',
      'rock_basalt': 'Basalt',
      'rock_conglomerate': 'Konglomerat',
      'rock_quartzite': 'Kvartsitt',
      'rock_schist': 'Skifer',
      'rock_dolerite': 'Doleritt',
      'angle_slab': 'Plate',
      'angle_vertical': 'Loddrett',
      'angle_overhang': 'Overheng',
      'angle_roof': 'Tak',
      'feature_face': 'Vegg',
      'feature_finger_crack': 'Fingerriss',
      'feature_hand_crack': 'Håndriss',
      'feature_offwidth': 'Offwidth',
      'feature_chimney': 'Kamin',
      'feature_corner': 'Hjørne',
      'feature_arete': 'Egg',
      'feature_tufa': 'Tufa',
      'feature_ice_pillar': 'Issøyle',
      'feature_ice_curtain': 'Isgardin',
      'feature_mixed_dry_tool': 'Drytooling',
      'hold_crimp': 'Lister',
      'hold_pocket': 'Hull',
      'hold_pinch': 'Klyper',
      'hold_sloper': 'Slopere',
      'hold_jug': 'Bøtter',
      'hold_undercling': 'Undertak',
      'hold_sidepull': 'Sidetak',
      'protection_bolted': 'Boltet',
      'protection_trad': 'Naturlig sikret',
      'protection_mixed': 'Blandet sikring',
      'protection_runout': 'Glissent sikret',
      'protection_none': 'Usikret',
      'protection_pads': 'Crashpads',
      'protection_ice_screws': 'Isskruer',
      'descent_lower_off': 'Fire ned',
      'descent_rappel': 'Rappell',
      'descent_walk_off': 'Gå ned',
      'descent_downclimb': 'Klatre ned',
      'descent_swim': 'Svømme',
      'feel_very_soft': 'Veldig soft',
      'feel_soft': 'Soft',
      'feel_fair': 'Riktig',
      'feel_hard': 'Hard',
      'feel_very_hard': 'Veldig hard',
      'tag_pumpy': 'Pumpete',
      'tag_techy': 'Teknisk',
      'tag_powerful': 'Kraftkrevende',
      'tag_scary': 'Skummel',
      'tag_sustained': 'Vedvarende',
      'tag_reachy': 'Krever rekkevidde',
      'tag_polished': 'Blankslitt',
      'tag_great_rock': 'Flott fjell',
      'tag_heady': 'Psykisk',
      'tag_balancy': 'Balansepreget',
      'condition_perfect': 'Perfekt',
      'condition_dry': 'Tørt',
      'condition_humid': 'Fuktig',
      'condition_damp': 'Rått',
      'condition_wet': 'Vått',
      'condition_icy': 'Islagt',
      'condition_windy': 'Vind',
      'condition_cold': 'Kaldt',
      'condition_hot': 'Varmt',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get routeAdd => 'Legg til en rute';

  @override
  String get routeFormTitle => 'Ny rute';

  @override
  String get formName => 'Navn';

  @override
  String get routeFormNameMissing => 'Gi ruten et navn.';

  @override
  String get routeFormCrag => 'Felt';

  @override
  String get routeFormCragMissing => 'Velg feltet ruten er i.';

  @override
  String routeFormRockFromCrag(String rock) {
    return 'Bergarten følger feltet: $rock.';
  }

  @override
  String get routeFormDiscipline => 'Disiplin';

  @override
  String routeFormGrade(String system) {
    return 'Grad ($system)';
  }

  @override
  String get routeFormNoGrade => 'Ingen grad ennå';

  @override
  String get routeFormLength => 'Lengde i meter';

  @override
  String get routeFormPitches => 'Taulengder';

  @override
  String routeFormPitch(int number) {
    return 'Taulengde $number';
  }

  @override
  String formNumberInvalid(int max) {
    return 'Skriv et tall fra 1 til $max.';
  }

  @override
  String get routeFormAngle => 'Vinkel';

  @override
  String get routeFormFeatures => 'Formasjoner';

  @override
  String get routeFormHolds => 'Grep';

  @override
  String get routeFormProtection => 'Sikring';

  @override
  String get routeFormDescent => 'Nedstigning';

  @override
  String get routeFormRope => 'Tau som trengs';

  @override
  String get routeFormFirstAscent => 'Førstebestigning';

  @override
  String get routeFormFirstAscentHint => 'Navn og år';

  @override
  String get routeFormSave => 'Lagre ruten';

  @override
  String get formSaveFailed => 'Kunne ikke lagre. Sjekk feltene og prøv igjen.';

  @override
  String get cragAdd => 'Nytt felt';

  @override
  String get cragFormTitle => 'Nytt felt';

  @override
  String get cragFormNameMissing => 'Gi feltet et navn.';

  @override
  String get cragFormCountry => 'Landskode';

  @override
  String get cragFormCountryInvalid => 'Bruk to bokstaver, som NO.';

  @override
  String get cragFormRock => 'Bergart';

  @override
  String get cragFormLatitude => 'Breddegrad';

  @override
  String get cragFormLongitude => 'Lengdegrad';

  @override
  String get cragFormLocationHint =>
      'Desimalgrader, for eksempel 59,92 og 10,50. La begge stå tomme hvis du er usikker.';

  @override
  String get cragFormLocationInvalid => 'Fyll inn begge, som desimalgrader.';

  @override
  String get cragFormSave => 'Lagre feltet';

  @override
  String formLengthInvalid(int max) {
    return 'Skriv en lengde i meter, opptil $max.';
  }

  @override
  String get logWhere => 'Hvor klatret du?';

  @override
  String get logOutdoor => 'Ute';

  @override
  String get logOutdoorHint => 'Felt og fjell';

  @override
  String get logIndoor => 'Klatresenter';

  @override
  String get logIndoorHint => 'Vegger og brett';

  @override
  String get logIndoorNoTiles =>
      'Ingenting å trykke på ennå. Legg inn farger eller velg gradering for klatresenteret under Innstillinger, Klatresentre.';

  @override
  String get logIndoorLoadFailed =>
      'Kunne ikke laste klatresentrene. Lukk loggen og prøv igjen.';

  @override
  String logIndoorKind(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'boulder': 'buldring',
      'rope': 'tau',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get logIndoorNoGym =>
      'Legg inn klatresenteret ditt først: veggene og fargene.';

  @override
  String get logIndoorNoWalls =>
      'Dette klatresenteret har ingen vegger ennå. Legg dem inn under Innstillinger, Klatresentre.';

  @override
  String get logIndoorGym => 'Klatresenter';

  @override
  String get logIndoorFoundHere => 'Funnet ut fra posisjonen din';

  @override
  String get logIndoorWall => 'Vegg';

  @override
  String get logIndoorTapHint => 'Trykk på en farge hver gang du toppet den.';

  @override
  String get logIndoorUngraded => 'Klatring';

  @override
  String logIndoorTopped(String colour, String kind) {
    return 'Toppet $colour, $kind';
  }

  @override
  String logIndoorAddedSend(String colour) {
    return '$colour: topp lagt til';
  }

  @override
  String logIndoorAddedAttempt(String colour) {
    return '$colour: forsøk lagt til';
  }

  @override
  String get logIndoorUndo => 'Angre';

  @override
  String get logIndoorDidntTop => 'Toppet ikke';

  @override
  String get logIndoorToppedIt => 'Toppet den';

  @override
  String get logIndoorTries => 'Forsøk';

  @override
  String get logIndoorFewerTries => 'Færre forsøk';

  @override
  String get logIndoorMoreTries => 'Flere forsøk';

  @override
  String get logIndoorRopeType => 'På tauet';

  @override
  String logIndoorThisSession(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Denne økta · $count klatringer',
      one: 'Denne økta · 1 klatring',
    );
    return '$_temp0';
  }

  @override
  String get logRoute => 'Rute eller problem';

  @override
  String get logChangeRoute => 'Bytt rute';

  @override
  String get logStyle => 'Stil';

  @override
  String get logTries => 'Forsøk';

  @override
  String get logTriesFewer => 'Færre forsøk';

  @override
  String get logTriesMore => 'Flere forsøk';

  @override
  String get logHintSent =>
      'Du har klatret ruten før, så den logges som repetisjon eller forsøk.';

  @override
  String logHintTried(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Du har $count tidligere forsøk på ruten, så onsight og flash er ikke mulig.',
      one: 'Du har 1 tidligere forsøk på ruten, så onsight og flash er ikke mulig.',
    );
    return '$_temp0';
  }

  @override
  String get logHintBoulder => 'Buldreproblemer flashes, de onsightes ikke.';

  @override
  String get logRope => 'Tau';

  @override
  String ascentType(String type) {
    String _temp0 = intl.Intl.selectLogic(type, {
      'lead': 'Leding',
      'follow': 'Andremann',
      'toprope': 'Topptau',
      'solo': 'Solo',
      'boulder': 'Buldring',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get logFeel => 'Hvordan graden føltes';

  @override
  String get logPersonalGrade => 'Din grad';

  @override
  String get logPersonalGradeNone => 'Samme som ruten';

  @override
  String get logTags => 'Beskriv den';

  @override
  String get logQuality => 'Kvalitet';

  @override
  String logQualityLevel(String level) {
    String _temp0 = intl.Intl.selectLogic(level, {
      'q1': 'Bra',
      'q2': 'Svært bra',
      'q3': 'Klassiker',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get logAddClimb => 'Legg til og logg en til';

  @override
  String logClimbCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count klatringer',
      one: '1 klatring',
    );
    return '$_temp0';
  }

  @override
  String logRemoveClimb(String route) {
    return 'Fjern $route';
  }

  @override
  String get logSession => 'Økt';

  @override
  String get logDate => 'Dato';

  @override
  String get logTitle => 'Tittel';

  @override
  String get logDescription => 'Beskrivelse';

  @override
  String get logConditions => 'Forhold';

  @override
  String get logPartners => 'Klatrepartnere';

  @override
  String get logPartnersHint => 'Navn, skilt med komma';

  @override
  String logSave(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Lagre økten ($count klatringer)',
      one: 'Lagre økten',
    );
    return '$_temp0';
  }

  @override
  String get logSaved => 'Økten er lagret';

  @override
  String logClimbRejected(int number) {
    return 'Klatring $number passer ikke lenger med reglene for stil og forsøk. Sjekk den og prøv igjen.';
  }

  @override
  String get logLaterClimbsRemoved =>
      'Senere klatringer på ruten passet ikke lenger med reglene, så de ble også fjernet.';

  @override
  String routeYourGrade(String grade) {
    return 'Din grad: $grade';
  }

  @override
  String routeYourFeel(String feel) {
    return 'Opplevd som: $feel';
  }

  @override
  String routeLoggedAt(String grade) {
    return 'gradert $grade da';
  }

  @override
  String get cragFormMap => 'Kart. Trykk for å plassere feltet.';

  @override
  String get cragFormLocationHintMap =>
      'Trykk på kartet, eller skriv desimalgrader, for eksempel 59,92 og 10,50. La begge stå tomme hvis du er usikker.';

  @override
  String season(String season) {
    String _temp0 = intl.Intl.selectLogic(season, {
      'spring': 'Vår',
      'summer': 'Sommer',
      'autumn': 'Høst',
      'winter': 'Vinter',
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
    return '$mm mm regn';
  }

  @override
  String weatherWind(String speed) {
    return '$speed m/s vind';
  }

  @override
  String get sessionNotFound =>
      'Denne økta finnes ikke på telefonen. Den kan være slettet.';

  @override
  String sessionWith(String names) {
    return 'Med $names';
  }

  @override
  String get sessionClimbs => 'Klatringer';

  @override
  String get sessionEdit => 'Rediger økt';

  @override
  String get sessionDelete => 'Slett økt';

  @override
  String get sessionDeleteTitle => 'Slette denne økta?';

  @override
  String get sessionDeleteBody =>
      'Klatringene og partnerne slettes sammen med den. Senere klatringer på de samme rutene telles på nytt.';

  @override
  String get sessionDeleteLastBody =>
      'Dette er den siste klatringen i økta, så når du lagrer, slettes hele økta.';

  @override
  String get sessionDeleteConfirm => 'Slett';

  @override
  String get sessionKeep => 'Behold';

  @override
  String get sessionDeleted => 'Økta er slettet';

  @override
  String get logEditTitle => 'Rediger økt';

  @override
  String get logEditExisting => 'I denne økta';

  @override
  String get logEditForgotten => 'Legg til en klatring du glemte';

  @override
  String logEditMarked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count klatringer fjernes når du lagrer.',
      one: '1 klatring fjernes når du lagrer.',
    );
    return '$_temp0';
  }

  @override
  String logEditKeep(String route) {
    return 'Behold $route';
  }

  @override
  String get logEditSave => 'Lagre endringer';

  @override
  String get logEditSaved => 'Endringene er lagret';

  @override
  String get logLaterClimbRejected =>
      'En senere klatring på samme rute bygger på denne. Endre eller fjern den klatringen først.';
}
