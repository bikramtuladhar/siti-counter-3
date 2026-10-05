import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siti_counter/compliance/legal_compliance_screen.dart';

void main() {
  group('LegalComplianceScreen Widget Tests', () {
    testWidgets('renders Privacy tab with Nepal Privacy Act 2075 & GDPR guarantees', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LegalComplianceScreen(language: 'en'),
        ),
      );

      // Verify header and tab labels
      expect(find.text('Privacy & Compliance'), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('Terms of Service'), findsOneWidget);
      expect(find.text('Audits & Rights'), findsOneWidget);

      // Verify privacy guarantees
      expect(find.text('100% On-Device Audio Privacy'), findsOneWidget);
      expect(find.text('Nepal Individual Privacy Act 2075'), findsOneWidget);
      expect(find.text('EU General Data Protection Regulation (GDPR)'), findsOneWidget);
      expect(find.text('Pediatric Nutrition Protection'), findsOneWidget);
    });

    testWidgets('switches to Terms tab and displays safety disclaimers', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LegalComplianceScreen(language: 'en'),
        ),
      );

      // Tap on Terms of Service tab
      await tester.tap(find.text('Terms of Service'));
      await tester.pumpAndSettle();

      expect(find.text('Health & Cooking Safety Disclaimer'), findsOneWidget);
      expect(find.text('Physical Pressure Cooker Supervision'), findsOneWidget);
      expect(find.text('Zero Advertising Rank Bias'), findsOneWidget);
    });

    testWidgets('switches to Audits & Rights tab and triggers data export and erase confirmation', (tester) async {
      bool exportCalled = false;
      bool eraseCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: LegalComplianceScreen(
            language: 'en',
            onExportData: () => exportCalled = true,
            onEraseData: () => eraseCalled = true,
          ),
        ),
      );

      // Tap on Audits & Rights tab
      await tester.tap(find.text('Audits & Rights'));
      await tester.pumpAndSettle();

      expect(find.text('Your Data Sovereignty'), findsOneWidget);
      expect(find.text('Open Beta Gate Audit (Week 24)'), findsOneWidget);

      // Tap export data button
      await tester.tap(find.text('Export All Household Data (JSON)'));
      await tester.pump();
      expect(exportCalled, isTrue);

      // Tap erase data button to open confirmation dialog
      await tester.tap(find.text('Erase All Household Data'));
      await tester.pumpAndSettle();

      expect(find.text('Erase All Data?'), findsOneWidget);
      expect(find.text('Erase Everything'), findsOneWidget);

      // Confirm erase in dialog
      await tester.tap(find.text('Erase Everything'));
      await tester.pumpAndSettle();
      expect(eraseCalled, isTrue);
    });

    testWidgets('toggles language between English and Nepali', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LegalComplianceScreen(language: 'en'),
        ),
      );

      expect(find.text('Privacy & Compliance'), findsOneWidget);

      // Tap translation toggle
      await tester.tap(find.byIcon(Icons.translate));
      await tester.pumpAndSettle();

      // Check Nepali text
      expect(find.text('गोपनीयता र सर्तहरू'), findsOneWidget);
      expect(find.text('गोपनीयता नीति'), findsOneWidget);
      expect(find.text('१००% अन-डिभाइस अडियो सुरक्षा'), findsOneWidget);
    });
  });
}
