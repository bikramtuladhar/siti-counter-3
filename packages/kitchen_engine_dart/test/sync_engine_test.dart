import 'package:kitchen_engine/kitchen_engine.dart';
import 'package:test/test.dart';

void main() {
  group('UuidV7 Generator & Validation', () {
    test('generates valid RFC 9562 UUIDv7 strings', () {
      final uuid = UuidV7.generate();
      expect(UuidV7.isValid(uuid), isTrue);
      expect(uuid.length, equals(36));

      // Version nibble at index 14 must be '7'
      expect(uuid[14], equals('7'));

      // Variant character at index 19 must be one of 8, 9, a, b
      expect(['8', '9', 'a', 'b'].contains(uuid[19].toLowerCase()), isTrue);
    });

    test('extracts Unix timestamp accurately', () {
      final customMs = 1728000000123;
      final uuid = UuidV7.generate(timestampMs: customMs);

      expect(UuidV7.isValid(uuid), isTrue);
      final extracted = UuidV7.getTimestampMs(uuid);
      expect(extracted, equals(customMs));
    });

    test('generates chronologically and lexicographically ordered IDs within same millisecond', () {
      final fixedMs = 1728000000000;
      final ids = List.generate(5, (_) => UuidV7.generate(timestampMs: fixedMs));

      for (var i = 0; i < ids.length - 1; i++) {
        expect(ids[i].compareTo(ids[i + 1]), lessThan(0),
            reason: '${ids[i]} should be less than ${ids[i + 1]}');
      }
    });

    test('rejects invalid UUID formats', () {
      expect(UuidV7.isValid(''), isFalse);
      expect(UuidV7.isValid('not-a-uuid'), isFalse);
      // Valid v4 uuid (version 4)
      expect(UuidV7.isValid('c56a4180-65aa-42ec-a945-5fd21dec0538'), isFalse);
    });
  });

  group('SyncConflictResolver: Deterministic Last-Write-Wins (LWW)', () {
    test('higher record version strictly wins over lower version regardless of timestamp', () {
      final local = SyncChange(
        id: UuidV7.generate(timestampMs: 1000),
        householdId: 'h1',
        entityType: 'meal_plan',
        entityId: 'p1',
        version: 1,
        payload: {'dish': 'Dal Bhat'},
        createdAt: 1000,
      );

      final remote = SyncChange(
        id: UuidV7.generate(timestampMs: 900), // earlier timestamp, but version bumped
        householdId: 'h1',
        entityType: 'meal_plan',
        entityId: 'p1',
        version: 2,
        payload: {'dish': 'Khichdi'},
        createdAt: 900,
      );

      final res = SyncConflictResolver.resolve(local: local, remote: remote);
      expect(res.action, equals(SyncResolutionAction.applyRemote));
      expect(res.winner?.id, equals(remote.id));
      expect(res.effectivePayload?['dish'], equals('Khichdi'));
    });

    test('newer timestamp wins when versions are identical', () {
      final local = SyncChange(
        id: UuidV7.generate(timestampMs: 2000),
        householdId: 'h1',
        entityType: 'grocery_item',
        entityId: 'g1',
        version: 1,
        payload: {'status': 'in_cart'},
        createdAt: 2000,
      );

      final remote = SyncChange(
        id: UuidV7.generate(timestampMs: 1500),
        householdId: 'h1',
        entityType: 'grocery_item',
        entityId: 'g1',
        version: 1,
        payload: {'status': 'pending'},
        createdAt: 1500,
      );

      final res = SyncConflictResolver.resolve(local: local, remote: remote);
      expect(res.action, equals(SyncResolutionAction.keepLocal));
      expect(res.winner?.id, equals(local.id));
      expect(res.effectivePayload?['status'], equals('in_cart'));
    });

    test('deterministic lexicographical tiebreaker when version and timestamp match', () {
      const fixedMs = 3000;
      final id1 = '018f0000-0000-7000-8000-000000000001';
      final id2 = '018f0000-0000-7000-8000-000000000002';

      final local = SyncChange(
        id: id1,
        householdId: 'h1',
        entityType: 'batch',
        entityId: 'b1',
        version: 1,
        payload: {'state': 'local'},
        createdAt: fixedMs,
      );

      final remote = SyncChange(
        id: id2,
        householdId: 'h1',
        entityType: 'batch',
        entityId: 'b1',
        version: 1,
        payload: {'state': 'remote'},
        createdAt: fixedMs,
      );

      final res = SyncConflictResolver.resolve(local: local, remote: remote);
      // id2 > id1 lexicographically -> remote wins
      expect(res.action, equals(SyncResolutionAction.applyRemote));
      expect(res.winner?.id, equals(id2));
    });
  });

  group('SyncConflictResolver: Safety Gate for Allergies', () {
    test('conflicting allergy changes require user prompt and provide safe union merge', () {
      final local = SyncChange(
        id: UuidV7.generate(timestampMs: 2000),
        householdId: 'h1',
        entityType: 'member',
        entityId: 'm1',
        version: 2,
        payload: {
          'name': 'Aayush',
          'allergies': ['peanut', 'mustard'],
        },
        createdAt: 2000,
      );

      final remote = SyncChange(
        id: UuidV7.generate(timestampMs: 3000), // remote is newer and has higher version
        householdId: 'h1',
        entityType: 'member',
        entityId: 'm1',
        version: 3,
        payload: {
          'name': 'Aayush',
          'allergies': ['dairy'], // peanut and mustard were dropped in remote!
        },
        createdAt: 3000,
      );

      final res = SyncConflictResolver.resolve(local: local, remote: remote);

      // Must NOT silently overwrite peanut/mustard allergies
      expect(res.action, equals(SyncResolutionAction.promptUser));
      expect(res.conflict?.requiresPrompt, isTrue);
      expect(res.conflict?.reason, equals('ALLERGY_MODIFICATION_REQUIRES_CONFIRMATION'));

      // Effective payload must be a safe union: dairy, mustard, peanut
      final safeAllergies = res.effectivePayload?['allergies'] as List;
      expect(safeAllergies, containsAll(['dairy', 'mustard', 'peanut']));
    });

    test('identical allergy sets proceed with standard LWW', () {
      final local = SyncChange(
        id: UuidV7.generate(timestampMs: 1000),
        householdId: 'h1',
        entityType: 'member',
        entityId: 'm1',
        version: 1,
        payload: {
          'name': 'Sita',
          'allergies': ['dairy'],
        },
        createdAt: 1000,
      );

      final remote = SyncChange(
        id: UuidV7.generate(timestampMs: 1500),
        householdId: 'h1',
        entityType: 'member',
        entityId: 'm1',
        version: 2,
        payload: {
          'name': 'Sita Maya',
          'allergies': ['dairy'],
        },
        createdAt: 1500,
      );

      final res = SyncConflictResolver.resolve(local: local, remote: remote);
      expect(res.action, equals(SyncResolutionAction.applyRemote));
      expect(res.winner?.id, equals(remote.id));
      expect(res.effectivePayload?['name'], equals('Sita Maya'));
    });
  });
}
