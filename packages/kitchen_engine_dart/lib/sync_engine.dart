import 'dart:math';

/// RFC 9562 UUIDv7 generator and utility functions.
///
/// Layout:
/// - 48 bits: Unix timestamp in milliseconds (Big Endian)
/// - 4 bits: Version 7 (0b0111)
/// - 12 bits: Sub-millisecond sequence counter / random seed
/// - 2 bits: Variant 1 (0b10)
/// - 62 bits: Pseudo-random data
class UuidV7 {
  static final Random _random = Random.secure();
  static int _lastTimestampMs = -1;
  static int _sequence = 0;

  static final RegExp _uuidV7Regex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-7[0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );

  /// Generates a time-ordered UUIDv7 string.
  /// If [timestampMs] is omitted, [DateTime.now().millisecondsSinceEpoch] is used.
  static String generate({int? timestampMs}) {
    final now = timestampMs ?? DateTime.now().toUtc().millisecondsSinceEpoch;

    if (now == _lastTimestampMs) {
      _sequence = (_sequence + 1) & 0x0FFF;
    } else {
      _lastTimestampMs = now;
      _sequence = _random.nextInt(0x1000);
    }

    final tsHex = now.toRadixString(16).padLeft(12, '0');
    final timeHigh = tsHex.substring(0, 8);
    final timeMid = tsHex.substring(8, 12);

    final verAndSeq = '7${_sequence.toRadixString(16).padLeft(3, '0')}';

    // Variant: 0b10xxxxxx -> 8, 9, a, or b in hex
    final variantNibble = (0x8 | (_random.nextInt(4))).toRadixString(16);
    final randA = _random.nextInt(0x1000).toRadixString(16).padLeft(3, '0');
    final randB1 = _random.nextInt(0x10000).toRadixString(16).padLeft(4, '0');
    final randB2 = _random.nextInt(0x10000).toRadixString(16).padLeft(4, '0');
    final randB3 = _random.nextInt(0x10000).toRadixString(16).padLeft(4, '0');

    return '$timeHigh-$timeMid-$verAndSeq-$variantNibble$randA-$randB1$randB2$randB3'.toLowerCase();
  }

  /// Verifies whether [uuid] is a syntactically valid RFC 9562 UUIDv7.
  static bool isValid(String uuid) {
    return _uuidV7Regex.hasMatch(uuid);
  }

  /// Extracts the Unix timestamp in milliseconds from a valid UUIDv7.
  /// Returns `null` if invalid.
  static int? getTimestampMs(String uuid) {
    if (!isValid(uuid)) return null;
    final clean = uuid.replaceAll('-', '');
    final timeHex = clean.substring(0, 12);
    return int.tryParse(timeHex, radix: 16);
  }
}

/// Represents a single mutation change queued in the client outbox or received from remote D1.
class SyncChange {
  final String id; // UUIDv7
  final String householdId;
  final String entityType;
  final String entityId;
  final int version;
  final Map<String, dynamic> payload;
  final bool deleted;
  final int createdAt; // Unix epoch ms

