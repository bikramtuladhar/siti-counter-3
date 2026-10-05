import 'package:kitchen_engine/kitchen_engine.dart';
import 'package:test/test.dart';

void main() {
  group('PartyPlannerEngine Dart Tests - 20-Guest Feast Scaling & Timeline', () {
    test('scales menu 5x for 20 guests, schedules T-minus tasks, and allocates co-hosts', () {
      const menu = [
        PartyMenuItem(
          recipeId: 'khasi_ko_masu',
          nameEn: 'Mutton Curry',
          nameNe: 'खसीको मासु',
          course: CourseType.main,
          prepDurationMinutes: 20,
          cookDurationMinutes: 45,
          marinateMinutes: 60,
          requiredEquipment: ['pressure_cooker_5l'],
          requiredBurners: 1,
          ingredients: [
            PartyIngredient(id: 'mutton', nameEn: 'Mutton', nameNe: 'खसीको मासु', baseGrams: 800),
            PartyIngredient(id: 'onion', nameEn: 'Onion', nameNe: 'प्याज', baseGrams: 300),
          ],
        ),
        PartyMenuItem(
          recipeId: 'jeera_rice',
          nameEn: 'Jeera Rice',
          nameNe: 'जीरा राइस',
          course: CourseType.side,
          prepDurationMinutes: 10,
          cookDurationMinutes: 25,
          requiredEquipment: ['rice_cooker'],
          requiredBurners: 0,
          ingredients: [
            PartyIngredient(id: 'rice', nameEn: 'Basmati Rice', nameNe: 'बासमती चामल', baseGrams: 500),
          ],
        ),
      ];

      const input = PartyPlanInput(
        titleEn: 'Dashain Family Feast',
        titleNe: 'दशैं पारिवारिक भोज',
        guestCount: 20,
        serveTime: '19:00',
        menuItems: menu,
        availableEquipment: ['pressure_cooker_5l', 'rice_cooker'],
        burnerCount: 3,
        coHosts: ['Bikram', 'Sita'],
      );

      final plan = PartyPlannerEngine.generatePlan(input);

      expect(plan.guestCount, 20);
      expect(plan.scaleFactor, 5.0);
      expect(plan.timeline.length, greaterThanOrEqualTo(4));

      final marinateTask = plan.timeline.firstWhere((t) => t.id == 'task_khasi_ko_masu_marinate');
      final cookTask = plan.timeline.firstWhere((t) => t.id == 'task_khasi_ko_masu_cook');

      expect(marinateTask.tMinusMinutes, greaterThan(cookTask.tMinusMinutes));

      final mutton = plan.combinedGroceries.firstWhere((g) => g.ingredientId == 'mutton');
      expect(mutton.scaledGrams, 4000.0);

      final rice = plan.combinedGroceries.firstWhere((g) => g.ingredientId == 'rice');
      expect(rice.scaledGrams, 2500.0);

      expect(plan.timeline.any((t) => t.assignedCoHost == 'Bikram'), isTrue);
      expect(plan.timeline.any((t) => t.assignedCoHost == 'Sita'), isTrue);
      expect(plan.isFeasibleWithoutConflict, isTrue);
    });
  });

  group('PartyPlannerEngine Dart Tests - Equipment Conflict Detection', () {
    test('detects concurrent use of 5L pressure cooker and provides bilingual suggestions', () {
      const menu = [
        PartyMenuItem(
          recipeId: 'dal_makhani',
          nameEn: 'Dal Makhani',
          nameNe: 'दाल मखनी',
          course: CourseType.main,
          prepDurationMinutes: 15,
          cookDurationMinutes: 40,
          requiredEquipment: ['pressure_cooker_5l'],
          requiredBurners: 1,
        ),
        PartyMenuItem(
          recipeId: 'aloo_dum',
          nameEn: 'Dum Aloo',
          nameNe: 'दम आलु',
          course: CourseType.main,
          prepDurationMinutes: 15,
          cookDurationMinutes: 35,
          requiredEquipment: ['pressure_cooker_5l'],
          requiredBurners: 1,
        ),
      ];

      const input = PartyPlanInput(
        titleEn: 'Dinner Party',
        titleNe: 'साँझको भोज',
        guestCount: 12,
        serveTime: '19:00',
        menuItems: menu,
        availableEquipment: ['pressure_cooker_5l'],
        burnerCount: 2,
      );

      final plan = PartyPlannerEngine.generatePlan(input);

      expect(plan.isFeasibleWithoutConflict, isFalse);
      expect(plan.equipmentConflicts.length, 1);

      final conflict = plan.equipmentConflicts[0];
      expect(conflict.equipmentId, 'pressure_cooker_5l');
      expect(conflict.resolutionSuggestionEn, contains('Stagger preparation'));
      expect(conflict.resolutionSuggestionNe, contains('समय मिलाउनुहोस्'));
    });

    test('detects stove burner overload when simultaneous burner count exceeds capacity', () {
      const menu = [
        PartyMenuItem(
          recipeId: 'dish_1',
          nameEn: 'Dish 1',
          nameNe: 'परिकार १',
          course: CourseType.main,
          prepDurationMinutes: 10,
          cookDurationMinutes: 30,
          requiredEquipment: ['kadai_1'],
          requiredBurners: 2,
        ),
        PartyMenuItem(
          recipeId: 'dish_2',
          nameEn: 'Dish 2',
          nameNe: 'परिकार २',
          course: CourseType.main,
          prepDurationMinutes: 10,
          cookDurationMinutes: 30,
          requiredEquipment: ['kadai_2'],
          requiredBurners: 1,
        ),
      ];

      const input = PartyPlanInput(
        titleEn: 'Stove Limit Test',
        titleNe: 'चुल्हो परीक्षण',
        guestCount: 8,
        serveTime: '20:00',
        menuItems: menu,
        availableEquipment: ['kadai_1', 'kadai_2'],
        burnerCount: 2,
      );

      final plan = PartyPlannerEngine.generatePlan(input);

      expect(plan.isFeasibleWithoutConflict, isFalse);
      expect(plan.burnerConflicts.length, 1);
      expect(plan.burnerConflicts[0].resolutionSuggestionEn, contains('Exceeds 2 cooktop burners'));
    });
  });
}
