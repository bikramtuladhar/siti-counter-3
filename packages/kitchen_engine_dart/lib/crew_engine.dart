library;

import 'region_pack.dart';

/// Task types for kitchen prep, cooking, and clean-up.
enum TaskType {
  washChop,
  grindMasala,
  watchCooker,
  rollRotis,
  simmerStir,
  cleanUp;

  String get labelEn {
    switch (this) {
      case TaskType.washChop:
        return 'Wash & Chop';
      case TaskType.grindMasala:
        return 'Grind Masala';
      case TaskType.watchCooker:
        return 'Watch Cooker';
      case TaskType.rollRotis:
        return 'Roll Rotis';
      case TaskType.simmerStir:
        return 'Simmer & Stir';
      case TaskType.cleanUp:
        return 'Clean-up & Table';
    }
  }

  String get labelNe {
    switch (this) {
      case TaskType.washChop:
        return 'धुने र काट्ने';
      case TaskType.grindMasala:
        return 'मसला पिस्ने';
      case TaskType.watchCooker:
        return 'सिट्टी गन्ने / कुकर हेर्ने';
      case TaskType.rollRotis:
        return 'रोटी बेल्ने';
      case TaskType.simmerStir:
        return 'झाङ्ने र चलाउने';
      case TaskType.cleanUp:
        return 'सफा गर्ने र थाल लगाउने';
    }
  }

  String get category {
    switch (this) {
      case TaskType.washChop:
      case TaskType.grindMasala:
        return 'prep';
      case TaskType.watchCooker:
      case TaskType.rollRotis:
      case TaskType.simmerStir:
        return 'cook';
      case TaskType.cleanUp:
        return 'clean';
    }
  }
}

/// Lifecycle status of a cook task.
enum TaskStatus {
  pending,
  inProgress,
  completed;

  String get labelEn {
    switch (this) {
      case TaskStatus.pending:
        return 'Pending';
      case TaskStatus.inProgress:
        return 'In Progress';
      case TaskStatus.completed:
        return 'Completed';
    }
  }
}

/// Age categories determining kitchen safety rules.
enum AgeGroup {
  toddler, // 0-4
  child, // 5-11
  teen, // 12-17
  adult, // 18-64
  elderly; // 65+

  static AgeGroup fromAge(int age) {
    if (age < 5) return AgeGroup.toddler;
    if (age < 12) return AgeGroup.child;
    if (age < 18) return AgeGroup.teen;
    if (age < 65) return AgeGroup.adult;
    return AgeGroup.elderly;
  }
}

/// Culinary skill level.
enum SkillLevel {
  beginner,
  intermediate,
  expert;

  static SkillLevel fromString(String val) {
    switch (val.toLowerCase()) {
      case 'expert':
        return SkillLevel.expert;
      case 'intermediate':
        return SkillLevel.intermediate;
      default:
        return SkillLevel.beginner;
    }
  }
}

/// Profile of a household member for cooking crew assignments.
class MemberCrewProfile {
  final String memberId;
  final String name;
  final int age;
  final AgeGroup ageGroup;
  final SkillLevel skillLevel;
  final Set<TaskType> preferredTasks;
  final Set<TaskType> avoidedTasks;
  final bool isAvailable;

  MemberCrewProfile({
    required this.memberId,
    required this.name,
    required this.age,
    AgeGroup? ageGroup,
    this.skillLevel = SkillLevel.intermediate,
    Set<TaskType>? preferredTasks,
    Set<TaskType>? avoidedTasks,
    this.isAvailable = true,
  })  : ageGroup = ageGroup ?? AgeGroup.fromAge(age),
        preferredTasks = preferredTasks ?? const {},
        avoidedTasks = avoidedTasks ?? const {};

