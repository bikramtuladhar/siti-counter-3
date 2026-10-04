import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'planner_models.dart';

/// SQLite-backed offline repository for weekly meal planning and custom meal rhythms.
class WeeklyPlannerRepository {
  final Database _db;

  WeeklyPlannerRepository(this._db);

  /// Initializes the SQLite schema for slots, planned meals, and leftovers.
  static Future<void> createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS meal_rhythm_slots (
        id TEXT PRIMARY KEY,
        name_en TEXT NOT NULL,
        name_ne TEXT NOT NULL,
        default_time TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS planned_meals (
        id TEXT PRIMARY KEY,
        date_iso TEXT NOT NULL,
        slot_id TEXT NOT NULL,
        recipe_id TEXT NOT NULL,
        recipe_title_en TEXT NOT NULL,
        recipe_title_ne TEXT NOT NULL,
        servings INTEGER NOT NULL DEFAULT 4,
        is_leftover INTEGER NOT NULL DEFAULT 0,
        leftover_source_date TEXT,
        is_seasonal INTEGER NOT NULL DEFAULT 0,
        dietary_badges TEXT NOT NULL DEFAULT '',
        notes TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS leftovers (
        id TEXT PRIMARY KEY,
        recipe_id TEXT NOT NULL,
        title_en TEXT NOT NULL,
        title_ne TEXT NOT NULL,
        servings_remaining INTEGER NOT NULL DEFAULT 1,
        prepared_date_iso TEXT NOT NULL,
        use_by_date_iso TEXT NOT NULL,
        is_consumed INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS pantry_items (
        ingredient_id TEXT PRIMARY KEY,
        quantity_grams REAL NOT NULL DEFAULT 0,
        unit TEXT NOT NULL DEFAULT 'g',
        updated_at TEXT NOT NULL
      )
    ''');

    // Seed default Nepali meal rhythm if empty
    final existingSlots = await db.query('meal_rhythm_slots');
    if (existingSlots.isEmpty) {
      final batch = db.batch();
      for (final slot in MealRhythmSlot.defaultNepaliRhythm()) {
        batch.insert('meal_rhythm_slots', slot.toMap());
      }
      await batch.commit(noResult: true);
    }
  }

  /// Creates and opens a local on-disk SQLite database.
  static Future<WeeklyPlannerRepository> openOnDisk([String path = 'siti_planner.db']) async {
    final db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) => createTables(db),
    );
    return WeeklyPlannerRepository(db);
  }

  // --- Meal Rhythm Slots ---

  /// Retrieves active meal rhythm slots ordered by sortOrder.
  Future<List<MealRhythmSlot>> getActiveSlots() async {
    final rows = await _db.query(
      'meal_rhythm_slots',
      where: 'is_active = 1',
      orderBy: 'sort_order ASC',
    );
    return rows.map((r) => MealRhythmSlot.fromMap(r)).toList();
  }

  /// Saves or updates a meal rhythm slot.
  Future<void> saveSlot(MealRhythmSlot slot) async {
    await _db.insert(
      'meal_rhythm_slots',
      slot.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Deactivates or removes a meal rhythm slot.
  Future<void> deleteSlot(String slotId) async {
    await _db.update(
      'meal_rhythm_slots',
      {'is_active': 0},
      where: 'id = ?',
      whereArgs: [slotId],
    );
  }

  // --- Planned Meals ---

  /// Retrieves all planned meals for a 7-day range starting from [weekStartDate].
  Future<List<PlannedMeal>> getPlannedMealsForWeek(DateTime weekStartDate) async {
    final startIso = _formatDateIso(weekStartDate);
    final endIso = _formatDateIso(weekStartDate.add(const Duration(days: 6)));

    final rows = await _db.query(
      'planned_meals',
      where: 'date_iso >= ? AND date_iso <= ?',
      whereArgs: [startIso, endIso],
    );
    return rows.map((r) => PlannedMeal.fromMap(r)).toList();
  }

  /// Inserts or replaces a planned meal.
  Future<void> savePlannedMeal(PlannedMeal meal) async {
    await _db.insert(
      'planned_meals',
      meal.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Deletes a planned meal by id.
  Future<void> deletePlannedMeal(String mealId) async {
    await _db.delete(
      'planned_meals',
      where: 'id = ?',
      whereArgs: [mealId],
    );
  }

  /// Moves or swaps a planned meal to another day or slot.
  Future<void> movePlannedMeal({
    required String mealId,
    required String targetDateIso,
    required String targetSlotId,
  }) async {
    await _db.update(
      'planned_meals',
      {
        'date_iso': targetDateIso,
        'slot_id': targetSlotId,
      },
      where: 'id = ?',
      whereArgs: [mealId],
    );
  }

  // --- Leftovers ---

  /// Retrieves all active (unconsumed) leftovers.
  Future<List<LeftoverItem>> getActiveLeftovers() async {
    final rows = await _db.query(
      'leftovers',
      where: 'is_consumed = 0 AND servings_remaining > 0',
      orderBy: 'use_by_date_iso ASC',
    );
    return rows.map((r) => LeftoverItem.fromMap(r)).toList();
  }

  /// Saves or updates a leftover item.
  Future<void> saveLeftover(LeftoverItem item) async {
    await _db.insert(
      'leftovers',
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Marks a leftover as consumed.
  Future<void> markLeftoverConsumed(String leftoverId) async {
    await _db.update(
      'leftovers',
      {'is_consumed': 1, 'servings_remaining': 0},
      where: 'id = ?',
      whereArgs: [leftoverId],
    );
  }

  // --- Pantry Items ---

  /// Retrieves all pantry items mapped from ingredientId to quantity in grams.
  Future<Map<String, double>> getPantryItems() async {
    final rows = await _db.query('pantry_items');
    final map = <String, double>{};
    for (final row in rows) {
      final id = row['ingredient_id'] as String;
      final grams = (row['quantity_grams'] as num).toDouble();
      map[id] = grams;
    }
    return map;
  }

  /// Sets or updates a pantry item's quantity in grams.
  Future<void> setPantryItem(String ingredientId, double quantityGrams, {String unit = 'g'}) async {
    final nowIso = DateTime.now().toIso8601String();
    await _db.insert(
      'pantry_items',
      {
        'ingredient_id': ingredientId,
        'quantity_grams': quantityGrams,
        'unit': unit,
        'updated_at': nowIso,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Removes an ingredient from the pantry.
  Future<void> removePantryItem(String ingredientId) async {
    await _db.delete(
      'pantry_items',
      where: 'ingredient_id = ?',
      whereArgs: [ingredientId],
    );
  }

  /// Clears all items in the pantry.
  Future<void> clearPantry() async {
    await _db.delete('pantry_items');
  }

  static String _formatDateIso(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
