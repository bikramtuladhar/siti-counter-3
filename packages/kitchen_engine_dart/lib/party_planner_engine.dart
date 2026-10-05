library;

import 'dart:math' as math;

enum CourseType {
  drink,
  appetizer,
  main,
  side,
  dessert;

  String toJson() => name;
  static CourseType fromJson(String value) => CourseType.values.byName(value);
}

class PartyIngredient {
  final String id;
  final String nameEn;
  final String nameNe;
  final double baseGrams;
  final String unit;

  const PartyIngredient({
    required this.id,
    required this.nameEn,
    required this.nameNe,
    required this.baseGrams,
    this.unit = 'g',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'nameEn': nameEn,
        'nameNe': nameNe,
        'baseGrams': baseGrams,
        'unit': unit,
      };
}

class PartyMenuItem {
  final String recipeId;
  final String nameEn;
  final String nameNe;
  final CourseType course;
  final int baseServings;
  final int prepDurationMinutes;
  final int cookDurationMinutes;
  final List<String> requiredEquipment;
  final int requiredBurners;
  final bool canBePreparedAhead;
  final int? marinateMinutes;
  final List<String> dietaryTags;
  final List<PartyIngredient> ingredients;

  const PartyMenuItem({
    required this.recipeId,
    required this.nameEn,
    required this.nameNe,
    required this.course,
    this.baseServings = 4,
    required this.prepDurationMinutes,
    required this.cookDurationMinutes,
    this.requiredEquipment = const [],
    this.requiredBurners = 1,
    this.canBePreparedAhead = false,
    this.marinateMinutes,
    this.dietaryTags = const [],
    this.ingredients = const [],
  });

  Map<String, dynamic> toJson() => {
        'recipeId': recipeId,
        'nameEn': nameEn,
        'nameNe': nameNe,
        'course': course.toJson(),
        'baseServings': baseServings,
        'prepDurationMinutes': prepDurationMinutes,
        'cookDurationMinutes': cookDurationMinutes,
        'requiredEquipment': requiredEquipment,
        'requiredBurners': requiredBurners,
        'canBePreparedAhead': canBePreparedAhead,
        'marinateMinutes': marinateMinutes,
        'dietaryTags': dietaryTags,
        'ingredients': ingredients.map((i) => i.toJson()).toList(),
      };
}

class PartyPlanInput {
  final String titleEn;
  final String titleNe;
  final int guestCount;
  final String serveTime; // "19:00"
  final List<String> dietaryRestrictions;
  final List<PartyMenuItem> menuItems;
  final List<String> availableEquipment;
  final int burnerCount;
  final List<String> coHosts;

  const PartyPlanInput({
    required this.titleEn,
    required this.titleNe,
    required this.guestCount,
    required this.serveTime,
    this.dietaryRestrictions = const [],
    required this.menuItems,
    this.availableEquipment = const [],
    this.burnerCount = 3,
    this.coHosts = const [],
  });
}

class TMinusTask {
  final String id;
  final String recipeId;
  final String recipeNameEn;
  final String recipeNameNe;
  final String titleEn;
  final String titleNe;
  final int tMinusMinutes;
  final String targetTime;
  final int durationMinutes;
  final List<String> equipmentUsed;
  final int burnersUsed;
  final String? assignedCoHost;
  final bool isCompleted;

  const TMinusTask({
    required this.id,
    required this.recipeId,
    required this.recipeNameEn,
    required this.recipeNameNe,
    required this.titleEn,
    required this.titleNe,
    required this.tMinusMinutes,
    required this.targetTime,
    required this.durationMinutes,
    required this.equipmentUsed,
    required this.burnersUsed,
    this.assignedCoHost,
    this.isCompleted = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'recipeId': recipeId,
        'recipeNameEn': recipeNameEn,
        'recipeNameNe': recipeNameNe,
        'titleEn': titleEn,
        'titleNe': titleNe,
        'tMinusMinutes': tMinusMinutes,
        'targetTime': targetTime,
        'durationMinutes': durationMinutes,
        'equipmentUsed': equipmentUsed,
        'burnersUsed': burnersUsed,
        'assignedCoHost': assignedCoHost,
        'isCompleted': isCompleted,
      };
}

class EquipmentConflict {
  final String equipmentId;
  final List<String> conflictingRecipeIds;
  final List<String> conflictingRecipeNames;
  final String overlapStartTime;
  final String overlapEndTime;
  final String resolutionSuggestionEn;
  final String resolutionSuggestionNe;