  /// Checks if a task is safe and age-appropriate for this member.
  bool canPerformTask(TaskType task) {
    switch (ageGroup) {
      case AgeGroup.toddler:
        // Toddlers can only help with gentle, non-sharp, no-heat clean-up/table tasks under supervision
        return task == TaskType.cleanUp;

      case AgeGroup.child:
        // Children (5-11):
        // Safe: Watch cooker (whistle counting), table/clean-up, wash (sorting beans/rice/veggies).
        // Unsafe: Active stove frying/tadka (simmerStir), rolling rotis on hot tava, or sharp-knife heavy chopping.
        return task == TaskType.watchCooker ||
            task == TaskType.cleanUp ||
            task == TaskType.washChop;

      case AgeGroup.teen:
      case AgeGroup.adult:
      case AgeGroup.elderly:
        return true;
    }
  }

  Map<String, dynamic> toJson() => {
        'memberId': memberId,
        'name': name,
        'age': age,
        'ageGroup': ageGroup.name,
        'skillLevel': skillLevel.name,
        'preferredTasks': preferredTasks.map((t) => t.name).toList(),
        'avoidedTasks': avoidedTasks.map((t) => t.name).toList(),
        'isAvailable': isAvailable,
      };

  factory MemberCrewProfile.fromJson(Map<String, dynamic> json) {
    final age = json['age'] as int? ?? 25;
    return MemberCrewProfile(
      memberId: json['memberId'] as String,
      name: json['name'] as String,
      age: age,
      ageGroup: json['ageGroup'] != null
          ? AgeGroup.values.byName(json['ageGroup'] as String)
          : AgeGroup.fromAge(age),
      skillLevel: json['skillLevel'] != null
          ? SkillLevel.values.byName(json['skillLevel'] as String)
          : SkillLevel.intermediate,
      preferredTasks: (json['preferredTasks'] as List<dynamic>?)
              ?.map((t) => TaskType.values.byName(t.toString()))
              .toSet() ??
          {},
      avoidedTasks: (json['avoidedTasks'] as List<dynamic>?)
              ?.map((t) => TaskType.values.byName(t.toString()))
              .toSet() ??
          {},
      isAvailable: json['isAvailable'] as bool? ?? true,
    );
  }
}

/// An individual parallel cook task split from a recipe.
class CookTask {
  final String id;
  final String recipeId;
  final TaskType taskType;
  final String titleEn;
  final String titleNe;
  final String descriptionEn;
  final String descriptionNe;
  final int estimatedMinutes;
  final int minimumAge;
  final bool isKidFriendly;
  final bool requiresSupervision;
  final bool isParallel;
  String? assignedMemberId;
  String? assignedMemberName;
  TaskStatus status;

  CookTask({
    required this.id,
    required this.recipeId,
    required this.taskType,
    required this.titleEn,
    required this.titleNe,
    required this.descriptionEn,
    required this.descriptionNe,
    required this.estimatedMinutes,
    this.minimumAge = 5,
    this.isKidFriendly = false,
    this.requiresSupervision = false,
    this.isParallel = true,
    this.assignedMemberId,
    this.assignedMemberName,
    this.status = TaskStatus.pending,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'recipeId': recipeId,
        'taskType': taskType.name,
        'titleEn': titleEn,
        'titleNe': titleNe,
        'descriptionEn': descriptionEn,
        'descriptionNe': descriptionNe,
        'estimatedMinutes': estimatedMinutes,
        'minimumAge': minimumAge,
        'isKidFriendly': isKidFriendly,
        'requiresSupervision': requiresSupervision,
        'isParallel': isParallel,
        'assignedMemberId': assignedMemberId,
        'assignedMemberName': assignedMemberName,
        'status': status.name,
      };

  factory CookTask.fromJson(Map<String, dynamic> json) => CookTask(
        id: json['id'] as String,
        recipeId: json['recipeId'] as String,
        taskType: TaskType.values.byName(json['taskType'] as String),
        titleEn: json['titleEn'] as String,
        titleNe: json['titleNe'] as String,
        descriptionEn: json['descriptionEn'] as String,
        descriptionNe: json['descriptionNe'] as String,
        estimatedMinutes: json['estimatedMinutes'] as int? ?? 10,
        minimumAge: json['minimumAge'] as int? ?? 5,
        isKidFriendly: json['isKidFriendly'] as bool? ?? false,
        requiresSupervision: json['requiresSupervision'] as bool? ?? false,
        isParallel: json['isParallel'] as bool? ?? true,
        assignedMemberId: json['assignedMemberId'] as String?,
        assignedMemberName: json['assignedMemberName'] as String?,
        status: json['status'] != null
            ? TaskStatus.values.byName(json['status'] as String)
            : TaskStatus.pending,
      );
}

/// Historical record of a member's contribution in a cooking session.
class RotaContributionRecord {
  final String id;
  final String sessionId;
  final String recipeId;
  final String memberId;
  final String memberName;
  final TaskType taskType;
  final String role; // 'leadCook', 'coCook', 'helper'
  final DateTime completedAt;
  final int durationMinutes;

