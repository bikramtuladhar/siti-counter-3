import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siti_counter/region_pack_fixture.dart';

/// Renders screens to PNG under `test/screenshots/goldens/` so the layout can be reviewed as
/// an image rather than inferred from widget code.
///
/// These are a review tool, not an assertion test. They depend on a specific font file and on
/// the Flutter version's rasteriser, so committing the PNGs would make the suite fail on any
/// machine that is not this one. Regenerate and read the images instead:
///
///     REGENERATE_SCREENSHOTS=1 flutter test --update-goldens \
///       test/screenshots/render_screens_test.dart
///
/// The generated PNGs are gitignored.
///
/// Two things this harness does that ordinary widget tests do not, and both were needed to
/// make the images trustworthy:
///   * it loads a font with Devanagari coverage and sets a theme font family, without which
///     Nepali renders as boxes and every Latin string rendered through a bare `TextStyle`
///     renders as the test placeholder font's solid black blocks;
///   * it loads the Material icon font, without which every icon is an empty square.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Skipped unless explicitly regenerating, so the default `flutter test` run stays
  // deterministic on any machine.
  final regenerate = Platform.environment['REGENERATE_SCREENSHOTS'] == '1';

  setUpAll(() async {
    // flutter_test ships no font with Devanagari coverage, so every Nepali string would
    // render as empty boxes and the screenshots would be useless for reviewing the
    // bilingual UI. Arial Unicode is the one plain TTF on this machine that covers it.
    final fontFile = File(
      '/System/Library/Fonts/Supplemental/Arial Unicode.ttf',
    );
    if (!fontFile.existsSync()) {
      // Not fatal: English still renders, Devanagari becomes boxes.
      // ignore: avoid_print
      print('WARNING: Arial Unicode.ttf not found, Nepali text will render as boxes');
      return;
    }
    final bytes = fontFile.readAsBytesSync();
    for (final family in ['Roboto', 'NotoSans', 'NotoSansDevanagari', 'Mukta']) {
      final loader = FontLoader(family)
        ..addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
      await loader.load();
    }

    // Icons come from a separate bundled font. Without it every icon renders as an empty
    // box and the layout cannot be reviewed.
    final icons = File(
      '/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    if (icons.existsSync()) {
      final loader = FontLoader('MaterialIcons')
        ..addFont(
          Future<ByteData>.value(ByteData.sublistView(icons.readAsBytesSync())),
        );
      await loader.load();
    }
  });

  Future<void> capture(
    WidgetTester tester,
    Widget screen, {
    required String name,
    Size size = const Size(390, 844),
    Future<void> Function(WidgetTester tester)? interact,
  }) async {
    // `size` is a logical viewport (what a phone actually reports); the physical size has to
    // be scaled by the device pixel ratio or the layout is computed for a fraction of the
    // width and every screen overflows.
    tester.view.devicePixelRatio = 2.0;
    tester.view.physicalSize = size * 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // The theme font matters here: most of the app styles text through NepaliTypography,
    // which carries a real fontFamily, but plenty of widgets use a bare TextStyle and inherit
    // the app default. Without a theme family those fall back to the test placeholder font,
    // which draws every Latin character as a solid black box and hides the English UI.
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(fontFamily: 'Roboto'),
        home: screen,
      ),
    );

    // Not pumpAndSettle: screens backed by sqflite need real async time to open the
    // database, and a progress indicator means the tree never goes fully idle.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1200)),
    );
    for (var i = 0; i < 6; i += 1) {
      await tester.pump(const Duration(milliseconds: 120));
    }

    if (interact != null) {
      await interact(tester);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pump(const Duration(milliseconds: 200));
    }

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  testWidgets('seasonal kitchen', (tester) async {
    if (!regenerate) return;
    await capture(
      tester,
      SeasonalKitchenHarness(
        pack: buildDemoRegionPack(),
        language: 'ne',
      ),
      name: '01_seasonal_kitchen_ne',
    );
  });

  testWidgets('seasonal kitchen in English', (tester) async {
    if (!regenerate) return;
    await capture(
      tester,
      SeasonalKitchenHarness(
        pack: buildDemoRegionPack(),
        language: 'en',
      ),
      name: '02_seasonal_kitchen_en',
    );
  });

  testWidgets('kitchen recommendations sheet', (tester) async {
    if (!regenerate) return;
    await capture(
      tester,
      SeasonalKitchenHarness(
        pack: buildDemoRegionPack(),
        language: 'en',
      ),
      name: '03_kitchen_recommendations_sheet',
      // Taller, because the sheet is a long scrollable list.
      size: const Size(390, 1400),
      interact: (tester) async {
        // Actually open the sheet rather than photographing the kitchen again.
        await tester.tap(find.byKey(const Key('recommendation_chip_Night')));
        await tester.pump(const Duration(milliseconds: 400));
      },
    );
  });

  testWidgets('monthly planner', (tester) async {
    if (!regenerate) return;
    await capture(
      tester,
      MonthlyPlannerHarness(language: 'en'),
      name: '04_monthly_planner_en',
      size: const Size(390, 1000),
    );
  });

  testWidgets('monthly planner in Nepali', (tester) async {
    if (!regenerate) return;
    await capture(
      tester,
      MonthlyPlannerHarness(language: 'ne'),
      name: '05_monthly_planner_ne',
      size: const Size(390, 1000),
    );
  });

  testWidgets('grocery list', (tester) async {
    if (!regenerate) return;
    final repo = await tester.runAsync(buildSeededGroceryRepository);
    await capture(
      tester,
      GroceryListHarness(language: 'en', repository: repo!),
      name: '06_grocery_list_en',
      size: const Size(390, 1100),
    );
  });

  testWidgets('grocery list in Nepali', (tester) async {
    if (!regenerate) return;
    final repo = await tester.runAsync(buildSeededGroceryRepository);
    await capture(
      tester,
      GroceryListHarness(language: 'ne', repository: repo!),
      name: '07_grocery_list_ne',
      size: const Size(390, 1100),
    );
  });
}