  const EquipmentConflict({
    required this.equipmentId,
    required this.conflictingRecipeIds,
    required this.conflictingRecipeNames,
    required this.overlapStartTime,
    required this.overlapEndTime,
    required this.resolutionSuggestionEn,
    required this.resolutionSuggestionNe,
  });

  Map<String, dynamic> toJson() => {
        'equipmentId': equipmentId,
        'conflictingRecipeIds': conflictingRecipeIds,
        'conflictingRecipeNames': conflictingRecipeNames,
        'overlapStartTime': overlapStartTime,
        'overlapEndTime': overlapEndTime,
        'resolutionSuggestionEn': resolutionSuggestionEn,
        'resolutionSuggestionNe': resolutionSuggestionNe,
      };
}

class PartyGroceryItem {
  final String ingredientId;
  final String nameEn;
  final String nameNe;
  final double scaledGrams;
  final String unit;

  const PartyGroceryItem({
    required this.ingredientId,
    required this.nameEn,
    required this.nameNe,
    required this.scaledGrams,
    required this.unit,
  });

  Map<String, dynamic> toJson() => {
        'ingredientId': ingredientId,
        'nameEn': nameEn,
        'nameNe': nameNe,
        'scaledGrams': scaledGrams,
        'unit': unit,
      };
}

class PartyPlanResult {
  final String titleEn;
  final String titleNe;
  final int guestCount;
  final double scaleFactor;
  final List<TMinusTask> timeline;
  final List<EquipmentConflict> equipmentConflicts;
  final List<EquipmentConflict> burnerConflicts;
  final List<PartyGroceryItem> combinedGroceries;
  final bool isFeasibleWithoutConflict;

  const PartyPlanResult({
    required this.titleEn,
    required this.titleNe,
    required this.guestCount,
    required this.scaleFactor,
    required this.timeline,
    required this.equipmentConflicts,
    required this.burnerConflicts,
    required this.combinedGroceries,
    required this.isFeasibleWithoutConflict,
  });