  const RotaContributionRecord({
    required this.id,
    required this.sessionId,
    required this.recipeId,
    required this.memberId,
    required this.memberName,
    required this.taskType,
    required this.role,
    required this.completedAt,
    this.durationMinutes = 15,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'sessionId': sessionId,
        'recipeId': recipeId,
        'memberId': memberId,
        'memberName': memberName,
        'taskType': taskType.name,
        'role': role,
        'completedAt': completedAt.toIso8601String(),
        'durationMinutes': durationMinutes,
      };

  factory RotaContributionRecord.fromJson(Map<String, dynamic> json) =>
      RotaContributionRecord(
        id: json['id'] as String,
        sessionId: json['sessionId'] as String,
        recipeId: json['recipeId'] as String,
        memberId: json['memberId'] as String,
        memberName: json['memberName'] as String,
        taskType: TaskType.values.byName(json['taskType'] as String),
        role: json['role'] as String,
        completedAt: DateTime.parse(json['completedAt'] as String),
        durationMinutes: json['durationMinutes'] as int? ?? 15,
      );
}

/// Fair-share contribution summary for a single member.
class MemberContributionSummary {
  final String memberId;
  final String memberName;
  final int totalTasksCompleted;
  final int timesLeadCook;
  final int timesCoCook;
  final Map<TaskType, int> tasksByType;
  final String celebratoryBadge; // Non-shaming celebratory title

  const MemberContributionSummary({
    required this.memberId,
    required this.memberName,
    required this.totalTasksCompleted,
    required this.timesLeadCook,
    required this.timesCoCook,
    required this.tasksByType,
    required this.celebratoryBadge,
  });
}

/// Non-shaming household fair-share summary.
class FairShareSummary {
  final int totalSessions;
  final int totalTasksCompleted;
  final List<MemberContributionSummary> memberSummaries;
  final String celebratoryHeadline;
  final String teamworkInsight;
  final String rotationSuggestion;

