import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:sva_core/sva_core.dart'
    show AttributeValues, GradeSystem, LoggedAscent, convertGrade;
import 'package:sva_data/sva_data.dart';

/// The local database. `main` opens it on the device; tests override it
/// with [SvaDatabase.inMemory].
final databaseProvider = Provider<SvaDatabase>(
  (ref) => throw UnimplementedError('Override databaseProvider'),
);

/// The user id before sign-in, replaced on first sign-in (docs/schema.md,
/// profiles).
const localUserId = 'local';

/// The user whose rows screens read and write.
final currentUserIdProvider = Provider<String>((ref) => localUserId);

final Provider<AreaRepository> areaRepositoryProvider = Provider(
  (ref) => AreaRepository(ref.watch(databaseProvider)),
);
final Provider<RouteRepository> routeRepositoryProvider = Provider(
  (ref) => RouteRepository(ref.watch(databaseProvider)),
);
final Provider<AttributeRepository> attributeRepositoryProvider = Provider(
  (ref) => AttributeRepository(ref.watch(databaseProvider)),
);
final Provider<GymWallRepository> gymWallRepositoryProvider = Provider(
  (ref) => GymWallRepository(ref.watch(databaseProvider)),
);
final Provider<GymColourGradeRepository> gymColourGradeRepositoryProvider =
    Provider((ref) => GymColourGradeRepository(ref.watch(databaseProvider)));
final Provider<SessionRepository> sessionRepositoryProvider = Provider(
  (ref) => SessionRepository(ref.watch(databaseProvider)),
);
final Provider<AscentRepository> ascentRepositoryProvider = Provider(
  (ref) => AscentRepository(ref.watch(databaseProvider)),
);

/// The user's sessions, newest first, live.
final StreamProvider<List<Session>> mySessionsProvider = StreamProvider(
  (ref) => ref
      .watch(sessionRepositoryProvider)
      .watchMine(userId: ref.watch(currentUserIdProvider)),
);

/// One page of the user's sessions for the feed: the newest `limit`,
/// newest first, live.
final StreamProviderFamily<List<Session>, int> feedSessionsProvider =
    StreamProvider.autoDispose.family(
      (ref, limit) => ref
          .watch(sessionRepositoryProvider)
          .watchMine(userId: ref.watch(currentUserIdProvider), limit: limit),
    );

/// The features, holds and tags of one session's climbs as value keys,
/// in climb order without repeats. Follows the climbs.
final FutureProviderFamily<List<String>, String> sessionTagsProvider =
    FutureProvider.autoDispose.family((ref, sessionId) async {
      final climbs = await ref.watch(sessionAscentsProvider(sessionId).future);
      final attributes = ref.watch(attributeRepositoryProvider);
      final tags = <String>{};
      for (final climb in climbs) {
        final values = await attributes.resolvedForAscent(climb.id);
        for (final key in const ['feature', 'hold', 'tag']) {
          tags.addAll(values[key] ?? const []);
        }
      }
      return tags.toList();
    });

/// One session, or `null` once it is deleted, live.
final StreamProviderFamily<Session?, String> sessionProvider = StreamProvider
    .autoDispose
    .family((ref, id) => ref.watch(sessionRepositoryProvider).watch(id));

/// The partners' names on one session, live.
final StreamProviderFamily<List<String>, String> sessionPartnersProvider =
    StreamProvider.autoDispose.family(
      (ref, id) => ref.watch(sessionRepositoryProvider).watchPartners(id),
    );

/// The climbs in one session, in order, live.
final StreamProviderFamily<List<Ascent>, String> sessionAscentsProvider =
    StreamProvider.autoDispose.family(
      (ref, sessionId) =>
          ref.watch(ascentRepositoryProvider).watchInSession(sessionId),
    );

/// The places under one place (the top level for `null`), live.
final StreamProviderFamily<List<Area>, String?> areaChildrenProvider =
    StreamProvider.autoDispose.family(
      (ref, parentId) => ref
          .watch(areaRepositoryProvider)
          .watchChildren(parentId, userId: ref.watch(currentUserIdProvider)),
    );

/// The routes in one place, live.
final StreamProviderFamily<List<Route>, String> routesInAreaProvider =
    StreamProvider.autoDispose.family(
      (ref, areaId) => ref
          .watch(routeRepositoryProvider)
          .watchInArea(areaId, userId: ref.watch(currentUserIdProvider)),
    );

