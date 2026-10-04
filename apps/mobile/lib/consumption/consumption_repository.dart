import 'dart:async';
import 'dart:convert';
import 'package:kitchen_engine/consumption_engine.dart';
import 'package:kitchen_engine/waste_engine.dart';
import 'package:sqflite/sqflite.dart';

/// SQLite-backed offline repository for consumption tracking and vessel calibration.
class ConsumptionRepository {
  final Database _db;

  ConsumptionRepository(this._db);

  /// Initializes the SQLite schema for consumption logs, outside foods, vessels, and members.
  static Future<void> createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS consumption_logs (
        id TEXT PRIMARY KEY,
        meal_plan_id TEXT,
        recipe_id TEXT NOT NULL,
        recipe_title TEXT NOT NULL,
        meal_slot TEXT NOT NULL,
        consumed_at TEXT NOT NULL,
        member_portions_json TEXT NOT NULL,
        total_servings REAL NOT NULL,
        logged_as_usual INTEGER NOT NULL,
        batch_yield_grams REAL,
        leftover_grams REAL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS outside_food_logs (
        id TEXT PRIMARY KEY,
        member_id TEXT NOT NULL,
        member_name TEXT NOT NULL,
        food_name TEXT NOT NULL,
        meal_slot TEXT NOT NULL,
        consumed_at TEXT NOT NULL,
        portion_size TEXT NOT NULL,
        estimated_calories INTEGER,
        tags_json TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS household_vessel_calibrations (
        vessel_id TEXT PRIMARY KEY,
        volume_ml REAL NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS household_members (
        member_id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT 'Adult',
        nutrition_profile TEXT NOT NULL DEFAULT 'everyday',
        portion_multiplier REAL NOT NULL DEFAULT 1.0,
        preferred_vessel_id TEXT NOT NULL DEFAULT 'katori',
        default_vessel_count REAL NOT NULL DEFAULT 1.0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS tracked_leftovers (
        id TEXT PRIMARY KEY,
        meal_log_id TEXT,
        recipe_id TEXT NOT NULL,
        title_en TEXT NOT NULL,
        title_ne TEXT NOT NULL,
        servings_remaining INTEGER NOT NULL,
        remaining_grams REAL NOT NULL,
        prepared_at TEXT NOT NULL,
        use_by_date TEXT NOT NULL,
        storage_condition TEXT NOT NULL,
        is_consumed INTEGER NOT NULL DEFAULT 0,
        consumed_at TEXT,
        is_discarded INTEGER NOT NULL DEFAULT 0,
        discard_reason TEXT
      )
    ''');

    // Seed default household members if empty
    final existingMembers = await db.query('household_members');
    if (existingMembers.isEmpty) {
      final defaultMembers = [
        const MemberDietaryProfile(
          memberId: 'm1',
          name: 'Bikram',
          role: 'Adult',
          nutritionProfile: 'everyday',
          portionMultiplier: 1.0,
          preferredVesselId: 'plate',
          defaultVesselCount: 1.0,
        ),
        const MemberDietaryProfile(
          memberId: 'm2',
          name: 'Srijana',
          role: 'Adult',
          nutritionProfile: 'everyday',
          portionMultiplier: 0.8,
          preferredVesselId: 'katori',
          defaultVesselCount: 2.0,
        ),
        const MemberDietaryProfile(
          memberId: 'm3',
          name: 'Aayush',
          role: 'Child',
          nutritionProfile: 'child',
          portionMultiplier: 0.5,
          preferredVesselId: 'katori',
          defaultVesselCount: 1.0,
        ),
      ];

      final batch = db.batch();
      for (final m in defaultMembers) {
        batch.insert('household_members', {
          'member_id': m.memberId,
          'name': m.name,
          'role': m.role,
          'nutrition_profile': m.nutritionProfile,
          'portion_multiplier': m.portionMultiplier,
          'preferred_vessel_id': m.preferredVesselId,
          'default_vessel_count': m.defaultVesselCount,
        });
      }
      await batch.commit(noResult: true);
    }
  }

  /// Creates and opens a local on-disk SQLite database.
  static Future<ConsumptionRepository> openOnDisk([String path = 'siti_consumption.db']) async {
    final db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) => createTables(db),
    );
    return ConsumptionRepository(db);
  }

  /// Fetches configured household members.
  Future<List<MemberDietaryProfile>> getMembers() async {
    final rows = await _db.query('household_members');
    return rows.map((r) {
      return MemberDietaryProfile(
        memberId: r['member_id'] as String,
        name: r['name'] as String,
        role: r['role'] as String? ?? 'Adult',
        nutritionProfile: r['nutrition_profile'] as String? ?? 'everyday',
        portionMultiplier: (r['portion_multiplier'] as num?)?.toDouble() ?? 1.0,
        preferredVesselId: r['preferred_vessel_id'] as String? ?? 'katori',
        defaultVesselCount: (r['default_vessel_count'] as num?)?.toDouble() ?? 1.0,
      );
    }).toList();
  }

  /// Saves or updates a household member.
  Future<void> saveMember(MemberDietaryProfile member) async {
    await _db.insert(
      'household_members',
      {
        'member_id': member.memberId,
        'name': member.name,
        'role': member.role,
        'nutrition_profile': member.nutritionProfile,
        'portion_multiplier': member.portionMultiplier,
        'preferred_vessel_id': member.preferredVesselId,
        'default_vessel_count': member.defaultVesselCount,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Gets the household vessel calibration profile.
  Future<HouseholdVesselProfile> getVesselProfile() async {
    final rows = await _db.query('household_vessel_calibrations');
    final map = <String, double>{};
    for (final r in rows) {
      map[r['vessel_id'] as String] = (r['volume_ml'] as num).toDouble();
    }
    return HouseholdVesselProfile(customVolumes: map);
  }

  /// Saves or updates a vessel calibration.
  Future<void> saveVesselCalibration(String vesselId, double volumeMl) async {
    await _db.insert(
      'household_vessel_calibrations',
      {'vessel_id': vesselId, 'volume_ml': volumeMl},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Resets a vessel calibration to default standard.
  Future<void> resetVesselCalibration(String vesselId) async {
    await _db.delete(
      'household_vessel_calibrations',
      where: 'vessel_id = ?',
      whereArgs: [vesselId],
    );
  }

  /// Logs a home-cooked meal consumption record and automatically creates
  /// a tracked leftover ("Eat first") if yield exceeds consumed portions.
  Future<TrackedLeftover?> logMeal(
    MealConsumptionLog log, {
    StorageCondition storage = StorageCondition.refrigerated,
    ClimateZone climate = ClimateZone.temperate,
    DateTime? now,
  }) async {
    await _db.insert(
      'consumption_logs',
      {
        'id': log.id,
        'meal_plan_id': log.mealPlanId,
        'recipe_id': log.recipeId,
        'recipe_title': log.recipeTitle,
        'meal_slot': log.mealSlot,
        'consumed_at': log.consumedAt.toIso8601String(),
        'member_portions_json': jsonEncode(log.memberPortions.map((p) => p.toJson()).toList()),
        'total_servings': log.totalServings,
        'logged_as_usual': log.loggedAsUsual ? 1 : 0,
        'batch_yield_grams': log.batchYieldGrams,
        'leftover_grams': log.leftoverGrams,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    final leftover = WasteEngine.createFromMealLog(
      log: log,
      storage: storage,
      climate: climate,
      now: now,
    );

    if (leftover != null) {
      await saveLeftover(leftover);
    }

    return leftover;
  }

  /// Logs an outside food entry.
  Future<void> logOutsideFood(OutsideFoodEntry entry) async {
    await _db.insert(
      'outside_food_logs',
      {
        'id': entry.id,
        'member_id': entry.memberId,
        'member_name': entry.memberName,
        'food_name': entry.foodName,
        'meal_slot': entry.mealSlot,
        'consumed_at': entry.consumedAt.toIso8601String(),
        'portion_size': entry.portionSize,
        'estimated_calories': entry.estimatedCalories,
        'tags_json': jsonEncode(entry.tags),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Fetches meal consumption logs in a given time window.
  Future<List<MealConsumptionLog>> getMealLogs({
    DateTime? from,
    DateTime? to,
  }) async {
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (from != null) {
      whereClauses.add('consumed_at >= ?');
      whereArgs.add(from.toIso8601String());
    }
    if (to != null) {
      whereClauses.add('consumed_at <= ?');
      whereArgs.add(to.toIso8601String());
    }

    final rows = await _db.query(
      'consumption_logs',
      where: whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'consumed_at DESC',
    );

    return rows.map((r) {
      final portionsList = jsonDecode(r['member_portions_json'] as String) as List<dynamic>;
      final portions = portionsList
          .map((e) => MemberConsumptionEntry.fromJson(e as Map<String, dynamic>))
          .toList();

      return MealConsumptionLog(
        id: r['id'] as String,
        mealPlanId: r['meal_plan_id'] as String?,
        recipeId: r['recipe_id'] as String,
        recipeTitle: r['recipe_title'] as String,
        mealSlot: r['meal_slot'] as String,
        consumedAt: DateTime.parse(r['consumed_at'] as String),
        memberPortions: portions,
        totalServings: (r['total_servings'] as num).toDouble(),
        loggedAsUsual: (r['logged_as_usual'] as int) == 1,
        batchYieldGrams: (r['batch_yield_grams'] as num?)?.toDouble(),
        leftoverGrams: (r['leftover_grams'] as num?)?.toDouble(),
      );
    }).toList();
  }

  /// Fetches outside food entries in a given time window.
  Future<List<OutsideFoodEntry>> getOutsideFoodLogs({
    DateTime? from,
    DateTime? to,
  }) async {
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (from != null) {
      whereClauses.add('consumed_at >= ?');
      whereArgs.add(from.toIso8601String());
    }
    if (to != null) {
      whereClauses.add('consumed_at <= ?');
      whereArgs.add(to.toIso8601String());
    }

    final rows = await _db.query(
      'outside_food_logs',
      where: whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'consumed_at DESC',
    );

    return rows.map((r) {
      final tagsList = (jsonDecode(r['tags_json'] as String) as List<dynamic>).cast<String>();
      return OutsideFoodEntry(
        id: r['id'] as String,
        memberId: r['member_id'] as String,
        memberName: r['member_name'] as String,
        foodName: r['food_name'] as String,
        mealSlot: r['meal_slot'] as String,
        consumedAt: DateTime.parse(r['consumed_at'] as String),
        portionSize: r['portion_size'] as String,
        estimatedCalories: r['estimated_calories'] as int?,
        tags: tagsList,
      );
    }).toList();
  }

  /// Calculates weekly household summary using the core domain engine.
  Future<WeeklyHouseholdSummary> getWeeklySummary({
    required DateTime weekStart,
    required DateTime weekEnd,
  }) async {
    final members = await getMembers();
    final mealLogs = await getMealLogs(from: weekStart, to: weekEnd);
    final outsideLogs = await getOutsideFoodLogs(from: weekStart, to: weekEnd);

    return ConsumptionEngine.calculateWeeklySummary(
      weekStart: weekStart,
      weekEnd: weekEnd,
      mealLogs: mealLogs,
      outsideLogs: outsideLogs,
      members: members,
    );
  }

  /// Saves or updates a tracked leftover.
  Future<void> saveLeftover(TrackedLeftover leftover) async {
    await _db.insert(
      'tracked_leftovers',
      {
        'id': leftover.id,
        'meal_log_id': leftover.mealLogId,
        'recipe_id': leftover.recipeId,
        'title_en': leftover.titleEn,
        'title_ne': leftover.titleNe,
        'servings_remaining': leftover.servingsRemaining,
        'remaining_grams': leftover.remainingGrams,
        'prepared_at': leftover.preparedAt.toIso8601String(),
        'use_by_date': leftover.useByDate.toIso8601String(),
        'storage_condition': leftover.storageCondition.name,
        'is_consumed': leftover.isConsumed ? 1 : 0,
        'consumed_at': leftover.consumedAt?.toIso8601String(),
        'is_discarded': leftover.isDiscarded ? 1 : 0,
        'discard_reason': leftover.discardReason,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Fetches tracked leftovers, optionally filtering for only active (unconsumed, undiscarded).
  Future<List<TrackedLeftover>> getTrackedLeftovers({bool? activeOnly}) async {
    final where = activeOnly == true ? 'is_consumed = 0 AND is_discarded = 0' : null;
    final rows = await _db.query('tracked_leftovers', where: where, orderBy: 'use_by_date ASC');
    return rows.map((r) {
      return TrackedLeftover(
        id: r['id'] as String,
        mealLogId: r['meal_log_id'] as String?,
        recipeId: r['recipe_id'] as String,
        titleEn: r['title_en'] as String,
        titleNe: r['title_ne'] as String,
        servingsRemaining: r['servings_remaining'] as int,
        remainingGrams: (r['remaining_grams'] as num).toDouble(),
        preparedAt: DateTime.parse(r['prepared_at'] as String),
        useByDate: DateTime.parse(r['use_by_date'] as String),
        storageCondition: (r['storage_condition'] as String) == 'roomTemperature'
            ? StorageCondition.roomTemperature
            : StorageCondition.refrigerated,
        isConsumed: (r['is_consumed'] as int) == 1,
        consumedAt: r['consumed_at'] != null ? DateTime.parse(r['consumed_at'] as String) : null,
        isDiscarded: (r['is_discarded'] as int) == 1,
        discardReason: r['discard_reason'] as String?,
      );
    }).toList();
  }

  /// Marks a leftover as consumed (food saved).
  Future<void> markLeftoverConsumed(String id, [DateTime? consumedAt]) async {
    await _db.update(
      'tracked_leftovers',
      {
        'is_consumed': 1,
        'consumed_at': (consumedAt ?? DateTime.now()).toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Marks a leftover as discarded.
  Future<void> markLeftoverDiscarded(String id, [String? reason]) async {
    await _db.update(
      'tracked_leftovers',
      {
        'is_discarded': 1,
        'discard_reason': reason ?? 'expired',
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Calculates household waste summary and recurring insights.
  Future<HouseholdWasteSummary> getWasteSummary({
    DateTime? now,
    int? daysBack,
  }) async {
    final current = now ?? DateTime.now();
    final leftovers = await getTrackedLeftovers();
    final fromDate = current.subtract(Duration(days: daysBack ?? 30));
    final mealLogs = await getMealLogs(from: fromDate, to: current);

    return WasteEngine.calculateWasteSummary(
      leftovers: leftovers,
      recentMealLogs: mealLogs,
      now: current,
    );
  }

  /// Identifies recurring food waste patterns on specific weekdays.
  Future<List<WasteInsight>> getWasteInsights({
    int minimumOccurrences = 2,
    int? daysBack,
    DateTime? now,
  }) async {
    final current = now ?? DateTime.now();
    final fromDate = current.subtract(Duration(days: daysBack ?? 30));
    final mealLogs = await getMealLogs(from: fromDate, to: current);
    return WasteEngine.analyzeWastePatterns(
      mealLogs,
      minimumOccurrences: minimumOccurrences,
    );
  }
}