  const FairShareSummary({
    required this.totalSessions,
    required this.totalTasksCompleted,
    required this.memberSummaries,
    required this.celebratoryHeadline,
    required this.teamworkInsight,
    required this.rotationSuggestion,
  });
}

/// Engine for splitting recipes into parallel tasks, assigning to crew,
/// generating warm invitation prompts, and tracking fair-share rota.
class CrewEngine {
  /// Splits a recipe into parallel tasks based on ingredients, steps, and whistle profile.
  static List<CookTask> splitRecipe({
    required RegionRecipe recipe,
    List<RegionIngredient>? catalogIngredients,
  }) {
    final tasks = <CookTask>[];
    final recipeLower = recipe.titleEn.toLowerCase();
    final isBreadOrRoti = recipeLower.contains('roti') ||
        recipeLower.contains('paratha') ||
        recipeLower.contains('puri') ||
        recipeLower.contains('naan') ||
        recipe.category.toLowerCase().contains('bread');

    // 1. Wash & Chop (Prep)
    final hasVegOrLentils = recipe.ingredients.isNotEmpty;
    if (hasVegOrLentils) {
      final ingredientsSummary = recipe.ingredients
          .take(3)
          .map((i) => i.ingredientId.replaceAll('_', ' '))
          .join(', ');
      tasks.add(
        CookTask(
          id: '${recipe.id}_wash_chop',
          recipeId: recipe.id,
          taskType: TaskType.washChop,
          titleEn: 'Wash & Chop Vegetables',
          titleNe: 'तरकारी धुने र काट्ने',
          descriptionEn: 'Wash lentils/rice and finely chop vegetables ($ingredientsSummary).',
          descriptionNe: 'दाल/चामल पखाल्ने र तरकारी तयार गर्ने।',
          estimatedMinutes: (recipe.prepTimeMinutes * 0.6).round().clamp(5, 20),
          minimumAge: 5, // 5+ can wash; cutting needs teen/adult
          isKidFriendly: true,
          requiresSupervision: true,
          isParallel: true,
        ),
      );
    }

    // 2. Grind Masala (Prep)
    final needsGrinding = recipe.ingredients.any((i) {
      final id = i.ingredientId.toLowerCase();
      return id.contains('ginger') ||
          id.contains('garlic') ||
          id.contains('chilli') ||
          id.contains('cumin') ||
          id.contains('coriander') ||
          id.contains('masala');
    }) || recipe.steps.any((s) =>
        s.instructionEn.toLowerCase().contains('grind') ||
        s.instructionEn.toLowerCase().contains('paste') ||
        s.instructionEn.toLowerCase().contains('pound'));

    if (needsGrinding) {
      tasks.add(
        CookTask(
          id: '${recipe.id}_grind_masala',
          recipeId: recipe.id,
          taskType: TaskType.grindMasala,
          titleEn: 'Grind Fresh Masala',
          titleNe: 'ताजा मसला पिस्ने',
          descriptionEn: 'Pound ginger, garlic, and fresh whole spices on silauto or blender.',
          descriptionNe: 'अदुवा, लसुन र मसला पिस्ने वा सिलौटोमा कुट्ने।',
          estimatedMinutes: 8,
          minimumAge: 10,
          isKidFriendly: true,
          requiresSupervision: false,
          isParallel: true,
        ),
      );
    }

    // 3. Watch Cooker (Pressure Cooking / Whistle Monitoring)
    if (recipe.pressureCooker.enabled && recipe.pressureCooker.recommendedWhistles > 0) {
      final whistles = recipe.pressureCooker.recommendedWhistles;
      tasks.add(
        CookTask(
          id: '${recipe.id}_watch_cooker',
          recipeId: recipe.id,
          taskType: TaskType.watchCooker,
          titleEn: 'Watch Pressure Cooker ($whistles whistles)',
          titleNe: 'कुकरको सिट्टी गन्ने ($whistles सिट्टी)',
          descriptionEn: 'Keep an ear out for the pressure cooker and count $whistles whistles from a safe distance.',
          descriptionNe: 'सुरक्षित दूरीबाट कुकरको $whistles सिट्टी गन्ने र ध्यान राख्ने।',
          estimatedMinutes: (recipe.cookTimeMinutes * 0.7).round().clamp(8, 30),
          minimumAge: 5, // Highly kid-friendly!
          isKidFriendly: true,
          requiresSupervision: false,
          isParallel: false,
        ),
      );
    }

    // 4. Roll Rotis (Active Cooking for flatbreads/rotis)
    if (isBreadOrRoti) {
      tasks.add(
        CookTask(
          id: '${recipe.id}_roll_rotis',
          recipeId: recipe.id,
          taskType: TaskType.rollRotis,
          titleEn: 'Roll & Cook Hot Rotis',
          titleNe: 'रोटी बेल्ने र सेक्ने',
          descriptionEn: 'Knead dough portions, roll round rotis with belan, and flip on hot tava.',
          descriptionNe: 'पिठोको लोला बनाउने, गोलो रोटी बेल्ने र तावामा सेक्ने।',
          estimatedMinutes: (recipe.cookTimeMinutes * 0.8).round().clamp(10, 25),
          minimumAge: 12,
          isKidFriendly: false,
          requiresSupervision: false,
          isParallel: true,
        ),
      );
    }

    // 5. Simmer & Stir (Tadka, Sauteing, Seasoning)
    tasks.add(
      CookTask(
        id: '${recipe.id}_simmer_stir',
        recipeId: recipe.id,
        taskType: TaskType.simmerStir,
        titleEn: 'Temper Tadka & Simmer',
        titleNe: 'झान्न र चलाउन',
        descriptionEn: 'Heat oil/ghee, temper fenugreek and cumin, saute, and stir until tender.',
        descriptionNe: 'तेल/घ्यूमा मेथी जिरा झाङ्ने, भुट्ने र चलाउने।',
        estimatedMinutes: recipe.cookTimeMinutes.clamp(10, 35),
        minimumAge: 14,
        isKidFriendly: false,
        requiresSupervision: false,
        isParallel: false,
      ),
    );

    // 6. Clean-up & Table Setup
    tasks.add(
      CookTask(
        id: '${recipe.id}_clean_up',
        recipeId: recipe.id,
        taskType: TaskType.cleanUp,
        titleEn: 'Clean-up & Set the Table',
        titleNe: 'थाल लगाउने र भान्सा सफा गर्ने',
        descriptionEn: 'Set katoris, plates, and water glasses, then wash prep utensils and wipe counters.',
        descriptionNe: 'थाल, कचौरा र पानीको गिलास राख्ने, र भान्साको काउन्टर सफा गर्ने।',
        estimatedMinutes: 10,
        minimumAge: 4, // Very kid-friendly
        isKidFriendly: true,
        requiresSupervision: false,
        isParallel: true,
      ),
    );

    return tasks;
  }

