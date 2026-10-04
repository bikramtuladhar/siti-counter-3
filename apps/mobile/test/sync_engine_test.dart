import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchen_engine/kitchen_engine.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:siti_counter/sync/sync_repository.dart';
import 'package:siti_counter/sync/sync_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late SyncRepository repository;

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await SyncRepository.createTables(db);
    repository = SyncRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('SyncRepository SQLite Outbox Tests', () {
    test('enqueues mutations with valid UUIDv7 and version tracking', () async {
      final change1 = await repository.enqueueMutation(
        householdId: 'h1',
        entityType: 'meal_plan',
        entityId: 'plan_1',
        payload: {'dish': 'Dal Bhat'},
      );

      expect(UuidV7.isValid(change1.id), isTrue);
      expect(change1.version, equals(1));
      expect(change1.payload['dish'], equals('Dal Bhat'));

      // Second mutation to same entity increments version to 2
      final change2 = await repository.enqueueMutation(
        householdId: 'h1',
        entityType: 'meal_plan',
        entityId: 'plan_1',
        payload: {'dish': 'Dal Bhat Tarkari'},
      );

      expect(change2.version, equals(2));
      expect(change2.id, isNot(equals(change1.id)));

      final pending = await repository.getPendingOutbox();
      expect(pending.length, equals(2));
      expect(pending[0].id, equals(change1.id));
      expect(pending[1].id, equals(change2.id));
    });

    test('markChangesSynced removes applied mutations and updates last_sync_token', () async {
      final change1 = await repository.enqueueMutation(
        householdId: 'h1',
        entityType: 'grocery_item',
        entityId: 'g1',
        payload: {'bought': true},
      );
      final change2 = await repository.enqueueMutation(
        householdId: 'h1',
        entityType: 'grocery_item',
        entityId: 'g2',
        payload: {'bought': false},
      );

      expect((await repository.getPendingOutbox()).length, equals(2));

      await repository.markChangesSynced([change1.id], 'st_12345');

      final pendingAfter = await repository.getPendingOutbox();
      expect(pendingAfter.length, equals(1));
      expect(pendingAfter.first.id, equals(change2.id));

      final token = await repository.getLastSyncToken();
      expect(token, equals('st_12345'));
    });

    test('records and queries unresolved safety conflicts', () async {
      final local = SyncChange(
        id: UuidV7.generate(),
        householdId: 'h1',
        entityType: 'member',
        entityId: 'm1',
        version: 1,
        payload: {'allergies': ['peanut']},
        createdAt: 1000,
      );
      final remote = SyncChange(
        id: UuidV7.generate(),
        householdId: 'h1',
        entityType: 'member',
        entityId: 'm1',
        version: 2,
        payload: {'allergies': ['dairy']},
        createdAt: 2000,
      );

      final conflict = SyncConflict(
        entityType: 'member',
        entityId: 'm1',
        reason: 'ALLERGY_MODIFICATION_REQUIRES_CONFIRMATION',
        localChange: local,
        remoteChange: remote,
        requiresPrompt: true,
        safeMergedPayload: {
          'allergies': ['dairy', 'peanut']
        },
      );

      await repository.recordConflict(conflict);

      final pending = await repository.getPendingConflicts();
      expect(pending.length, equals(1));
      expect(pending.first['reason'], equals('ALLERGY_MODIFICATION_REQUIRES_CONFIRMATION'));
      expect(jsonDecode(pending.first['safe_merged_payload'] as String)['allergies'],
          containsAll(['dairy', 'peanut']));

      await repository.markConflictResolved(pending.first['id'] as String);
      final pendingAfter = await repository.getPendingConflicts();
      expect(pendingAfter.isEmpty, isTrue);
    });
  });

  group('SyncEngine Delta Sync & Network Transport Tests', () {
    test('successfully syncs outbox batch and updates sync token', () async {
      await repository.enqueueMutation(
        householdId: 'h_ktm',
        entityType: 'meal_plan',
        entityId: 'plan_sat',
        payload: {'recipe': 'Kwati'},
      );

      bool transportCalled = false;
      Map<String, dynamic>? sentBody;

      final engine = SyncEngine(
        repository: repository,
        householdId: 'h_ktm',
        transport: ({required url, required body, headers}) async {
          transportCalled = true;
          sentBody = body;
          return {
            'syncToken': 'st_99999',
            'applied': 1,
            'serverTime': '2026-10-04T05:00:00.000Z',
            'conflicts': [],
            'remoteChanges': [],
          };
        },
      );

      final res = await engine.syncNow();
      expect(res.success, isTrue);
      expect(res.appliedCount, equals(1));
      expect(res.syncToken, equals('st_99999'));
      expect(transportCalled, isTrue);
      expect(sentBody?['householdId'], equals('h_ktm'));

      final pendingAfter = await repository.getPendingOutbox();
      expect(pendingAfter.isEmpty, isTrue);
      expect(await repository.getLastSyncToken(), equals('st_99999'));
    });

    test('respects low-bandwidth batch budget (<30KB) by chunking mutations', () async {
      // Create mutations each with ~1KB payload
      final chunkData = 'A' * 1024;
      for (var i = 0; i < 35; i++) {
        await repository.enqueueMutation(
          householdId: 'h_budget',
          entityType: 'batch',
          entityId: 'batch_$i',
          payload: {'data': chunkData},
        );
      }

      int itemsSentInFirstPass = 0;
      final engine = SyncEngine(
        repository: repository,
        householdId: 'h_budget',
        transport: ({required url, required body, headers}) async {
          final changes = body['changes'] as List;
          itemsSentInFirstPass = changes.length;

          // Verify payload byte size stays strictly below 28KB (safe budget < 30KB)
          final payloadBytes = jsonEncode(body).length;
          expect(payloadBytes, lessThan(SyncEngine.maxBatchBytes));

          return {
            'syncToken': 'st_chunk_1',
            'applied': changes.length,
            'serverTime': '2026-10-04T05:00:00.000Z',
            'conflicts': [],
            'remoteChanges': [],
          };
        },
      );

      final res = await engine.syncNow();
      expect(res.success, isTrue);
      // Verify chunking: less than 35 items sent in first pass so size stays under 28KB
      expect(itemsSentInFirstPass, lessThan(35));
      expect(itemsSentInFirstPass, greaterThan(20));

      final remaining = await repository.getPendingOutbox();
      expect(remaining.length, equals(35 - itemsSentInFirstPass));
    });

    test('handles server allergy safety conflicts and records them in repository', () async {
      final change = await repository.enqueueMutation(
        householdId: 'h_safe',
        entityType: 'member',
        entityId: 'm_member_1',
        payload: {'name': 'Bikram', 'allergies': ['dairy']},
      );

      final engine = SyncEngine(
        repository: repository,
        householdId: 'h_safe',
        transport: ({required url, required body, headers}) async {
          return {
            'syncToken': 'st_conflict_1',
            'applied': 0,
            'serverTime': '2026-10-04T05:00:00.000Z',
            'conflicts': [
              {
                'id': change.id,
                'entityId': 'm_member_1',
                'entityType': 'member',
                'reason': 'ALLERGY_MODIFICATION_REQUIRES_CONFIRMATION',
                'message': 'Allergy modification requires explicit user confirmation.',
                'requiresPrompt': true,
                'safeMergedPayload': {
                  'name': 'Bikram',
                  'allergies': ['dairy', 'peanut']
                }
              }
            ],
            'remoteChanges': [],
          };
        },
      );

      final res = await engine.syncNow();
      expect(res.success, isTrue);
      expect(res.conflictsCount, equals(1));

      // Verify conflict recorded in SQLite
      final conflicts = await repository.getPendingConflicts();
      expect(conflicts.length, equals(1));
      expect(conflicts.first['reason'], equals('ALLERGY_MODIFICATION_REQUIRES_CONFIRMATION'));
    });

    test('lifecycle observer triggers sync on resumed and paused', () async {
      int syncTriggerCount = 0;

      final engine = SyncEngine(
        repository: repository,
        householdId: 'h_lifecycle',
        transport: ({required url, required body, headers}) async {
          syncTriggerCount++;
          return {
            'syncToken': 'st_live',
            'applied': 0,
            'serverTime': '2026-10-04T05:00:00.000Z',
            'conflicts': [],
            'remoteChanges': [],
          };
        },
      );

      final observer = SyncLifecycleObserver(engine);

      // App Resumed (Open) -> Sync triggered
      observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(syncTriggerCount, equals(1));

      // App Paused (Close/Background) -> Sync triggered
      observer.didChangeAppLifecycleState(AppLifecycleState.paused);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(syncTriggerCount, equals(2));

      // Post-cooking hook -> Sync triggered
      await engine.onCookingCompleted();
      expect(syncTriggerCount, equals(3));
    });
  });
}