final Provider<GearPieceRepository> gearPieceRepositoryProvider = Provider(
  (ref) => GearPieceRepository(ref.watch(databaseProvider)),
);
final Provider<ShoeRepository> shoeRepositoryProvider = Provider(
  (ref) => ShoeRepository(ref.watch(databaseProvider)),
);
final Provider<BenchmarkDefRepository> benchmarkDefRepositoryProvider =
    Provider((ref) => BenchmarkDefRepository(ref.watch(databaseProvider)));
final Provider<BenchmarkResultRepository> benchmarkResultRepositoryProvider =
    Provider((ref) => BenchmarkResultRepository(ref.watch(databaseProvider)));
final Provider<ProjectRepository> projectRepositoryProvider = Provider(
  (ref) => ProjectRepository(ref.watch(databaseProvider)),
);
final Provider<GoalRepository> goalRepositoryProvider = Provider(
  (ref) => GoalRepository(ref.watch(databaseProvider)),
);

/// The user's rack, live.
final StreamProvider<List<GearPiece>> myGearProvider = StreamProvider(
  (ref) => ref
      .watch(gearPieceRepositoryProvider)
      .watchMine(userId: ref.watch(currentUserIdProvider)),
);

/// The user's shoes, in use first, live.
final StreamProvider<List<Shoe>> myShoesProvider = StreamProvider(
  (ref) => ref
      .watch(shoeRepositoryProvider)
      .watchMine(userId: ref.watch(currentUserIdProvider)),
);

/// The standard tests and the user's own, live.
final StreamProvider<List<BenchmarkDef>> benchmarksProvider = StreamProvider(
  (ref) => ref
      .watch(benchmarkDefRepositoryProvider)
      .watchAvailable(userId: ref.watch(currentUserIdProvider)),
);

/// The user's results on one test, oldest first, live.
final StreamProviderFamily<List<BenchmarkResult>, String>
benchmarkResultsProvider = StreamProvider.autoDispose.family(
  (ref, benchmarkId) => ref
      .watch(benchmarkResultRepositoryProvider)
      .watchFor(benchmarkId, userId: ref.watch(currentUserIdProvider)),
);

/// The user's active projects, live.
final StreamProvider<List<Project>> activeProjectsProvider = StreamProvider(
  (ref) => ref
      .watch(projectRepositoryProvider)
      .watchMine(userId: ref.watch(currentUserIdProvider), status: 'active'),
);

/// The user's active goals, soonest deadline first, live.
final StreamProvider<List<Goal>> activeGoalsProvider = StreamProvider(
  (ref) => ref
      .watch(goalRepositoryProvider)
      .watchMine(userId: ref.watch(currentUserIdProvider), status: 'active'),
);

/// Where route search measures "nearby" from: the user's latest outdoor
/// climbing place, until the app reads the phone's location. Follows new
/// sessions. Without one, or if the lookup fails, search simply skips
/// "nearby".
final FutureProvider<LatLon?> searchOriginProvider = FutureProvider.autoDispose(
  (ref) async {
    ref.watch(mySessionsProvider);
    try {
      return await ref
          .watch(sessionRepositoryProvider)
          .lastOutdoorLocation(userId: ref.watch(currentUserIdProvider));
    } on Object {
      return null;
    }
  },
);

/// Outdoor routes matching a search term, best first, live.
final StreamProviderFamily<List<RouteHit>, String> routeSearchProvider =
    StreamProvider.autoDispose.family((ref, term) async* {
      final near = await ref.watch(searchOriginProvider.future);
      yield* ref
          .watch(routeRepositoryProvider)
          .watchFind(
            term: term,
            userId: ref.watch(currentUserIdProvider),
            near: near,
          );
    });

/// One route as search shows it, or `null` when it is gone or private.
final FutureProviderFamily<RouteHit?, String> routeHitProvider = FutureProvider
    .autoDispose
    .family(
      (ref, routeId) => ref
          .watch(routeRepositoryProvider)
          .hit(routeId, userId: ref.watch(currentUserIdProvider)),
    );

/// A route's details, with what it inherits from its crag.
final FutureProviderFamily<AttributeValues, String> routeDetailsProvider =
    FutureProvider.autoDispose.family(
      (ref, routeId) => ref
          .watch(attributeRepositoryProvider)
          .resolvedForRoute(routeId, userId: ref.watch(currentUserIdProvider)),
    );

/// The user's climbs on one route, newest first, live.
final StreamProviderFamily<List<RouteClimb>, String> routeClimbsProvider =
    StreamProvider.autoDispose.family(
      (ref, routeId) => ref
          .watch(ascentRepositoryProvider)
          .watchOnRoute(routeId, userId: ref.watch(currentUserIdProvider)),
    );