  /// Assigns tasks to available crew members taking into account:
  /// 1. Age safety constraint (must be capable).
  /// 2. Availability (only available members).
  /// 3. Avoided tasks penalty.
  /// 4. Preferred tasks boost.
  /// 5. Historical fair-share balancing (ensures rotation).
  static List<CookTask> assignTasks({
    required List<CookTask> tasks,
    required List<MemberCrewProfile> crew,
    String? leadCookMemberId,
    List<RotaContributionRecord>? history,
  }) {
    if (crew.isEmpty) return tasks;

    final availableCrew = crew.where((m) => m.isAvailable).toList();
    if (availableCrew.isEmpty) return tasks;

    // Track how many tasks assigned to each member in this session
    final currentSessionLoad = <String, int>{
      for (final m in availableCrew) m.memberId: 0,
    };

    // Calculate historical task counts per member to balance rotation
    final historicalTaskCount = <String, int>{
      for (final m in availableCrew) m.memberId: 0,
    };
    final historicalTaskTypeCount = <String, Map<TaskType, int>>{
      for (final m in availableCrew)
        m.memberId: {for (final t in TaskType.values) t: 0},
    };

    if (history != null) {
      for (final rec in history) {
        if (historicalTaskCount.containsKey(rec.memberId)) {
          historicalTaskCount[rec.memberId] = (historicalTaskCount[rec.memberId] ?? 0) + 1;
          historicalTaskTypeCount[rec.memberId]![rec.taskType] =
              (historicalTaskTypeCount[rec.memberId]![rec.taskType] ?? 0) + 1;
        }
      }
    }

    // Lead cook gets primary cooking tasks if available (simmerStir or watchCooker)
    final leadCook = availableCrew.firstWhere(
      (m) => m.memberId == leadCookMemberId,
      orElse: () => availableCrew.first,
    );

    for (final task in tasks) {
      // Find eligible members based on age safety
      final eligible = availableCrew.where((m) => m.canPerformTask(task.taskType)).toList();
      if (eligible.isEmpty) continue;

      // Score each candidate
      MemberCrewProfile? bestCandidate;
      double highestScore = -9999.0;

      for (final candidate in eligible) {
        double score = 0.0;

        // Lead cook gets a strong preference for main cooking
        if (candidate.memberId == leadCook.memberId &&
            (task.taskType == TaskType.simmerStir || task.taskType == TaskType.rollRotis)) {
          score += 50.0;
        }

        // Children / toddlers get priority for kid-friendly tasks like whistle counting or table setting
        if (candidate.ageGroup == AgeGroup.child && task.taskType == TaskType.watchCooker) {
          score += 40.0; // Great bonding and fun for kids
        }
        if (candidate.ageGroup == AgeGroup.toddler && task.taskType == TaskType.cleanUp) {
          score += 30.0;
        }

        // Member preference boost
        if (candidate.preferredTasks.contains(task.taskType)) {
          score += 25.0;
        }

        // Avoided task penalty
        if (candidate.avoidedTasks.contains(task.taskType)) {
          score -= 40.0;
        }

        // Fair-share rotation: penalize candidate if they already did this specific task type often
        final pastTypeCount = historicalTaskTypeCount[candidate.memberId]?[task.taskType] ?? 0;
        score -= pastTypeCount * 3.0;

        // Current session load balancing
        final load = currentSessionLoad[candidate.memberId] ?? 0;
        score -= load * 15.0;

        if (score > highestScore) {
          highestScore = score;
          bestCandidate = candidate;
        }
      }

      if (bestCandidate != null) {
        task.assignedMemberId = bestCandidate.memberId;
        task.assignedMemberName = bestCandidate.name;
        currentSessionLoad[bestCandidate.memberId] =
            (currentSessionLoad[bestCandidate.memberId] ?? 0) + 1;
      }
    }

    return tasks;
  }

