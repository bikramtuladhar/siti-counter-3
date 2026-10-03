import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siti_counter/widgets/microphone_privacy_primer_dialog.dart';

void main() {
  group('MicrophonePrivacyPrimerDialog', () {
    testWidgets('renders Nepali privacy assurances and handles allow decision',
        (tester) async {
      MicrophonePrimerDecision? decision;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  decision = await MicrophonePrivacyPrimerDialog.show(
                    context,
                    language: 'ne',
                  );
                },
                child: const Text('Open Primer'),
              ),
            ),
          ),
        ),
      );

      // Open bottom sheet
      await tester.tap(find.text('Open Primer'));
      await tester.pumpAndSettle();

      // Verify privacy guarantees in Nepali
      expect(find.text('गोपनीयता र माइक अनुमति'), findsOneWidget);
      expect(find.text('१००% अन-डिभाइस सिट्ठी पहिचान'), findsOneWidget);
      expect(
        find.textContaining('तपाईंको आवाज कहिल्यै फोन बाहिर जाँदैन'),
        findsOneWidget,
      );
      expect(find.text('कुनै अडियो रेकर्ड हुँदैन'), findsOneWidget);

      // Tap allow button
      await tester.tap(find.byKey(const Key('primer_allow_button')));
      await tester.pumpAndSettle();

      expect(decision, equals(MicrophonePrimerDecision.allowAcoustic));
    });

    testWidgets('renders English privacy assurances and handles manual decision',
        (tester) async {
      MicrophonePrimerDecision? decision;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  decision = await MicrophonePrivacyPrimerDialog.show(
                    context,
                    language: 'en',
                  );
                },
                child: const Text('Open Primer'),
              ),
            ),
          ),
        ),
      );

      // Open bottom sheet
      await tester.tap(find.text('Open Primer'));
      await tester.pumpAndSettle();

      // Verify privacy guarantees in English
      expect(find.text('Microphone & Privacy'), findsOneWidget);
      expect(
        find.textContaining('Your audio never leaves your phone'),
        findsOneWidget,
      );
      expect(find.text('No Recording Stored'), findsOneWidget);
      expect(find.text('Low Battery Usage'), findsOneWidget);

      // Tap manual tap button
      await tester.tap(find.byKey(const Key('primer_manual_button')));
      await tester.pumpAndSettle();

      expect(decision, equals(MicrophonePrimerDecision.manualOnly));
    });
  });
}
