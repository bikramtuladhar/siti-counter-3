import 'dart:convert';

import 'package:sqflite/sqflite.dart';

/// Durable key/value store for onboarding answers and household setup state.
///
/// Onboarding used to live only in a Flutter field, so every launch re-asked the same five
/// questions and the answers were lost. Persisting them here means the first-run answers
/// survive, and the progressive setup checklist on the home screen can tell what is still
/// missing across launches.
///
/// Values are stored as JSON strings so a richer answer (a list of stoves, a fasting
/// schedule) needs no schema change.
class SettingsRepository {
  final Database _db;

  SettingsRepository(this._db);

  /// Underlying handle, for callers that need to join against other tables in the same
  /// database rather than go through the key/value API.
  Database get database => _db;

  static const String tableName = 'app_settings';

  /// Bump when [createTables] gains a column, so existing installs migrate on open.
  static const int schemaVersion = 1;

  static Future<void> createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableName (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
  }

  static Future<SettingsRepository> openOnDisk([
    String path = 'siti_settings.db',
  ]) async {
    final db = await openDatabase(
      path,
      version: schemaVersion,
      onCreate: (db, version) => createTables(db),
    );
    return SettingsRepository(db);
  }

  /// Reads a raw JSON value, or null when unset.
  Future<Object?> read(String key) async {
    final rows = await _db.query(
      tableName,
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    try {
      return jsonDecode(rows.first['value'] as String);
    } on FormatException {
      // A corrupt value must not break startup; treat it as unset.
      return null;
    }
  }

  Future<void> write(String key, Object? value) async {
    await _db.insert(
      tableName,
      {
        'key': key,
        'value': jsonEncode(value),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<bool> readBool(String key, {bool fallback = false}) async {
    final value = await read(key);
    return value is bool ? value : fallback;
  }

  Future<int> readInt(String key, {int fallback = 0}) async {
    final value = await read(key);
    return value is num ? value.toInt() : fallback;
  }

  Future<double> readDouble(String key, {double fallback = 0}) async {
    final value = await read(key);
    return value is num ? value.toDouble() : fallback;
  }

  Future<String> readString(String key, {String fallback = ''}) async {
    final value = await read(key);
    return value is String ? value : fallback;
  }

  Future<List<String>> readStringList(String key) async {
    final value = await read(key);
    if (value is! List) return const [];
    return value.whereType<String>().toList();
  }

  Future<void> remove(String key) async {
    await _db.delete(tableName, where: 'key = ?', whereArgs: [key]);
  }

  /// All stored keys, useful for debugging a half-configured install.
  Future<Set<String>> keys() async {
    final rows = await _db.query(tableName, columns: ['key']);
    return rows.map((r) => r['key'] as String).toSet();
  }

  /// Well-known keys. Kept in one place so a typo cannot silently orphan a setting.
  static const String keyOnboardingComplete = 'onboarding_complete';
  static const String keyLanguage = 'language';
  static const String keyRegionPackId = 'region_pack_id';
  static const String keyStoveTypes = 'stove_types';
  static const String keyElevationMeters = 'elevation_meters';
  static const String keyDietaryRules = 'dietary_rules';
  static const String keyUnitSystem = 'unit_system';
  static const String keyCookingRhythm = 'cooking_rhythm';
  static const String keyFastingDays = 'fasting_days';
  static const String keyMealSlots = 'meal_slots';
  static const String keyIsGuest = 'is_guest';

  Future<void> clearAll() async {
    await _db.delete(tableName);
  }
}