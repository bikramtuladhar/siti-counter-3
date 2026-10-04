import { test, describe } from 'node:test';
import assert from 'node:assert/strict';
import {
  CrewEngine,
  MemberCrewProfile,
  canPerformTask,
  getAgeGroup,
  RotaContributionRecord,
} from './crew_engine.js';
import { RegionRecipe } from './region_pack_manager.js';

describe('CrewEngine TypeScript Parity Tests', () => {
  const sampleDal: RegionRecipe = {
    id: 'masyaura_dal',
    titleEn: 'Masyaura Dal',
    titleNe: 'मस्यौरा दाल',
    category: 'Lentils & Pulses',
    cuisine: 'Nepali',
    dietary: ['Vegetarian'],
    prepTimeMinutes: 15,
    cookTimeMinutes: 25,
    servings: 4,
    difficulty: 'Easy',
    ingredients: [
      { ingredientId: 'musuro_dal', quantity: 200, unit: 'g' },
      { ingredientId: 'ginger_garlic', quantity: 25, unit: 'g' },
      { ingredientId: 'onion', quantity: 100, unit: 'g' },
      { ingredientId: 'cumin_seeds', quantity: 5, unit: 'g' },
    ],
    pressureCooker: {
      enabled: true,
      recommendedWhistles: 3,
      altitudeWhistleOffsetKathmandu: 0,
      heatLevel: 'medium',
      releaseType: 'natural',
    },
    seasonality: ['all_year'],
    tags: ['dal', 'lentils'],
  };

  const sampleRoti: RegionRecipe = {
    id: 'chapati_roti',
    titleEn: 'Phulka Roti',
    titleNe: 'फुल्का रोटी',
    category: 'Breads',
    cuisine: 'Nepali',
    dietary: ['Vegetarian'],
    prepTimeMinutes: 20,
    cookTimeMinutes: 15,
    servings: 4,
    difficulty: 'Medium',
    ingredients: [
      { ingredientId: 'wheat_flour', quantity: 300, unit: 'g' },
      { ingredientId: 'water', quantity: 180, unit: 'ml' },
    ],
    pressureCooker: {
      enabled: false,
      recommendedWhistles: 0,
      altitudeWhistleOffsetKathmandu: 0,
      heatLevel: 'medium',
      releaseType: 'none',
    },
    seasonality: ['all_year'],
    tags: ['roti', 'bread'],
  };

  describe('Recipe Task Splitting', () => {
    test('splits pressure cooker dal recipe into parallel tasks', () => {
      const tasks = CrewEngine.splitRecipe(sampleDal);

      assert.ok(tasks.some((t) => t.taskType === 'washChop'));
      assert.ok(tasks.some((t) => t.taskType === 'grindMasala'));
      assert.ok(tasks.some((t) => t.taskType === 'watchCooker'));
      assert.ok(tasks.some((t) => t.taskType === 'simmerStir'));
      assert.ok(tasks.some((t) => t.taskType === 'cleanUp'));

      const cookerTask = tasks.find((t) => t.taskType === 'watchCooker');
      assert.ok(cookerTask?.titleEn.includes('3 whistles'));
      assert.strictEqual(cookerTask?.isKidFriendly, true);
    });

    test('splits roti flatbread recipe into rollRotis and cleanup tasks', () => {
      const tasks = CrewEngine.splitRecipe(sampleRoti);

      assert.ok(tasks.some((t) => t.taskType === 'rollRotis'));
      assert.ok(tasks.some((t) => t.taskType === 'cleanUp'));
      assert.strictEqual(tasks.some((t) => t.taskType === 'watchCooker'), false);
    });
  });

  describe('Age Appropriateness & Safety Rules', () => {
    test('toddler safety check', () => {
      assert.strictEqual(getAgeGroup(3), 'toddler');
      assert.strictEqual(canPerformTask('toddler', 'cleanUp'), true);
      assert.strictEqual(canPerformTask('toddler', 'washChop'), false);
      assert.strictEqual(canPerformTask('toddler', 'watchCooker'), false);
      assert.strictEqual(canPerformTask('toddler', 'simmerStir'), false);
    });

    test('child (8yo) safety check', () => {
      assert.strictEqual(getAgeGroup(8), 'child');
      assert.strictEqual(canPerformTask('child', 'watchCooker'), true);
      assert.strictEqual(canPerformTask('child', 'cleanUp'), true);
      assert.strictEqual(canPerformTask('child', 'washChop'), true);
      assert.strictEqual(canPerformTask('child', 'simmerStir'), false);
      assert.strictEqual(canPerformTask('child', 'rollRotis'), false);
    });

    test('teen and adult can perform all tasks', () => {
      const taskTypes = ['washChop', 'grindMasala', 'watchCooker', 'rollRotis', 'simmerStir', 'cleanUp'] as const;
      for (const t of taskTypes) {
        assert.strictEqual(canPerformTask('teen', t), true);
        assert.strictEqual(canPerformTask('adult', t), true);
      }
    });
  });

  describe('Task Assignment & Invitation Generation', () => {
    const sita: MemberCrewProfile = {
      memberId: 'm_sita',
      name: 'Sita',
      age: 38,
      skillLevel: 'expert',
      preferredTasks: ['rollRotis', 'simmerStir'],
    };

    const bikram: MemberCrewProfile = {
      memberId: 'm_bikram',
      name: 'Bikram',
      age: 40,
      skillLevel: 'intermediate',
      preferredTasks: ['washChop', 'grindMasala'],
      avoidedTasks: ['cleanUp'],
    };

    const rohan: MemberCrewProfile = {
      memberId: 'm_rohan',
      name: 'Rohan',
      age: 9,
      skillLevel: 'beginner',
      preferredTasks: ['watchCooker'],
    };

    test('assigns tasks respecting age safety, preferences, and lead cook role', () => {
      const tasks = CrewEngine.splitRecipe(sampleDal);
      const assigned = CrewEngine.assignTasks({
        tasks,
        crew: [sita, bikram, rohan],
        leadCookMemberId: sita.memberId,
      });

      const cookerTask = assigned.find((t) => t.taskType === 'watchCooker');
      assert.strictEqual(cookerTask?.assignedMemberId, rohan.memberId);

      const stirTask = assigned.find((t) => t.taskType === 'simmerStir');
      assert.strictEqual(stirTask?.assignedMemberId, sita.memberId);

      const prepTask = assigned.find((t) => t.taskType === 'washChop');
      assert.strictEqual(prepTask?.assignedMemberId, bikram.memberId);
    });

    test('generates warm, engaging invitation prompt for lead cook', () => {
      const tasks = CrewEngine.splitRecipe(sampleDal);
      const assigned = CrewEngine.assignTasks({
        tasks,
        crew: [sita, bikram, rohan],
        leadCookMemberId: sita.memberId,
      });

      const prompt = CrewEngine.generateInvitationPrompt({
        recipe: sampleDal,
        leadCook: sita,
        crew: [sita, bikram, rohan],
        assignedTasks: assigned,
      });

      assert.ok(prompt.includes('Invite Bikram & Rohan to help with Masyaura Dal?'));
      assert.ok(prompt.includes('Rohan can count whistles'));
    });
  });

  describe('Fair-Share Rota & Non-Shaming Teamwork Analytics', () => {
    const sita: MemberCrewProfile = { memberId: 'm_sita', name: 'Sita', age: 38 };
    const bikram: MemberCrewProfile = { memberId: 'm_bikram', name: 'Bikram', age: 40 };
    const rohan: MemberCrewProfile = { memberId: 'm_rohan', name: 'Rohan', age: 9 };

    const history: RotaContributionRecord[] = [
      {
        id: 'rec_1',
        sessionId: 'sess_1',
        recipeId: 'dal',
        memberId: sita.memberId,
        memberName: sita.name,
        taskType: 'simmerStir',
        role: 'leadCook',
        completedAt: new Date(Date.now() - 3 * 86400000),
      },
      {
        id: 'rec_2',
        sessionId: 'sess_1',
        recipeId: 'dal',
        memberId: rohan.memberId,
        memberName: rohan.name,
        taskType: 'watchCooker',
        role: 'coCook',
        completedAt: new Date(Date.now() - 3 * 86400000),
      },
      {
        id: 'rec_3',
        sessionId: 'sess_1',
        recipeId: 'dal',
        memberId: bikram.memberId,
        memberName: bikram.name,
        taskType: 'washChop',
        role: 'helper',
        completedAt: new Date(Date.now() - 3 * 86400000),
      },
      {
        id: 'rec_4',
        sessionId: 'sess_2',
        recipeId: 'tarkari',
        memberId: sita.memberId,
        memberName: sita.name,
        taskType: 'simmerStir',
        role: 'leadCook',
        completedAt: new Date(Date.now() - 1 * 86400000),
      },
      {
        id: 'rec_5',
        sessionId: 'sess_2',
        recipeId: 'tarkari',
        memberId: rohan.memberId,
        memberName: rohan.name,
        taskType: 'watchCooker',
        role: 'coCook',
        completedAt: new Date(Date.now() - 1 * 86400000),
      },
    ];

    test('calculates fair-share summary with celebratory badges and zero guilt', () => {
      const summary = CrewEngine.calculateFairShareSummary({
        crew: [sita, bikram, rohan],
        history,
      });

      assert.strictEqual(summary.totalSessions, 2);
      assert.strictEqual(summary.totalTasksCompleted, 5);
      assert.ok(summary.celebratoryHeadline.includes('2 shared cooking sessions'));

      const rohanSummary = summary.memberSummaries.find((m) => m.memberId === rohan.memberId);
      assert.ok(rohanSummary?.celebratoryBadge.includes('Whistle Guardian'));

      assert.ok(!summary.teamworkInsight.includes('debt'));
      assert.ok(!summary.teamworkInsight.includes('lazy'));
      assert.ok(!summary.teamworkInsight.includes('behind'));
    });
  });
});
