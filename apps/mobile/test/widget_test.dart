import 'package:flutter_test/flutter_test.dart';
import 'package:siti_counter/main.dart';
import 'package:siti_counter/onboarding/welcome_tour_screen.dart';

void main() {
  testWidgets('App launches and renders WelcomeTourScreen', (tester) async {
    await tester.pumpWidget(const SitiCounterApp());
    await tester.pumpAndSettle();

    expect(find.byType(WelcomeTourScreen), findsOneWidget);
    expect(find.text('Siti Counter 3.0'), findsOneWidget);
  });
}
