import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchen_engine/nepali_calendar.dart';
import 'package:siti_counter/widgets/six_ritus_indicator.dart';

void main() {
  testWidgets('SixRitusIndicator renders current Nepali date and selects ritu', (tester) async {
    const testBsDate = BsDate(year: 2081, month: 7, day: 10); // Kartik -> Sharad
    RituName? selectedRitu;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SixRitusIndicator(
            currentDate: testBsDate,
            preferNepali: true,
            onRituSelected: (r) => selectedRitu = r,
          ),
        ),
      ),
    );

    // Should display Nepali date "२०८१ कात्तिक १०"
    expect(find.text('२०८१ कात्तिक १०'), findsOneWidget);
    // Should display active ritu name "शरद"
    expect(find.text('शरद'), findsWidgets);

    // Tap on Basanta pill (बसन्त)
    await tester.tap(find.text('बसन्त'));
    await tester.pumpAndSettle();

    expect(selectedRitu, equals(RituName.basanta));
  });

  testWidgets('SixRitusIndicator renders English mode properly', (tester) async {
    const testBsDate = BsDate(year: 2081, month: 1, day: 1); // Baisakh -> Basanta

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SixRitusIndicator(
            currentDate: testBsDate,
            preferNepali: false,
          ),
        ),
      ),
    );

    expect(find.text('Baisakh 1, 2081 BS'), findsOneWidget);
    expect(find.text("Today's Date"), findsOneWidget);
    expect(find.text('Basanta (Spring)'), findsOneWidget);
  });
}
