import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:siti_counter/planner/planner_models.dart';
import 'package:siti_counter/planner/planner_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late WeeklyPlannerRepository repository;

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await WeeklyPlannerRepository.createTables(db);
    repository = WeeklyPlannerRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('WeeklyPlannerRepository (SQLite)', () {
    test('initializes with default Nepali meal rhythms (Morning Dal Bhat, Khaja, Evening Dal Bhat)', () async {
      final slots = await repository.getActiveSlots();
      expect(slots.length, equals(3));
      expect(slots[0].id, equals('morning_dal_bhat'));
      expect(slots[0].nameNe, equals('बिहानीको दाल भात'));
      expect(slots[1].id, equals('afternoon_khaja'));
      expect(slots[1].nameNe, equals('दिउँसोको खाजा'));
      expect(slots[2].id, equals('evening_dal_bhat'));
      expect(slots[2].nameNe, equals('साँझको दाल भात'));
    });

    test('can add custom slot and deactivate existing slot', () async {
      const customSlot = MealRhythmSlot(
        id: 'suhoor',
        nameEn: 'Suhoor',
        nameNe: 'सहूर',
        defaultTime: '04:00',
        sortOrder: 0,
      );

      await repository.saveSlot(customSlot);
      var slots = await repository.getActiveSlots();
      expect(slots.any((s) => s.id == 'suhoor'), isTrue);

      await repository.deleteSlot('afternoon_khaja');
      slots = await repository.getActiveSlots();
      expect(slots.any((s) => s.id == 'afternoon_khaja'), isFalse);
    });

    test('saves, retrieves, moves, and deletes planned meals for a week', () async {
      final weekStart = DateTime(2026, 10, 4); // Sunday
      const meal = PlannedMeal(
        id: '2026-10-04_morning_dal_bhat',
        dateIso: '2026-10-04',
        slotId: 'morning_dal_bhat',
        recipeId: 'kalo-dal-jimbu',
        recipeTitleEn: 'Kalo Daal with Jimbu',
        recipeTitleNe: 'जिम्बु झानेको कालो दाल',
        servings: 4,
        isSeasonal: true,
        dietaryBadges: ['veg', 'gluten_free'],
      );

      await repository.savePlannedMeal(meal);

      var weeklyMeals = await repository.getPlannedMealsForWeek(weekStart);
      expect(weeklyMeals.length, equals(1));
      expect(weeklyMeals.first.recipeTitleNe, equals('जिम्बु झानेको कालो दाल'));
      expect(weeklyMeals.first.isSeasonal, isTrue);

      // Move meal to Monday evening
      await repository.movePlannedMeal(
        mealId: meal.id,
        targetDateIso: '2026-10-05',
        targetSlotId: 'evening_dal_bhat',
      );

      weeklyMeals = await repository.getPlannedMealsForWeek(weekStart);
      expect(weeklyMeals.first.dateIso, equals('2026-10-05'));
      expect(weeklyMeals.first.slotId, equals('evening_dal_bhat'));

      // Delete meal
      await repository.deletePlannedMeal(meal.id);
      weeklyMeals = await repository.getPlannedMealsForWeek(weekStart);
      expect(weeklyMeals, isEmpty);
    });

    test('tracks leftovers with use-by dates and marks as consumed', () async {
      const leftover = LeftoverItem(
        id: 'leftover_1',
        recipeId: 'masu-bhat',
        titleEn: 'Goat Curry',
        titleNe: 'खसीको मासु',
        servingsRemaining: 2,
        preparedDateIso: '2026-10-03',
        useByDateIso: '2026-10-05',
      );

      await repository.saveLeftover(leftover);

      var leftovers = await repository.getActiveLeftovers();
      expect(leftovers.length, equals(1));
      expect(leftovers.first.titleNe, equals('खसीको मासु'));

      await repository.markLeftoverConsumed('leftover_1');
      leftovers = await repository.getActiveLeftovers();
      expect(leftovers, isEmpty);
    });
  });
}