  const SyncChange({
    required this.id,
    required this.householdId,
    required this.entityType,
    required this.entityId,
    required this.version,
    required this.payload,
    this.deleted = false,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'householdId': householdId,
        'entityType': entityType,
        'entityId': entityId,
        'version': version,
        'payload': payload,
        'deleted': deleted,
        'createdAt': createdAt,
      };

  factory SyncChange.fromJson(Map<String, dynamic> json) {
    return SyncChange(
      id: json['id'] as String,
      householdId: (json['householdId'] ?? '') as String,
      entityType: json['entityType'] as String,
      entityId: json['entityId'] as String,
      version: (json['version'] as num?)?.toInt() ?? 1,
      payload: (json['payload'] as Map<String, dynamic>?) ?? {},
      deleted: json['deleted'] as bool? ?? false,
      createdAt: (json['createdAt'] as num?)?.toInt() ??
          (UuidV7.getTimestampMs(json['id'] as String? ?? '') ?? DateTime.now().millisecondsSinceEpoch),
    );
  }

  SyncChange copyWith({
    String? id,
    String? householdId,
    String? entityType,
    String? entityId,
    int? version,
    Map<String, dynamic>? payload,
    bool? deleted,
    int? createdAt,
  }) {
    return SyncChange(
      id: id ?? this.id,
      householdId: householdId ?? this.householdId,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      version: version ?? this.version,
      payload: payload ?? this.payload,
      deleted: deleted ?? this.deleted,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Resolution outcome for conflicting mutations.
enum SyncResolutionAction {
  applyRemote,
  keepLocal,
  promptUser,
  applySafeMerge,
}

/// Information describing a detected conflict.
class SyncConflict {
  final String entityType;
  final String entityId;
  final String reason;
  final SyncChange localChange;
  final SyncChange remoteChange;
  final bool requiresPrompt;
  final Map<String, dynamic>? safeMergedPayload;

  const SyncConflict({
    required this.entityType,
    required this.entityId,
    required this.reason,
    required this.localChange,
    required this.remoteChange,
    required this.requiresPrompt,
    this.safeMergedPayload,
  });

  Map<String, dynamic> toJson() => {
        'entityType': entityType,
        'entityId': entityId,
        'reason': reason,
        'requiresPrompt': requiresPrompt,
        'safeMergedPayload': safeMergedPayload,
      };
}

/// Conflict resolution result containing the winning change or prompt requirement.
class SyncResolutionResult {
  final SyncResolutionAction action;
  final SyncChange? winner;
  final SyncConflict? conflict;
  final Map<String, dynamic>? effectivePayload;

  const SyncResolutionResult({
    required this.action,
    this.winner,
    this.conflict,
    this.effectivePayload,
  });
}

/// Deterministic conflict resolver implementing Last-Write-Wins with a safety gate for allergies.
class SyncConflictResolver {
  /// Resolves conflicts between a local change and a remote change.
  ///
  /// Safety Principle:
  /// Allergies and critical safety dietary rules must NEVER be silently discarded by stale syncs.
  /// If allergy sets conflict, a safe merge (union) is provided and user prompt is flagged.
  static SyncResolutionResult resolve({
    required SyncChange local,
    required SyncChange remote,
  }) {
    // 1. Safety Gate: Member Allergies & Dietary Restrictions
    if (local.entityType == 'member' ||
        local.payload.containsKey('allergies') ||
        remote.payload.containsKey('allergies')) {
      final localAllergies = _extractStringSet(local.payload['allergies']);
      final remoteAllergies = _extractStringSet(remote.payload['allergies']);

      final allergiesDiffer = !_setEquals(localAllergies, remoteAllergies);

      if (allergiesDiffer) {
        // Union of both allergy sets ensures no allergen is accidentally dropped
        final safeUnion = {...localAllergies, ...remoteAllergies}.toList()..sort();
        final safeMerged = Map<String, dynamic>.from(remote.payload);
        safeMerged['allergies'] = safeUnion;

        final conflict = SyncConflict(
          entityType: local.entityType,
          entityId: local.entityId,
          reason: 'ALLERGY_MODIFICATION_REQUIRES_CONFIRMATION',
          localChange: local,
          remoteChange: remote,
          requiresPrompt: true,
          safeMergedPayload: safeMerged,
        );

        return SyncResolutionResult(
          action: SyncResolutionAction.promptUser,
          conflict: conflict,
          effectivePayload: safeMerged,
          winner: remote.copyWith(payload: safeMerged),
        );
      }
    }

    // 2. Deterministic Last-Write-Wins (LWW)
    // Primary criterion: Record versioning
    if (remote.version > local.version) {
      return SyncResolutionResult(
        action: SyncResolutionAction.applyRemote,
        winner: remote,
        effectivePayload: remote.payload,
      );
    } else if (local.version > remote.version) {
      return SyncResolutionResult(
        action: SyncResolutionAction.keepLocal,
        winner: local,
        effectivePayload: local.payload,
      );
    }

    // Secondary criterion: Creation timestamp (Unix epoch ms)
    if (remote.createdAt > local.createdAt) {
      return SyncResolutionResult(
        action: SyncResolutionAction.applyRemote,
        winner: remote,
        effectivePayload: remote.payload,
      );
    } else if (local.createdAt > remote.createdAt) {
      return SyncResolutionResult(
        action: SyncResolutionAction.keepLocal,
        winner: local,
        effectivePayload: local.payload,
      );
    }

    // Tertiary tie-breaker: Lexicographical comparison of UUIDv7 strings
    if (remote.id.compareTo(local.id) > 0) {
      return SyncResolutionResult(
        action: SyncResolutionAction.applyRemote,
        winner: remote,
        effectivePayload: remote.payload,
      );
    } else {
      return SyncResolutionResult(
        action: SyncResolutionAction.keepLocal,
        winner: local,
        effectivePayload: local.payload,
      );
    }
  }

  static Set<String> _extractStringSet(dynamic value) {
    if (value is Iterable) {
      return value.map((e) => e.toString().trim().toLowerCase()).toSet();
    }
    return <String>{};
  }

  static bool _setEquals(Set<String> a, Set<String> b) {
    if (a.length != b.length) return false;
    return a.containsAll(b);
  }
}
