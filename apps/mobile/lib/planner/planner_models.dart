import 'package:flutter/foundation.dart';

/// Configurable meal rhythm slot (e.g., Morning Dal Bhat, Afternoon Khaja, Evening Dal Bhat).
@immutable
class MealRhythmSlot {
  final String id;
  final String nameEn;
  final String nameNe;
  final String defaultTime; // e.g., '09:30', '14:30', '19:30'
  final int sortOrder;
  final bool isActive;

  const MealRhythmSlot({
    required this.id,
    required this.nameEn,
    required this.nameNe,
    required this.defaultTime,
    this.sortOrder = 0,
    this.isActive = true,
  });

  /// Default Nepali household meal rhythm (Section 8.1).
  static List<MealRhythmSlot> defaultNepaliRhythm() => const [
        MealRhythmSlot(
          id: 'morning_dal_bhat',
          nameEn: 'Morning Dal Bhat',
          nameNe: 'बिहानीको दाल भात',
          defaultTime: '09:30',
          sortOrder: 1,
          isActive: true,
        ),
        MealRhythmSlot(
          id: 'afternoon_khaja',
          nameEn: 'Afternoon Khaja',
          nameNe: 'दिउँसोको खाजा',
          defaultTime: '14:30',
          sortOrder: 2,
          isActive: true,
        ),
        MealRhythmSlot(
          id: 'evening_dal_bhat',
          nameEn: 'Evening Dal Bhat',
          nameNe: 'साँझको दाल भात',
          defaultTime: '19:30',
          sortOrder: 3,
          isActive: true,
        ),
      ];

  Map<String, dynamic> toMap() => {
        'id': id,
        'name_en': nameEn,
        'name_ne': nameNe,
        'default_time': defaultTime,
        'sort_order': sortOrder,
        'is_active': isActive ? 1 : 0,
      };

  factory MealRhythmSlot.fromMap(Map<String, dynamic> map) => MealRhythmSlot(
        id: map['id'] as String,
        nameEn: map['name_en'] as String,
        nameNe: map['name_ne'] as String,
        defaultTime: map['default_time'] as String,
        sortOrder: map['sort_order'] as int? ?? 0,
        isActive: (map['is_active'] as int? ?? 1) == 1,
      );
}

/// A planned meal slotted into a specific date and meal rhythm slot.
@immutable
class PlannedMeal {
  final String id;
  final String dateIso; // YYYY-MM-DD
  final String slotId;
  final String recipeId;
  final String recipeTitleEn;
  final String recipeTitleNe;
  final int servings;
  final bool isLeftover;
  final String? leftoverSourceDate;
  final bool isSeasonal;
  final List<String> dietaryBadges; // e.g. ['veg', 'gluten_free']
  final String? notes;

  const PlannedMeal({
    required this.id,
    required this.dateIso,
    required this.slotId,
    required this.recipeId,
    required this.recipeTitleEn,
    required this.recipeTitleNe,
    this.servings = 4,
    this.isLeftover = false,
    this.leftoverSourceDate,
    this.isSeasonal = false,
    this.dietaryBadges = const [],
    this.notes,
  });

  PlannedMeal copyWith({
    String? id,
    String? dateIso,
    String? slotId,
    String? recipeId,
    String? recipeTitleEn,
    String? recipeTitleNe,
    int? servings,
    bool? isLeftover,
    String? leftoverSourceDate,
    bool? isSeasonal,
    List<String>? dietaryBadges,
    String? notes,
  }) =>
      PlannedMeal(
        id: id ?? this.id,
        dateIso: dateIso ?? this.dateIso,
        slotId: slotId ?? this.slotId,
        recipeId: recipeId ?? this.recipeId,
        recipeTitleEn: recipeTitleEn ?? this.recipeTitleEn,
        recipeTitleNe: recipeTitleNe ?? this.recipeTitleNe,
        servings: servings ?? this.servings,
        isLeftover: isLeftover ?? this.isLeftover,
        leftoverSourceDate: leftoverSourceDate ?? this.leftoverSourceDate,
        isSeasonal: isSeasonal ?? this.isSeasonal,
        dietaryBadges: dietaryBadges ?? this.dietaryBadges,
        notes: notes ?? this.notes,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'date_iso': dateIso,
        'slot_id': slotId,
        'recipe_id': recipeId,
        'recipe_title_en': recipeTitleEn,
        'recipe_title_ne': recipeTitleNe,
        'servings': servings,
        'is_leftover': isLeftover ? 1 : 0,
        'leftover_source_date': leftoverSourceDate,
        'is_seasonal': isSeasonal ? 1 : 0,
        'dietary_badges': dietaryBadges.join(','),
        'notes': notes,
      };

  factory PlannedMeal.fromMap(Map<String, dynamic> map) => PlannedMeal(
        id: map['id'] as String,
        dateIso: map['date_iso'] as String,
        slotId: map['slot_id'] as String,
        recipeId: map['recipe_id'] as String,
        recipeTitleEn: map['recipe_title_en'] as String,
        recipeTitleNe: map['recipe_title_ne'] as String,
        servings: map['servings'] as int? ?? 4,
        isLeftover: (map['is_leftover'] as int? ?? 0) == 1,
        leftoverSourceDate: map['leftover_source_date'] as String?,
        isSeasonal: (map['is_seasonal'] as int? ?? 0) == 1,
        dietaryBadges: (map['dietary_badges'] as String? ?? '')
            .split(',')
            .where((s) => s.isNotEmpty)
            .toList(),
        notes: map['notes'] as String?,
      );
}

/// Tracked leftover item available for slotting in the planner.
@immutable
class LeftoverItem {
  final String id;
  final String recipeId;
  final String titleEn;
  final String titleNe;
  final int servingsRemaining;
  final String preparedDateIso;
  final String useByDateIso;
  final bool isConsumed;

  const LeftoverItem({
    required this.id,
    required this.recipeId,
    required this.titleEn,
    required this.titleNe,
    required this.servingsRemaining,
    required this.preparedDateIso,
    required this.useByDateIso,
    this.isConsumed = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'recipe_id': recipeId,
        'title_en': titleEn,
        'title_ne': titleNe,
        'servings_remaining': servingsRemaining,
        'prepared_date_iso': preparedDateIso,
        'use_by_date_iso': useByDateIso,
        'is_consumed': isConsumed ? 1 : 0,
      };

  factory LeftoverItem.fromMap(Map<String, dynamic> map) => LeftoverItem(
        id: map['id'] as String,
        recipeId: map['recipe_id'] as String,
        titleEn: map['title_en'] as String,
        titleNe: map['title_ne'] as String,
        servingsRemaining: map['servings_remaining'] as int? ?? 1,
        preparedDateIso: map['prepared_date_iso'] as String,
        useByDateIso: map['use_by_date_iso'] as String,
        isConsumed: (map['is_consumed'] as int? ?? 0) == 1,
      );
}

/// Granularity of the planner grid.
enum PlannerViewMode { week, month }
