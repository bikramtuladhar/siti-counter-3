import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:kitchen_engine/kitchen_engine.dart';

import 'package:siti_counter/displays/companion_widget_service.dart';
import 'package:siti_counter/displays/display_feed_cache.dart';
import 'package:siti_counter/sync/sync_engine.dart';
import 'package:siti_counter/sync/sync_repository.dart';

/// Small helper so the cache tests do not repeat the SyncChange constructor.
class SyncChangeFixture {
  static SyncChange make({
    required String id,
    required String entityType,
    required String entityId,
    required int version,
    required Map<String, dynamic> payload,
    required int createdAt,
    bool deleted = false,
    String householdId = 'hh_test',
  }) {
    return SyncChange(
      id: id,
      householdId: householdId,
      entityType: entityType,
      entityId: entityId,
      version: version,
      payload: payload,
      deleted: deleted,
      createdAt: createdAt,
    );
  }
}

/// Builds a feed response shaped like `GET /v1/displays/feed`.
Map<String, dynamic> feedResponse({
  String etag = 'W/"abc"',
  int whistles = 2,
  int target = 4,
  List<Map<String, dynamic>> meals = const [],
}) {
  return {
    'etag': etag,
    'fetchedAt': '2026-10-05T04:00:00.000Z',
    'todaysMeals': {
      'dateIso': '2026-10-05',
      'rituNameEn': 'Sharad',
      'rituNameNe': 'शरद',
      'meals': meals,
      'totalPlannedMeals': meals.length,
    },
    'activeSiti': {
      'sessionId': 'sess_1',
      'dishTitleEn': 'Kalo Dal',
      'dishTitleNe': 'कालो दाल',
      'currentWhistles': whistles,
      'targetWhistles': target,
      'progressPercent': target == 0 ? 0 : ((whistles / target) * 100).round(),
      'isAlarmActive': target > 0 && whistles >= target,
      'status': target > 0 && whistles >= target ? 'alarm' : 'cooking',
      'isAlarmAcknowledged': false,
    },
    'groceryChecklist': {
      'totalItems': 2,
      'completedItems': 1,
      'pendingItems': 1,
      'previewItems': const [
        {
          'itemId': 'g1',
          'nameEn': 'Mustard Oil',
          'nameNe': 'तोरीको तेल',
          'quantityStr': '1L',
          'isCompleted': false,
        },
      ],
    },
    'watchState': {
      'sessionId': 'sess_1',
      'dishTitleEn': 'Kalo Dal',
      'dishTitleNe': 'कालो दाल',
      'currentWhistles': whistles,
      'targetWhistles': target,
      'currentStepIndex': 0,
      'totalSteps': 2,
      'currentStepInstructionEn': 'Soak the lentils',
      'currentStepInstructionNe': 'दाल भिजाउनुहोस्',
      'isAlarmActive': target > 0 && whistles >= target,
      'status': target > 0 && whistles >= target ? 'alarm' : 'cooking',
      'isAlarmAcknowledged': false,
      'lastHapticPattern': 'whistle',
    },
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late SyncRepository repository;

  setUp(() async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await SyncRepository.createTables(db);
    repository = SyncRepository(db);
  });

  group('Display feed cache-first hydration', () {
    test('hydrates from cache without touching the network', () async {
      final cache = InMemoryDisplayFeedCache();
      await cache.write(
        CompanionDisplaySnapshot.fromFeedJson(feedResponse()),
        etag: 'W/"abc"',
      );

      var transportCalls = 0;
      final service = CompanionWidgetService(
        cache: cache,
        transport: ({required url, headers}) async {
          transportCalls++;
          return feedResponse();
        },
      );

      await service.hydrateFromCache();

      expect(transportCalls, 0, reason: 'cache hydration must be network-free');
      expect(service.hasAnyPayload, isTrue);
      expect(service.activeSitiWidget!.dishTitleEn, 'Kalo Dal');
      expect(service.todaysMealsWidget!.rituNameEn, 'Sharad');
      expect(service.groceryChecklistWidget!.pendingItems, 1);
      expect(service.watchCompanionState!.currentStepInstructionEn, 'Soak the lentils');
    });

    test('an empty cache leaves the service empty rather than throwing', () async {
      final service = CompanionWidgetService(cache: InMemoryDisplayFeedCache());
      await service.hydrateFromCache();
      expect(service.hasAnyPayload, isFalse);
    });

    test('a malformed meal row is skipped rather than failing the whole feed', () async {
      final cache = SqliteDisplayFeedCache(
        repository: repository,
        householdId: 'hh_1',
      );
      // One meal entry is not an object. The rest of the feed is still usable, so the cache
      // must return a partial snapshot instead of throwing and bricking the widgets.
      await repository.writeDisplayFeed('hh_1', const {
        'todaysMeals': {
          'dateIso': '2026-10-05',
          'rituNameEn': 'Sharad',
          'rituNameNe': 'शरद',
          'meals': [
            'not-an-object',
            {
              'slotId': 'lunch',
              'slotTitleEn': 'Lunch',
              'slotTitleNe': 'दिउँसोको खाना',
              'recipeTitleEn': 'Khichdi',
              'recipeTitleNe': 'खिचडी',
              'servings': 2,
            },
          ],
          'totalPlannedMeals': 1,
        },
      });

      final snapshot = await cache.read();
      expect(snapshot, isNotNull);
      expect(snapshot!.todaysMeals!.totalPlannedMeals, 1);
      expect(snapshot.todaysMeals!.meals.single.recipeTitleEn, 'Khichdi');
    });

    test('an all-null cache row reads as a miss so the next refresh repopulates it', () async {
      final cache = SqliteDisplayFeedCache(
        repository: repository,
        householdId: 'hh_empty_row',
      );
      await repository.writeDisplayFeed('hh_empty_row', const {});

      expect(await cache.read(), isNull);
    });
  });

  group('Display feed ETag revalidation', () {
    test('sends If-None-Match and treats 304 as up to date', () async {
      final cache = InMemoryDisplayFeedCache();
      await cache.write(
        CompanionDisplaySnapshot.fromFeedJson(feedResponse()),
        etag: 'W/"abc"',
      );

      String? seenIfNoneMatch;
      final service = CompanionWidgetService(
        cache: cache,
        transport: ({required url, headers}) async {
          seenIfNoneMatch = headers?['If-None-Match'];
          return const {'notModified': true};
        },
      );

      await service.hydrateFromCache();
      final result = await service.refreshFromApi();

      expect(seenIfNoneMatch, 'W/"abc"');
      expect(result.notModified, isTrue);
      expect(result.refreshed, isFalse);
      // The previously cached payloads must survive a 304 untouched.
      expect(service.activeSitiWidget!.dishTitleEn, 'Kalo Dal');
    });

    test('a fresh payload replaces the cache and updates the ETag', () async {
      final cache = InMemoryDisplayFeedCache();
      await cache.write(
        CompanionDisplaySnapshot.fromFeedJson(feedResponse()),
        etag: 'W/"old"',
      );

      final service = CompanionWidgetService(
        cache: cache,
        transport: ({required url, headers}) async =>
            feedResponse(etag: 'W/"new"', whistles: 3, target: 4),
      );

      await service.hydrateFromCache();
      final result = await service.refreshFromApi();

      expect(result.refreshed, isTrue);
      expect(service.activeSitiWidget!.currentWhistles, 3);
      expect(await cache.readEtag(), 'W/"new"');
    });

    test('a failed refresh keeps serving the cached payloads', () async {
      final cache = InMemoryDisplayFeedCache();
      await cache.write(
        CompanionDisplaySnapshot.fromFeedJson(feedResponse()),
        etag: 'W/"abc"',
      );

      final service = CompanionWidgetService(
        cache: cache,
        transport: ({required url, headers}) async =>
            {'error': 'SERVER_ERROR', 'message': 'boom'},
      );

      await service.hydrateFromCache();
      final result = await service.refreshFromApi();

      expect(result.refreshed, isFalse);
      expect(result.errorMessage, 'boom');
      expect(service.activeSitiWidget!.dishTitleEn, 'Kalo Dal');
    });

    test('a transport exception is reported without clearing state', () async {
      final cache = InMemoryDisplayFeedCache();
      await cache.write(
        CompanionDisplaySnapshot.fromFeedJson(feedResponse()),
        etag: 'W/"abc"',
      );

      final service = CompanionWidgetService(
        cache: cache,
        transport: ({required url, headers}) async => throw Exception('offline'),
      );

      await service.hydrateFromCache();
      final result = await service.refreshFromApi();

      expect(result.refreshed, isFalse);
      expect(result.errorMessage, contains('offline'));
      expect(service.hasAnyPayload, isTrue);
    });

    test('the access token is sent as a bearer header', () async {
      String? seenAuth;
      final service = CompanionWidgetService(
        transport: ({required url, headers}) async {
          seenAuth = headers?['Authorization'];
          return feedResponse();
        },
      )..accessTokenProvider = () => 'atk_123';

      await service.refreshFromApi();
      expect(seenAuth, 'Bearer atk_123');
    });
  });

  group('SyncEngine applies remote changes into the entity cache', () {
    test('remoteChanges are persisted, not just counted', () async {
      final engine = SyncEngine(
        repository: repository,
        householdId: 'hh_remote',
        transport: ({required url, required body, headers}) async => {
          'syncToken': 'st_1000',
          'applied': 0,
          'serverTime': '2026-10-05T04:00:00.000Z',
          'conflicts': const [],
          'remoteChanges': [
            {
              'id': 'remote-1',
              'entityType': 'meal_plan',
              'entityId': 'slot_lunch',
              'version': 3,
              'payload': {'recipeTitleEn': 'Khichdi'},
              'deleted': false,
              'createdAt': 900,
            },
          ],
        },
      );

      final result = await engine.syncNow();

      expect(result.success, isTrue);
      expect(result.remoteCount, 1);
      expect(result.appliedRemoteCount, 1);

      final cached = await repository.getCachedEntities(householdId: 'hh_remote');
      expect(cached.length, 1);
      expect(cached.first.entityId, 'slot_lunch');
      expect(cached.first.version, 3);
      expect(cached.first.payload['recipeTitleEn'], 'Khichdi');
    });

    test('an older remote delta does not roll the cache backwards', () async {
      await repository.applyRemoteChanges('hh_stale', [
        SyncChangeFixture.make(
          id: 'r1',
          entityType: 'grocery_item',
          entityId: 'item_1',
          version: 5,
          payload: {'nameEn': 'Salt'},
          createdAt: 900,
        ),
      ]);

      final engine = SyncEngine(
        repository: repository,
        householdId: 'hh_stale',
        transport: ({required url, required body, headers}) async => {
          'syncToken': 'st_2000',
          'applied': 0,
          'serverTime': '2026-10-05T04:00:00.000Z',
          'conflicts': const [],
          'remoteChanges': [
            {
              'id': 'r2',
              'entityType': 'grocery_item',
              'entityId': 'item_1',
              'version': 2,
              'payload': {'nameEn': 'Stale Name'},
              'deleted': false,
              'createdAt': 800,
            },
          ],
        },
      );

      final result = await engine.syncNow();

      expect(result.appliedRemoteCount, 0);
      final cached = await repository.getCachedEntities(householdId: 'hh_stale');
      expect(cached.first.version, 5);
      expect(cached.first.payload['nameEn'], 'Salt');
    });

    test('a delete is stored as a tombstone and excluded by default', () async {
      final engine = SyncEngine(
        repository: repository,
        householdId: 'hh_delete',
        transport: ({required url, required body, headers}) async => {
          'syncToken': 'st_3000',
          'applied': 0,
          'serverTime': '2026-10-05T04:00:00.000Z',
          'conflicts': const [],
          'remoteChanges': [
            {
              'id': 'r3',
              'entityType': 'grocery_item',
              'entityId': 'item_gone',
              'version': 1,
              'payload': <String, dynamic>{},
              'deleted': true,
              'createdAt': 900,
            },
          ],
        },
      );

      final result = await engine.syncNow();

      expect(result.success, isTrue);
      expect(result.appliedRemoteCount, 1);
      expect(await repository.getCachedEntities(householdId: 'hh_delete'), isEmpty);
      final withDeleted = await repository.getCachedEntities(
        householdId: 'hh_delete',
        includeDeleted: true,
      );
      expect(withDeleted.first.deleted, isTrue);
    });
  });

  group('Cached entities filter by type', () {
    test('only the requested entity type is returned', () async {
      await repository.applyRemoteChanges('hh_filter', [
        SyncChangeFixture.make(
          id: 'a',
          entityType: 'meal_plan',
          entityId: 'm1',
          version: 1,
          payload: const {},
          createdAt: 100,
        ),
        SyncChangeFixture.make(
          id: 'b',
          entityType: 'grocery_item',
          entityId: 'g1',
          version: 1,
          payload: const {},
          createdAt: 200,
        ),
      ]);

      final mealPlans = await repository.getCachedEntities(
        householdId: 'hh_filter',
        entityType: 'meal_plan',
      );
      expect(mealPlans.length, 1);
      expect(mealPlans.first.entityType, 'meal_plan');
    });

    test('households are isolated from each other', () async {
      await repository.applyRemoteChanges('hh_one', [
        SyncChangeFixture.make(
          id: 'x',
          entityType: 'grocery_item',
          entityId: 'item_x',
          version: 1,
          payload: const {},
          createdAt: 100,
        ),
      ]);

      expect(
        await repository.getCachedEntities(householdId: 'hh_two'),
        isEmpty,
      );
    });
  });

  group('Display feed cache round-trip', () {
    test('payload and ETag survive a write/read cycle', () async {
      final cache = SqliteDisplayFeedCache(
        repository: repository,
        householdId: 'hh_rt',
      );

      await cache.write(
        CompanionDisplaySnapshot.fromFeedJson(feedResponse()),
        etag: 'W/"rt"',
      );

      final restored = await cache.read();
      expect(restored, isNotNull);
      expect(restored!.activeSiti!.dishTitleEn, 'Kalo Dal');
      expect(restored.groceryChecklist!.previewItems.first.nameEn, 'Mustard Oil');
      expect(await cache.readEtag(), 'W/"rt"');
    });

    test('the payload is stored as valid JSON', () async {
      final cache = SqliteDisplayFeedCache(
        repository: repository,
        householdId: 'hh_json',
      );
      await cache.write(
        CompanionDisplaySnapshot.fromFeedJson(feedResponse()),
        etag: 'W/"json"',
      );

      final raw = await repository.readDisplayFeed('hh_json');
      // Would throw if the stored row were not decodable.
      expect(jsonDecode(jsonEncode(raw!.payload)), isA<Map<String, dynamic>>());
    });
  });
}