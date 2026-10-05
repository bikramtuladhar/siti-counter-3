import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchen_engine/kitchen_engine.dart';
import 'package:siti_counter/kitchen/multi_dish_kitchen_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MultiDishKitchenScreen Widget Tests (Issue #46)', () {
    testWidgets('Renders parallel lanes and status indicators', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: MultiDishKitchenScreen(currentLanguage: 'ne'),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify Header
      expect(find.text('बहु-परिकार भान्सा'), findsOneWidget);
      expect(find.textContaining('बर्नर'), findsWidgets);

      // 2. Verify all 4 default sample lanes are rendered
      expect(find.byKey(const Key('lane_card_lane_dal')), findsOneWidget);
      expect(find.byKey(const Key('lane_card_lane_rice')), findsOneWidget);
      expect(find.byKey(const Key('lane_card_lane_sabzi')), findsOneWidget);
      expect(find.byKey(const Key('lane_card_lane_chapati')), findsOneWidget);

      // 3. Verify Dal siti count badge
      expect(find.text('2 / 3 siti'), findsOneWidget);

      // 4. Verify Rice countdown timer
      expect(find.byKey(const Key('timer_badge_lane_rice')), findsOneWidget);

      // 5. Verify Sabzi is waiting
      expect(find.text('पर्खँदै'), findsWidgets);
    });

    testWidgets('Displays burner capacity conflict warning when lanes exceed cooktop',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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
        dishName: 'Sabzi',
        dishNameNe: 'सब्जी',
        vesselType: CookerVesselType.kadaiPan,
        vesselId: 'v3',
        requiresBurner: true,
        status: LaneStatus.cooking, // 3 cooking on 2 burners
      ));

      await tester.pumpWidget(
        MaterialApp(
          home: MultiDishKitchenScreen(engine: engine, currentLanguage: 'en'),
        ),
      );
      await tester.pumpAndSettle();

      // Verify conflict banner exists
      expect(find.byKey(const Key('conflict_banner_burnerCapacity')), findsOneWidget);
      expect(find.textContaining('Cooktop capacity exceeded'), findsOneWidget);
      expect(find.textContaining('Move 1 dish(es) to waiting status'), findsOneWidget);
    });

    testWidgets('Displays vessel collision warning when same pot assigned twice',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final engine = MultiDishKitchenEngine(maxBurners: 3);
      engine.addLane(CookingLane(
        id: 'lane_dal',
        dishName: 'Dal',
        dishNameNe: 'दाल',
        vesselType: CookerVesselType.pressureCooker5L,
        vesselId: 'shared_pc_5l',
        requiresBurner: true,
        status: LaneStatus.cooking,
      ));
      engine.addLane(CookingLane(
        id: 'lane_khichdi',
        dishName: 'Khichdi',
        dishNameNe: 'खिचडी',
        vesselType: CookerVesselType.pressureCooker5L,
        vesselId: 'shared_pc_5l', // Colliding vessel
        requiresBurner: true,
        status: LaneStatus.cooking,
      ));

      await tester.pumpWidget(
        MaterialApp(
          home: MultiDishKitchenScreen(engine: engine, currentLanguage: 'en'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('conflict_banner_vesselCollision')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('conflict_banner_vesselCollision')),
          matching: find.textContaining('shared_pc_5l'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Acoustic whistle disambiguation dialog prompts cook and attributes count',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final engine = MultiDishKitchenEngine(maxBurners: 2);
      engine.addLane(CookingLane(
        id: 'lane_dal',
        dishName: 'Dal Tadka',
        dishNameNe: 'दाल तड्का',
        vesselType: CookerVesselType.pressureCooker3L,
        vesselId: 'pc_3l',
        requiresBurner: true,
        status: LaneStatus.cooking,
        isAcousticCooker: true,
        currentWhistles: 1,
        targetWhistles: 3,
      ));
      engine.addLane(CookingLane(
        id: 'lane_mutton',
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

      await tester.pumpWidget(
        MaterialApp(
          home: MultiDishKitchenScreen(engine: engine, currentLanguage: 'ne'),
        ),
      );
      await tester.pumpAndSettle();

      // Trigger acoustic whistle
      await tester.tap(find.byKey(const Key('btn_trigger_whistle')));
      await tester.pumpAndSettle();

      // 1. Verify disambiguation dialog opens
      expect(find.byKey(const Key('whistle_disambiguation_dialog')), findsOneWidget);
      expect(find.text('सिट्ठी बज्यो! (कुन कुकर?)'), findsOneWidget);
      expect(find.byKey(const Key('btn_disambiguate_lane_dal')), findsOneWidget);
      expect(find.byKey(const Key('btn_disambiguate_lane_mutton')), findsOneWidget);

      // 2. Select Mutton cooker
      await tester.tap(find.byKey(const Key('btn_disambiguate_lane_mutton')));
      await tester.pumpAndSettle();

      // 3. Dialog dismissed and mutton whistle count incremented from 4 to 5
      expect(find.byKey(const Key('whistle_disambiguation_dialog')), findsNothing);
      expect(engine.getLane('lane_mutton')?.currentWhistles, 5);
      expect(engine.getLane('lane_dal')?.currentWhistles, 1);
    });
  });
}