  Map<String, dynamic> toJson() => {
        'titleEn': titleEn,
        'titleNe': titleNe,
        'guestCount': guestCount,
        'scaleFactor': scaleFactor,
        'timeline': timeline.map((t) => t.toJson()).toList(),
        'equipmentConflicts': equipmentConflicts.map((c) => c.toJson()).toList(),
        'burnerConflicts': burnerConflicts.map((c) => c.toJson()).toList(),
        'combinedGroceries': combinedGroceries.map((g) => g.toJson()).toList(),
        'isFeasibleWithoutConflict': isFeasibleWithoutConflict,
      };
}

class PartyPlannerEngine {
  static PartyPlanResult generatePlan(PartyPlanInput input) {
    final guestCount = math.max(1, input.guestCount);
    const baseServings = 4;
    final scaleFactor = guestCount / baseServings;
    final burnerCount = input.burnerCount;
    final coHosts = input.coHosts.isNotEmpty ? input.coHosts : const ['Host'];

    final serveTimeParts = input.serveTime.contains('T')
        ? input.serveTime.split('T')[1].split(':')
        : input.serveTime.split(':');
    final serveHour = int.parse(serveTimeParts[0]);
    final serveMin = int.parse(serveTimeParts[1]);
    final serveTotalMinutes = serveHour * 60 + serveMin;

    String formatClockTime(int totalMinutes) {
      var m = totalMinutes % (24 * 60);
      if (m < 0) m += 24 * 60;
      final h = m ~/ 60;
      final min = m % 60;
      return '${h.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}';
    }

    final tasks = <TMinusTask>[];
    int taskIdx = 0;

    for (final item in input.menuItems) {
      int finishOffsetMinutes = 0;
      if (item.course == CourseType.appetizer) {
        finishOffsetMinutes = 20;
      } else if (item.course == CourseType.drink) {
        finishOffsetMinutes = 30;
      } else if (item.course == CourseType.dessert && item.canBePreparedAhead) {
        finishOffsetMinutes = 120;
      } else if (item.course == CourseType.main) {
        finishOffsetMinutes = 10;
      } else {
        finishOffsetMinutes = 15;
      }

      final cookEndMinutes = serveTotalMinutes - finishOffsetMinutes;
      final cookStartMinutes = cookEndMinutes - item.cookDurationMinutes;
      final tMinusCook = serveTotalMinutes - cookStartMinutes;

      if (item.cookDurationMinutes > 0) {
        final assignedCoHost = coHosts[taskIdx % coHosts.length];
        taskIdx++;

        tasks.add(TMinusTask(
          id: 'task_${item.recipeId}_cook',
          recipeId: item.recipeId,
          recipeNameEn: item.nameEn,
          recipeNameNe: item.nameNe,
          titleEn: 'Cook ${item.nameEn}',
          titleNe: '${item.nameNe} पकाउनुहोस्',
          tMinusMinutes: tMinusCook,
          targetTime: formatClockTime(cookStartMinutes),
          durationMinutes: item.cookDurationMinutes,
          equipmentUsed: item.requiredEquipment,
          burnersUsed: item.requiredBurners,
          assignedCoHost: assignedCoHost,
        ));
      }

      int prepEndMinutes = cookStartMinutes;
      if (item.marinateMinutes != null && item.marinateMinutes! > 0) {
        final marinateStartMinutes = cookStartMinutes - item.marinateMinutes!;
        final tMinusMarinate = serveTotalMinutes - marinateStartMinutes;
        final assignedCoHost = coHosts[taskIdx % coHosts.length];
        taskIdx++;

        tasks.add(TMinusTask(
          id: 'task_${item.recipeId}_marinate',
          recipeId: item.recipeId,
          recipeNameEn: item.nameEn,
          recipeNameNe: item.nameNe,
          titleEn: 'Marinate ${item.nameEn}',
          titleNe: '${item.nameNe} मोल्नुहोस् (Marinate)',
          tMinusMinutes: tMinusMarinate,
          targetTime: formatClockTime(marinateStartMinutes),
          durationMinutes: item.marinateMinutes!,
          equipmentUsed: const [],
          burnersUsed: 0,
          assignedCoHost: assignedCoHost,
        ));

        prepEndMinutes = marinateStartMinutes;
      }

      if (item.prepDurationMinutes > 0) {
        final prepStartMinutes = prepEndMinutes - item.prepDurationMinutes;
        final tMinusPrep = serveTotalMinutes - prepStartMinutes;
        final assignedCoHost = coHosts[taskIdx % coHosts.length];
        taskIdx++;

        tasks.add(TMinusTask(
          id: 'task_${item.recipeId}_prep',
          recipeId: item.recipeId,
          recipeNameEn: item.nameEn,
          recipeNameNe: item.nameNe,
          titleEn: 'Prep ingredients for ${item.nameEn}',
          titleNe: '${item.nameNe} को सामग्री तयार पार्नुहोस्',
          tMinusMinutes: tMinusPrep,
          targetTime: formatClockTime(prepStartMinutes),
          durationMinutes: item.prepDurationMinutes,
          equipmentUsed: item.requiredEquipment
              .where((e) => e.contains('blender') || e.contains('food_processor'))
              .toList(),
          burnersUsed: 0,
          assignedCoHost: assignedCoHost,
        ));
      }
    }

    tasks.sort((a, b) => b.tMinusMinutes.compareTo(a.tMinusMinutes));

    // Equipment conflict detection
    final equipmentConflicts = <EquipmentConflict>[];
    final cookingTasks = tasks.where((t) => t.equipmentUsed.isNotEmpty && t.durationMinutes > 0).toList();

    for (int i = 0; i < cookingTasks.length; i++) {
      for (int j = i + 1; j < cookingTasks.length; j++) {
        final taskA = cookingTasks[i];
        final taskB = cookingTasks[j];

        final sharedEquipment = taskA.equipmentUsed.where((eq) => taskB.equipmentUsed.contains(eq)).toList();

        if (sharedEquipment.isNotEmpty) {
          final aStart = serveTotalMinutes - taskA.tMinusMinutes;
          final aEnd = aStart + taskA.durationMinutes;
          final bStart = serveTotalMinutes - taskB.tMinusMinutes;
          final bEnd = bStart + taskB.durationMinutes;

          final overlapStart = math.max(aStart, bStart);
          final overlapEnd = math.min(aEnd, bEnd);

          if (overlapStart < overlapEnd) {
            for (final eq in sharedEquipment) {
              final eqName = eq.replaceAll('_', ' ');
              equipmentConflicts.add(EquipmentConflict(
                equipmentId: eq,
                conflictingRecipeIds: [taskA.recipeId, taskB.recipeId],
                conflictingRecipeNames: [taskA.recipeNameEn, taskB.recipeNameEn],
                overlapStartTime: formatClockTime(overlapStart),
                overlapEndTime: formatClockTime(overlapEnd),
                resolutionSuggestionEn:
                    'Stagger preparation: cook ${taskA.recipeNameEn} earlier and keep warm to free the $eqName for ${taskB.recipeNameEn}.',
                resolutionSuggestionNe:
                    'समय मिलाउनुहोस्: ${taskA.recipeNameNe} लाई पहिले पकाएर तातो राख्नुहोस् जसले गर्दा $eqName ${taskB.recipeNameNe} को लागि खाली हुन्छ।',
              ));
            }
          }
        }
      }
    }

    // Stove Burner conflict detection
    final burnerConflicts = <EquipmentConflict>[];
    final stoveTasks = tasks.where((t) => t.burnersUsed > 0).toList();

    for (int i = 0; i < stoveTasks.length; i++) {
      for (int j = i + 1; j < stoveTasks.length; j++) {
        final a = stoveTasks[i];
        final b = stoveTasks[j];

        final aStart = serveTotalMinutes - a.tMinusMinutes;
        final aEnd = aStart + a.durationMinutes;
        final bStart = serveTotalMinutes - b.tMinusMinutes;
        final bEnd = bStart + b.durationMinutes;

        final overlapStart = math.max(aStart, bStart);
        final overlapEnd = math.min(aEnd, bEnd);

        if (overlapStart < overlapEnd) {
          final totalBurnersInOverlap = a.burnersUsed + b.burnersUsed;
          if (totalBurnersInOverlap > burnerCount) {
            burnerConflicts.add(EquipmentConflict(
              equipmentId: 'stove_burners',
              conflictingRecipeIds: [a.recipeId, b.recipeId],
              conflictingRecipeNames: [a.recipeNameEn, b.recipeNameEn],
              overlapStartTime: formatClockTime(overlapStart),
              overlapEndTime: formatClockTime(overlapEnd),
              resolutionSuggestionEn:
                  'Exceeds $burnerCount cooktop burners ($totalBurnersInOverlap needed). Cook one dish ahead.',
              resolutionSuggestionNe:
                  'चुल्होको क्षमता ($burnerCount बर्नर) भन्दा बढी भयो। एउटा परिकार अगाडि नै पकाउनुहोस्।',
            ));
          }
        }
      }
    }

    // Combined groceries
    final groceryMap = <String, PartyGroceryItem>{};

    for (final item in input.menuItems) {
      for (final ing in item.ingredients) {
        final scaled = ing.baseGrams * scaleFactor;
        final existing = groceryMap[ing.id];
        if (existing != null) {
          groceryMap[ing.id] = PartyGroceryItem(
            ingredientId: ing.id,
            nameEn: ing.nameEn,
            nameNe: ing.nameNe,
            scaledGrams: existing.scaledGrams + scaled,
            unit: ing.unit,
          );
        } else {
          groceryMap[ing.id] = PartyGroceryItem(
            ingredientId: ing.id,
            nameEn: ing.nameEn,
            nameNe: ing.nameNe,
            scaledGrams: scaled,
            unit: ing.unit,
          );
        }
      }
    }

    final combinedGroceries = groceryMap.values.toList()
      ..sort((a, b) => a.nameEn.compareTo(b.nameEn));

    return PartyPlanResult(
      titleEn: input.titleEn,
      titleNe: input.titleNe,
      guestCount: guestCount,
      scaleFactor: scaleFactor,
      timeline: tasks,
      equipmentConflicts: equipmentConflicts,
      burnerConflicts: burnerConflicts,
      combinedGroceries: combinedGroceries,
      isFeasibleWithoutConflict: equipmentConflicts.isEmpty && burnerConflicts.isEmpty,
    );
  }
}
