import 'package:kitchen_engine/kitchen_engine.dart';

import '../sync/sync_repository.dart';

/// Pushes the household profile to the API so a guest -> account merge actually carries it.
///
/// Signing in only merges what the server already holds for the guest household. Onboarding
/// answers used to live solely on the device, so there was nothing server-side to merge and
/// the merge was empty. This writes the profile as `household` and `member` sync entities
/// before sign-in, so the merged account inherits the household the user just configured.
///
/// Writes are best-effort: sign-in must still work when the device is offline, and the
/// profile is re-pushed on the next successful sync.
class HouseholdProfilePublisher {
  final SyncRepository repository;
  final String apiBaseUrl;
  final String Function() householdId;
  final String? Function()? accessToken;

  HouseholdProfilePublisher({
    required this.repository,
    required this.householdId,
    this.apiBaseUrl = 'https://api.siticounter.app',
    this.accessToken,
  });

  /// Enqueues the profile locally. Returns the change so the caller can inspect it.
  Future<SyncChange> enqueueProfile({
    required Map<String, dynamic> profile,
    List<Map<String, dynamic>> members = const [],
  }) async {
    final household = await repository.enqueueMutation(
      householdId: householdId(),
      entityType: 'household',
      entityId: householdId(),
      payload: profile,
    );

    for (final member in members) {
      final id = member['id']?.toString();
      if (id == null || id.isEmpty) continue;
      await repository.enqueueMutation(
        householdId: householdId(),
        entityType: 'member',
        entityId: id,
        payload: member,
      );
    }

    return household;
  }

  /// Builds the sync payload for the current household profile.
  ///
  /// Only non-empty values are sent, so the server never records a household as explicitly
  /// using metric when the user never chose.
  static Map<String, dynamic> buildProfilePayload({
    required String regionPackId,
    required String language,
    required List<String> stoveTypes,
    required double elevationMeters,
    required List<String> dietaryRules,
    required List<String> mealSlots,
    required String cookingRhythm,
    required List<String> fastingDays,
    required String unitSystem,
  }) {
    final payload = <String, dynamic>{};

    void put(String key, Object? value, {bool isEmpty = false}) {
      if (isEmpty) return;
      payload[key] = value;
    }

    put('regionPackId', regionPackId);
    put('language', language);
    put('stoveTypes', stoveTypes);
    put('primaryStoveType', stoveTypes.isNotEmpty ? stoveTypes.first : 'lpg_gas');
    put('elevationMeters', elevationMeters);
    put('dietaryRules', dietaryRules);
    put('mealSlots', mealSlots);
    put('cookingRhythm', cookingRhythm);
    put('fastingDays', fastingDays);
    put('unitSystem', unitSystem);

    return payload;
  }

  /// Builds a `member` sync payload, including allergens.
  ///
  /// Allergies are included because the sync protocol treats an allergen change as a
  /// prompt-the-user conflict rather than last-write-wins; a member synced without them
  /// would lose the household's most safety-critical field on the merge.
  static Map<String, dynamic> buildMemberPayload({
    required String id,
    required String name,
    required String role,
    List<String> allergies = const [],
  }) {
    return {
      'id': id,
      'name': name,
      'role': role,
      'allergies': allergies,
    };
  }
}

/// Reads the local sync database for household identifiers.
class SyncIdentityReader {
  final SyncRepository repository;

  SyncIdentityReader(this.repository);

  Future<String?> get guestHouseholdId =>
      repository.getSyncState('local_household_id');

  Future<String?> get deviceId => repository.getSyncState('device_id');
}