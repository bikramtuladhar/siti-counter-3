import 'dart:convert';
import 'package:kitchen_engine/kitchen_engine.dart';
import 'package:sqflite/sqflite.dart';

/// SQLite-backed outbox queue and synchronization state store.
class SyncRepository {
  final Database _db;

  SyncRepository(this._db);

  /// Initializes the SQLite schema for outbox, sync metadata state, and conflicts.
  static Future<void> createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_outbox (
        id TEXT PRIMARY KEY,
        household_id TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        version INTEGER NOT NULL DEFAULT 1,
        payload TEXT NOT NULL,
        deleted INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        synced_at INTEGER,
        attempt_count INTEGER NOT NULL DEFAULT 0,
        last_error TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_state (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_conflicts (
        id TEXT PRIMARY KEY,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        reason TEXT NOT NULL,
        local_payload TEXT NOT NULL,
        remote_payload TEXT NOT NULL,
        safe_merged_payload TEXT,
        created_at INTEGER NOT NULL,
        resolved_at INTEGER
      )
    ''');

    // Server-authoritative mirror of the household's entities. `POST /v1/sync` returns
    // remoteChanges; applying them here is what gives the app an offline copy of server
    // state to render from (and what the glanceable display feed is derived from).
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_entities (
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        household_id TEXT NOT NULL,
        version INTEGER NOT NULL,
        payload TEXT NOT NULL,
        deleted INTEGER NOT NULL DEFAULT 0,
        server_timestamp INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        PRIMARY KEY (household_id, entity_type, entity_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS display_feed_cache (
        household_id TEXT PRIMARY KEY,
        etag TEXT,
        payload TEXT NOT NULL,
        fetched_at INTEGER NOT NULL
      )
    ''');
  }