  /// Generates a warm, friendly invitation prompt for the lead cook.
  /// Example: "Invite Sita & Rohan to help with Dal Bhat? Sita can roll rotis and Rohan can watch the cooker."
  static String generateInvitationPrompt({
    required RegionRecipe recipe,
    required MemberCrewProfile leadCook,
    required List<MemberCrewProfile> crew,
    required List<CookTask> assignedTasks,
  }) {
    final otherCrew = crew.where((m) => m.memberId != leadCook.memberId && m.isAvailable).toList();
    if (otherCrew.isEmpty) {
      return 'Ready to cook ${recipe.titleEn}? All tasks are set for you!';
    }

    final names = otherCrew.map((m) => m.name).toList();
    final namesString = names.length == 1
        ? names.first
        : names.length == 2
            ? '${names[0]} & ${names[1]}'
            : '${names.take(names.length - 1).join(', ')} & ${names.last}';

    // Highlight specific task matches for key members
    final highlights = <String>[];
    for (final member in otherCrew.take(2)) {
      final task = assignedTasks.firstWhere(
        (t) => t.assignedMemberId == member.memberId,
        orElse: () => assignedTasks.first,
      );
      if (task.assignedMemberId == member.memberId) {
        if (task.taskType == TaskType.watchCooker) {
          highlights.add('${member.name} can count whistles');
        } else if (task.taskType == TaskType.rollRotis) {
          highlights.add('${member.name} can roll hot rotis');
        } else if (task.taskType == TaskType.washChop) {
          highlights.add('${member.name} can prep & chop');
        } else if (task.taskType == TaskType.grindMasala) {
          highlights.add('${member.name} can grind fresh masala');
        } else if (task.taskType == TaskType.cleanUp) {
          highlights.add('${member.name} can set the table');
        }
      }
    }

    final detail = highlights.isNotEmpty ? ' (${highlights.join(', ')})' : '';
    return 'Invite $namesString to help with ${recipe.titleEn}?$detail';
  }

