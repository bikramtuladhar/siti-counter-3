import 'dart:async';
import 'dart:convert';
import 'package:kitchen_engine/crew_engine.dart';
import 'package:sqflite/sqflite.dart';

/// SQLite-backed offline repository for cooking crew profiles and fair-share rota contributions.
class CrewRepository {
  final Database _db;

  CrewRepository(this._db);

  /// Initializes the SQLite schema for crew member profiles and rota contributions.
  static Future<void> createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS crew_member_profiles (
        member_id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        age INTEGER NOT NULL DEFAULT 30,
        age_group TEXT NOT NULL DEFAULT 'adult',
        skill_level TEXT NOT NULL DEFAULT 'intermediate',
        preferred_tasks_json TEXT NOT NULL DEFAULT '[]',
        avoided_tasks_json TEXT NOT NULL DEFAULT '[]',
        is_available INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cooking_rota_contributions (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        recipe_id TEXT NOT NULL,
        member_id TEXT NOT NULL,
        member_name TEXT NOT NULL,
        task_type TEXT NOT NULL,
        role TEXT NOT NULL,
        completed_at TEXT NOT NULL,
        duration_minutes INTEGER NOT NULL DEFAULT 15
      )
    ''');

    // Seed default crew members if empty
    final existing = await db.query('crew_member_profiles');
    if (existing.isEmpty) {
      final defaults = [
        MemberCrewProfile(
          memberId: 'm1',
          name: 'Bikram',
          age: 38,
          skillLevel: SkillLevel.intermediate,
          preferredTasks: {TaskType.washChop, TaskType.grindMasala},
          avoidedTasks: {TaskType.cleanUp},
        ),
        MemberCrewProfile(
          memberId: 'm2',
          name: 'Srijana',
          age: 36,
          skillLevel: SkillLevel.expert,
          preferredTasks: {TaskType.rollRotis, TaskType.simmerStir},
        ),
        MemberCrewProfile(
          memberId: 'm3',
          name: 'Aayush',
          age: 9,
          skillLevel: SkillLevel.beginner,
          preferredTasks: {TaskType.watchCooker, TaskType.cleanUp},
        ),
      ];

      final batch = db.batch();
      for (final m in defaults) {
        batch.insert('crew_member_profiles', {
          'member_id': m.memberId,
          'name': m.name,
          'age': m.age,
          'age_group': m.ageGroup.name,
          'skill_level': m.skillLevel.name,
          'preferred_tasks_json': jsonEncode(m.preferredTasks.map((t) => t.name).toList()),
          'avoided_tasks_json': jsonEncode(m.avoidedTasks.map((t) => t.name).toList()),
          'is_available': m.isAvailable ? 1 : 0,
        });
      }
      await batch.commit(noResult: true);
    }
  }

  /// Retrieves all crew profiles.
  Future<List<MemberCrewProfile>> getCrewProfiles() async {
    final rows = await _db.query('crew_member_profiles');
    return rows.map((r) {
      final preferredList = (jsonDecode(r['preferred_tasks_json'] as String) as List<dynamic>)
          .map((t) => TaskType.values.byName(t.toString()))
          .toSet();
      final avoidedList = (jsonDecode(r['avoided_tasks_json'] as String) as List<dynamic>)
          .map((t) => TaskType.values.byName(t.toString()))
          .toSet();

      return MemberCrewProfile(
        memberId: r['member_id'] as String,
        name: r['name'] as String,
        age: r['age'] as int,
        ageGroup: AgeGroup.values.byName(r['age_group'] as String),
        skillLevel: SkillLevel.values.byName(r['skill_level'] as String),
        preferredTasks: preferredList,
        avoidedTasks: avoidedList,
        isAvailable: (r['is_available'] as int) == 1,
      );
    }).toList();
  }

  /// Saves or updates a member's crew profile.
  Future<void> saveCrewProfile(MemberCrewProfile profile) async {
    await _db.insert(
      'crew_member_profiles',
      {
        'member_id': profile.memberId,
        'name': profile.name,
        'age': profile.age,
        'age_group': profile.ageGroup.name,
        'skill_level': profile.skillLevel.name,
        'preferred_tasks_json': jsonEncode(profile.preferredTasks.map((t) => t.name).toList()),
        'avoided_tasks_json': jsonEncode(profile.avoidedTasks.map((t) => t.name).toList()),
        'is_available': profile.isAvailable ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Logs a completed contribution record from a cooking session.
  Future<void> logContribution(RotaContributionRecord record) async {
    await _db.insert(
      'cooking_rota_contributions',
      {
        'id': record.id,
        'session_id': record.sessionId,
        'recipe_id': record.recipeId,
        'member_id': record.memberId,
        'member_name': record.memberName,
        'task_type': record.taskType.name,
        'role': record.role,
        'completed_at': record.completedAt.toIso8601String(),
        'duration_minutes': record.durationMinutes,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Retrieves recent contribution history.
  Future<List<RotaContributionRecord>> getContributionHistory({int limit = 50}) async {
    final rows = await _db.query(
      'cooking_rota_contributions',
      orderBy: 'completed_at DESC',
      limit: limit,
    );

    return rows.map((r) => RotaContributionRecord(
      id: r['id'] as String,
      sessionId: r['session_id'] as String,
      recipeId: r['recipe_id'] as String,
      memberId: r['member_id'] as String,
      memberName: r['member_name'] as String,
      taskType: TaskType.values.byName(r['task_type'] as String),
      role: r['role'] as String,
      completedAt: DateTime.parse(r['completed_at'] as String),
      durationMinutes: r['duration_minutes'] as int? ?? 15,
    )).toList();
  }

  /// Calculates fair-share summary and celebratory badges without guilt.
  Future<FairShareSummary> getFairShareSummary() async {
    final crew = await getCrewProfiles();
    final history = await getContributionHistory();
    return CrewEngine.calculateFairShareSummary(
      crew: crew,
      history: history,
    );
  }
}