/// Adds crags and routes from the forms.
final Provider<RouteEditor> routeEditorProvider = Provider(
  (ref) => RouteEditor(ref.watch(databaseProvider)),
);

/// Sets up gyms and their walls from the gym form.
final Provider<GymEditor> gymEditorProvider = Provider(
  (ref) => GymEditor(ref.watch(databaseProvider)),
);

/// The user's temporary gym routes: adding, projects, resets and gone.
final Provider<GymRouteRepository> gymRouteRepositoryProvider = Provider(
  (ref) => GymRouteRepository(ref.watch(databaseProvider)),
);

/// The gyms the user can see, by name, live.
final StreamProvider<List<Area>> gymsProvider = StreamProvider.autoDispose(
  (ref) => ref.watch(areaRepositoryProvider).watchOfTypes({
    'gym',
  }, userId: ref.watch(currentUserIdProvider)),
);

/// The crags and sectors a route can be added to, by name, live.
final StreamProvider<List<Area>> routePlacesProvider =
    StreamProvider.autoDispose(
      (ref) => ref.watch(areaRepositoryProvider).watchOfTypes({
        'crag',
        'sector',
      }, userId: ref.watch(currentUserIdProvider)),
    );

/// Every grade system on the device, easiest grade first.
final FutureProvider<List<GradeSystem>> gradeSystemsProvider = FutureProvider(
  (ref) => GradeRepository(ref.watch(databaseProvider)).systems(),
);

/// Saves logged sessions with their climbs.
final Provider<SessionLogger> sessionLoggerProvider = Provider(
  (ref) => SessionLogger(ref.watch(databaseProvider)),
);

/// The setting of the session the user logged last, so the log sheet opens
/// on the same choice.
final FutureProvider<String?> lastSettingProvider = FutureProvider.autoDispose(
  (ref) => ref
      .watch(sessionRepositoryProvider)
      .lastSetting(userId: ref.watch(currentUserIdProvider)),
);

/// What the user logged on a route up to and including one session,
/// oldest first: what a climb added to that session follows.
final FutureProviderFamily<List<RouteLogEntry>, (String, String)>
routeLogUpToProvider = FutureProvider.autoDispose.family(
  (ref, key) => ref
      .watch(ascentRepositoryProvider)
      .routeEntries(
        key.$1,
        userId: ref.watch(currentUserIdProvider),
        upToSession: key.$2,
      ),
);

/// What the user has logged on one route, oldest first, for the style and
/// tries rules.
final FutureProviderFamily<List<LoggedAscent>, String> routeLogProvider =
    FutureProvider.autoDispose.family(
      (ref, routeId) => ref
          .watch(ascentRepositoryProvider)
          .routeLog(routeId, userId: ref.watch(currentUserIdProvider)),
    );

/// Adds weather to sessions that lack it. `main` overrides this with the
/// one it runs on a timer, so every caller shares one run at a time.
final Provider<WeatherFiller> weatherFillerProvider = Provider(
  (ref) => WeatherFiller(ref.watch(databaseProvider), OpenMeteo()),
);

/// A session's weather, once fetched, live.
final StreamProviderFamily<WeatherSnapshot?, String> sessionWeatherProvider =
    StreamProvider.autoDispose.family(
      (ref, sessionId) =>
          ref.watch(sessionRepositoryProvider).watchWeather(sessionId),
    );

final Provider<SettingsRepository> settingsRepositoryProvider = Provider(
  (ref) => SettingsRepository(ref.watch(databaseProvider)),
);

/// The user's settings, live: theme, language, default visibility and
/// grade systems.
final StreamProvider<Settings> settingsProvider = StreamProvider(
  (ref) => ref
      .watch(settingsRepositoryProvider)
      .watch(ref.watch(currentUserIdProvider)),
);

/// Shows a grade label from system `systemKey` in the system the user
/// chose for its grade type. The stored grade never changes; a label that
/// cannot be converted, or one without a known system, shows as stored.
final Provider<String Function(String label, String? systemKey)>
gradeDisplayProvider = Provider((ref) {
  final systems = {
    for (final system
        in ref.watch(gradeSystemsProvider).value ?? const <GradeSystem>[])
      system.key: system,
  };
  final settings = ref.watch(settingsProvider).value ?? const Settings();
  return (label, systemKey) {
    final from = systems[systemKey];
    if (from == null) return label;
    final to = systems[settings.gradeSystemFor(from.gradeType)];
    if (to == null) return label;
    return convertGrade(label, from, to)?.label ?? label;
  };
});