  /// Calculates fair-share summary and celebratory badges without guilt.
  static FairShareSummary calculateFairShareSummary({
    required List<MemberCrewProfile> crew,
    required List<RotaContributionRecord> history,
  }) {
    final sessionIds = history.map((h) => h.sessionId).toSet();
    final totalSessions = sessionIds.length;
    final totalTasks = history.length;

    final memberSummaries = <MemberContributionSummary>[];

    for (final member in crew) {
      final memberRecords = history.where((r) => r.memberId == member.memberId).toList();
      final leadCount = memberRecords.where((r) => r.role == 'leadCook').length;
      final coCookCount = memberRecords.where((r) => r.role == 'coCook' || r.role == 'helper').length;

      final byType = <TaskType, int>{
        for (final t in TaskType.values) t: 0,
      };
      for (final r in memberRecords) {
        byType[r.taskType] = (byType[r.taskType] ?? 0) + 1;
      }

      // Assign fun, celebratory badge based on top contribution
      String badge = 'Kitchen Contributor';
      int maxCount = 0;
      TaskType? topType;
      byType.forEach((type, count) {
        if (count > maxCount) {
          maxCount = count;
          topType = type;
        }
      });

      if (leadCount >= 3) {
        badge = 'Master Head Chef';
      } else if (topType == TaskType.watchCooker && maxCount >= 2) {
        badge = 'Whistle Guardian 🔔';
      } else if (topType == TaskType.rollRotis && maxCount >= 2) {
        badge = 'Roti Artist 🫓';
      } else if (topType == TaskType.washChop && maxCount >= 2) {
        badge = 'Master Prep Pro 🔪';
      } else if (topType == TaskType.grindMasala && maxCount >= 2) {
        badge = 'Flavor Alchemist 🌿';
      } else if (topType == TaskType.cleanUp && maxCount >= 2) {
        badge = 'Table Host & Harmony ✨';
      } else if (memberRecords.isNotEmpty) {
        badge = 'Valued Kitchen Helper 🤝';
      } else {
        badge = 'Ready for Next Feast 🎉';
      }

      memberSummaries.add(
        MemberContributionSummary(
          memberId: member.memberId,
          memberName: member.name,
          totalTasksCompleted: memberRecords.length,
          timesLeadCook: leadCount,
          timesCoCook: coCookCount,
          tasksByType: byType,
          celebratoryBadge: badge,
        ),
      );
    }

    final headline = totalSessions > 0
        ? 'Teamwork this week: $totalSessions shared cooking sessions! 🌟'
        : 'Welcome to Co-Cooking! Ready for your first household session?';

    final teamworkInsight = totalTasks > 0
        ? 'Everyone brings something special to the kitchen table. Cooking together made prep ${totalTasks * 4} minutes faster!'
        : 'Invite household members to chop, listen for whistles, or set the table.';

    // Non-shaming rotation suggestion
    String rotationSuggestion = 'Keep sharing the joy of cooking!';
    if (memberSummaries.isNotEmpty) {
      final leastCleanUp = memberSummaries.reduce((a, b) =>
          (a.tasksByType[TaskType.cleanUp] ?? 0) <= (b.tasksByType[TaskType.cleanUp] ?? 0) ? a : b);
      rotationSuggestion = 'Next session tip: Let ${leastCleanUp.memberName} try table styling or gentle clean-up!';
    }

    return FairShareSummary(
      totalSessions: totalSessions,
      totalTasksCompleted: totalTasks,
      memberSummaries: memberSummaries,
      celebratoryHeadline: headline,
      teamworkInsight: teamworkInsight,
      rotationSuggestion: rotationSuggestion,
    );
  }
}
