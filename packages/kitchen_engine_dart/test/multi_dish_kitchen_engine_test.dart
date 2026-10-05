import 'package:kitchen_engine/kitchen_engine.dart';
import 'package:test/test.dart';

void main() {
  group('MultiDishKitchenEngine Dart Parity Tests', () {
    test('Parallel cooking lanes management and single cooker whistle', () {
      final engine = MultiDishKitchenEngine(maxBurners: 2);

      final dalLane = CookingLane(
        id: 'lane_dal',
        dishName: 'Kalo Dal',
        dishNameNe: 'कालो दाल',
        vesselType: CookerVesselType.pressureCooker3L,
        vesselId: 'pc_3l',
        requiresBurner: true,
        burnerIndex: 1,
        status: LaneStatus.cooking,
        isAcousticCooker: true,
        currentWhistles: 1,
        targetWhistles: 3,
        heatLevel: 'medium',
      );

      final riceLane = CookingLane(
        id: 'lane_rice',
        dishName: 'Basmati Bhat',
        dishNameNe: 'बासमती भात',
        vesselType: CookerVesselType.saucepan,
        vesselId: 'pot_rice',
        requiresBurner: true,
        burnerIndex: 2,
        status: LaneStatus.cooking,
        isAcousticCooker: false,
        remainingSeconds: 510, // 8m 30s
        totalSeconds: 600,
        heatLevel: 'low',
      );

      final sabziLane = CookingLane(
        id: 'lane_sabzi',
        dishName: 'Aloo Cauli',
        dishNameNe: 'आलु काउली',
        vesselType: CookerVesselType.kadaiPan,
        vesselId: 'kadai_iron',
        requiresBurner: true,
        status: LaneStatus.waiting,
        remainingSeconds: 250, // 4m 10s
        totalSeconds: 400,
        heatLevel: 'off',
      );

      final chapatiLane = CookingLane(
        id: 'lane_chapati',
        dishName: 'Gahu Chapati',
        dishNameNe: 'गहुँको रोटी',
        vesselType: CookerVesselType.tawa,
        vesselId: 'tawa_iron',
        requiresBurner: true,
        status: LaneStatus.waiting,
        heatLevel: 'off',
      );

      engine.addLane(dalLane);
      engine.addLane(riceLane);
      engine.addLane(sabziLane);
      engine.addLane(chapatiLane);

      expect(engine.lanes.length, 4);

      // No conflict while 2 are cooking and 2 are waiting on a 2-burner cooktop
      final conflicts = engine.detectConflicts();
      expect(conflicts, isEmpty);

      // Tick timers
      engine.tickTimers(10);
      expect(engine.getLane('lane_rice')?.remainingSeconds, 500);

      // Single acoustic cooker whistle increments immediately
      final whistleResult = engine.handleAcousticWhistle();
      expect(whistleResult['needsDisambiguation'], isFalse);
      expect(whistleResult['attributedLaneId'], 'lane_dal');
      expect(engine.getLane('lane_dal')?.currentWhistles, 2);
    });

    test('Burner capacity conflict warning (>2 dishes active on 2 burners)', () {
      final engine = MultiDishKitchenEngine(maxBurners: 2);

      engine.addLane(CookingLane(
        id: 'lane_1',
        dishName: 'Dal',
        dishNameNe: 'दाल',
        vesselType: CookerVesselType.pressureCooker3L,
        vesselId: 'v1',
        requiresBurner: true,
        status: LaneStatus.cooking,
      ));

      engine.addLane(CookingLane(
        id: 'lane_2',
        dishName: 'Rice',
        dishNameNe: 'भात',
        vesselType: CookerVesselType.saucepan,
        vesselId: 'v2',
        requiresBurner: true,
        status: LaneStatus.cooking,
      ));

      engine.addLane(CookingLane(
        id: 'lane_3',
        dishName: 'Tarkari',
        dishNameNe: 'तरकारी',
        vesselType: CookerVesselType.kadaiPan,
        vesselId: 'v3',
        requiresBurner: true,
        status: LaneStatus.cooking, // 3 dishes on 2 burners!
      ));

      final conflicts = engine.detectConflicts();
      expect(conflicts.length, 1);
      expect(conflicts.first.type, MultiDishConflictType.burnerCapacity);
      expect(conflicts.first.messageEn, contains('Cooktop capacity exceeded: 3 dishes active on 2 burners'));
      expect(conflicts.first.suggestionEn, contains('Move 1 dish(es) to waiting status'));
    });

    test('Vessel collision conflict warning', () {
      final engine = MultiDishKitchenEngine(maxBurners: 3);

      engine.addLane(CookingLane(
        id: 'lane_dal',
        dishName: 'Yellow Dal',
        dishNameNe: 'पहेँलो दाल',
        vesselType: CookerVesselType.pressureCooker5L,
        vesselId: 'pc_5l_only_one',
        requiresBurner: true,
        status: LaneStatus.cooking,
      ));

      engine.addLane(CookingLane(
        id: 'lane_chana',
        dishName: 'Kalo Chana',
        dishNameNe: 'कालो चना',
        vesselType: CookerVesselType.pressureCooker5L,
        vesselId: 'pc_5l_only_one', // SAME vessel ID!
        requiresBurner: true,
        status: LaneStatus.cooking,
      ));

      final conflicts = engine.detectConflicts();
      expect(conflicts.any((c) => c.type == MultiDishConflictType.vesselCollision), isTrue);
      final vesselConflict = conflicts.firstWhere((c) => c.type == MultiDishConflictType.vesselCollision);
      expect(vesselConflict.messageEn, contains("Vessel conflict: Multiple dishes (Yellow Dal & Kalo Chana) assigned to the same vessel 'pc_5l_only_one'"));
      expect(vesselConflict.suggestionEn, contains('Assign an alternate pot'));
    });

    test('Acoustic whistle disambiguation when multiple cookers active', () {
      final engine = MultiDishKitchenEngine(maxBurners: 2);

      engine.addLane(CookingLane(
        id: 'lane_dal',
        dishName: 'Dal',
        dishNameNe: 'दाल',
        vesselType: CookerVesselType.pressureCooker3L,
        vesselId: 'pc_3l',
        requiresBurner: true,
        status: LaneStatus.cooking,
        isAcousticCooker: true,
        currentWhistles: 1,
        targetWhistles: 3,
      ));

      engine.addLane(CookingLane(
        id: 'lane_meat',
        dishName: 'Khasi ko Masu',
        dishNameNe: 'खसीको मासु',
        vesselType: CookerVesselType.pressureCooker5L,
        vesselId: 'pc_5l',
        requiresBurner: true,
        status: LaneStatus.cooking,
        isAcousticCooker: true,
        currentWhistles: 4,
        targetWhistles: 7,
      ));

      // Whistle detected while both are active
      final whistleResult = engine.handleAcousticWhistle();
      expect(whistleResult['needsDisambiguation'], isTrue);
      expect(engine.pendingDisambiguation, isNotNull);
      expect(engine.pendingDisambiguation!.candidateLaneIds, ['lane_dal', 'lane_meat']);

      // Cook disambiguates: "That whistle was for Meat!"
      final resolved = engine.resolveDisambiguation('lane_meat');
      expect(resolved, isTrue);
      expect(engine.getLane('lane_meat')?.currentWhistles, 5);
      expect(engine.getLane('lane_dal')?.currentWhistles, 1);
      expect(engine.pendingDisambiguation, isNull);
    });
  });
}