  /// Creates and opens a local on-disk SQLite database for synchronization.
  static Future<SyncRepository> openOnDisk([String path = 'siti_sync.db']) async {
    final db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) => createTables(db),
    );
    return SyncRepository(db);
  }

  /// Enqueues a local entity mutation to the outbox with a time-ordered UUIDv7.
  Future<SyncChange> enqueueMutation({
    required String householdId,
    required String entityType,
    required String entityId,
    required Map<String, dynamic> payload,
    bool deleted = false,
  }) async {
    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    final changeId = UuidV7.generate(timestampMs: nowMs);

    // Find the latest version for this entity in the outbox
    final existing = await _db.query(
      'sync_outbox',
      columns: ['version'],
      where: 'household_id = ? AND entity_type = ? AND entity_id = ?',
      whereArgs: [householdId, entityType, entityId],
      orderBy: 'version DESC',
      limit: 1,
    );

    final nextVersion = existing.isNotEmpty ? (existing.first['version'] as int) + 1 : 1;

    final change = SyncChange(
      id: changeId,
      householdId: householdId,
      entityType: entityType,
      entityId: entityId,
      version: nextVersion,
      payload: payload,
      deleted: deleted,
      createdAt: nowMs,
    );

    await _db.insert(
      'sync_outbox',
      {
        'id': change.id,
        'household_id': change.householdId,
        'entity_type': change.entityType,
        'entity_id': change.entityId,
        'version': change.version,
        'payload': jsonEncode(change.payload),
        'deleted': change.deleted ? 1 : 0,
        'created_at': change.createdAt,
        'synced_at': null,
        'attempt_count': 0,
        'last_error': null,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return change;
  }

  /// Retrieves pending unsynced changes ordered chronologically by created_at.
  Future<List<SyncChange>> getPendingOutbox({int limit = 50}) async {
    final rows = await _db.query(
      'sync_outbox',
      where: 'synced_at IS NULL',
      orderBy: 'created_at ASC',
      limit: limit,
    );

    return rows.map((row) {
      return SyncChange(
        id: row['id'] as String,
        householdId: row['household_id'] as String,
        entityType: row['entity_type'] as String,
        entityId: row['entity_id'] as String,
        version: row['version'] as int,
        payload: jsonDecode(row['payload'] as String) as Map<String, dynamic>,
        deleted: (row['deleted'] as int) == 1,
        createdAt: row['created_at'] as int,
      );
    }).toList();
  }

  /// Acknowledges applied mutations by removing them from outbox and persisting the sync token.
  Future<void> markChangesSynced(List<String> changeIds, String? syncToken) async {
    if (changeIds.isNotEmpty) {
      final placeholders = List.filled(changeIds.length, '?').join(',');
      await _db.delete(
        'sync_outbox',
        where: 'id IN ($placeholders)',
        whereArgs: changeIds,
      );
    }

    if (syncToken != null && syncToken.isNotEmpty) {
      await setSyncState('last_sync_token', syncToken);
      await setSyncState('last_sync_timestamp', DateTime.now().millisecondsSinceEpoch.toString());
    }
  }

  /// Increments attempt count and logs error for failed outbox entries.
  Future<void> markAttemptFailed(List<String> changeIds, String error) async {
    if (changeIds.isEmpty) return;
    final placeholders = List.filled(changeIds.length, '?').join(',');
    await _db.rawUpdate(
      '''
      UPDATE sync_outbox
      SET attempt_count = attempt_count + 1, last_error = ?
      WHERE id IN ($placeholders)
      ''',
      [error, ...changeIds],
    );
  }

  /// Reads a value from sync metadata state.
  Future<String?> getSyncState(String key) async {
    final rows = await _db.query(
      'sync_state',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  /// Sets or updates a key-value pair in sync metadata state.
  Future<void> setSyncState(String key, String value) async {
    await _db.insert(
      'sync_state',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Retrieves the last saved sync token.
  Future<String?> getLastSyncToken() => getSyncState('last_sync_token');

  /// Records an unresolved or safety conflict.
  Future<void> recordConflict(SyncConflict conflict) async {
    final conflictId = UuidV7.generate();
    await _db.insert(
      'sync_conflicts',
      {
        'id': conflictId,
        'entity_type': conflict.entityType,
        'entity_id': conflict.entityId,
        'reason': conflict.reason,
        'local_payload': jsonEncode(conflict.localChange.payload),
        'remote_payload': jsonEncode(conflict.remoteChange.payload),
        'safe_merged_payload':
            conflict.safeMergedPayload != null ? jsonEncode(conflict.safeMergedPayload) : null,
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'resolved_at': null,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Returns all active unresolved conflicts requiring attention.
  Future<List<Map<String, dynamic>>> getPendingConflicts() async {
    return _db.query(
      'sync_conflicts',
      where: 'resolved_at IS NULL',
      orderBy: 'created_at ASC',
    );
  }

  /// Applies server-authoritative changes into the local entity mirror.
  ///
  /// Version-guarded: a remote change older than what is already cached is ignored, so a
  /// late-arriving delta cannot roll the local cache backwards. Tombstones are kept rather
  /// than dropped, otherwise a delete could be undone by a stale delta.
  Future<int> applyRemoteChanges(
    String householdId,
    List<SyncChange> remoteChanges,
  ) async {
    if (remoteChanges.isEmpty) return 0;

    var applied = 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    await _db.transaction((txn) async {
      for (final change in remoteChanges) {
        final existing = await txn.query(
          'sync_entities',
          columns: ['version'],
          where:
              'household_id = ? AND entity_type = ? AND entity_id = ?',
          whereArgs: [householdId, change.entityType, change.entityId],
          limit: 1,
        );

        if (existing.isNotEmpty && (existing.first['version'] as int) >= change.version) {
          continue;
        }

        await txn.insert('sync_entities', {
          'entity_type': change.entityType,
          'entity_id': change.entityId,
          'household_id': householdId,
          'version': change.version,
          'payload': jsonEncode(change.payload),
          'deleted': change.deleted ? 1 : 0,
          'server_timestamp': change.createdAt,
          'updated_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        applied++;
      }
    });

    return applied;
  }

  /// Reads every cached entity for a household, optionally filtered by type and excluding
  /// tombstones. This is the offline source of truth the UI reads from.
  Future<List<SyncChange>> getCachedEntities({
    required String householdId,
    String? entityType,
    bool includeDeleted = false,
  }) async {
    final where = <String>['household_id = ?'];
    final whereArgs = <dynamic>[householdId];

    if (entityType != null) {
      where.add('entity_type = ?');
      whereArgs.add(entityType);
    }
    if (!includeDeleted) {
      where.add('deleted = 0');
    }

    final rows = await _db.query(
      'sync_entities',
      where: where.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'server_timestamp ASC',
    );

    return rows
        .map(
          (row) => SyncChange(
            id: '${row['entity_type']}:${row['entity_id']}',
            householdId: row['household_id'] as String,
            entityType: row['entity_type'] as String,
            entityId: row['entity_id'] as String,
            version: row['version'] as int,
            payload: jsonDecode(row['payload'] as String) as Map<String, dynamic>,
            deleted: (row['deleted'] as int) == 1,
            createdAt: row['server_timestamp'] as int,
          ),
        )
        .toList();
  }

  /// Persists the display feed payloads plus the ETag that produced them.
  Future<void> writeDisplayFeed(
    String householdId,
    Map<String, dynamic> payload, {
    String? etag,
  }) async {
    await _db.insert(
      'display_feed_cache',
      {
        'household_id': householdId,
        'etag': etag,
        'payload': jsonEncode(payload),
        'fetched_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Reads the cached display feed payloads and their ETag.
  Future<({Map<String, dynamic>? payload, String? etag})?> readDisplayFeed(
    String householdId,
  ) async {
    final rows = await _db.query(
      'display_feed_cache',
      where: 'household_id = ?',
      whereArgs: [householdId],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    final row = rows.first;
    return (
      payload: jsonDecode(row['payload'] as String) as Map<String, dynamic>,
      etag: row['etag'] as String?,
    );
  }

  /// Marks a conflict as resolved.
  Future<void> markConflictResolved(String conflictId) async {
    await _db.update(
      'sync_conflicts',
      {'resolved_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [conflictId],
    );
  }
}
