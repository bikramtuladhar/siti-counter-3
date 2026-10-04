import 'package:kitchen_engine/kitchen_engine.dart';
import 'package:test/test.dart';

void main() {
  group('KitchenVoiceEngine Unit Tests', () {
    test('parses whistle queries in English, Nepali, and Hindi', () {
      final q1 = KitchenVoiceEngine.parse('How many siti left?');
      expect(q1.intent, equals(KitchenVoiceIntent.queryWhistles));
      expect(q1.detectedLanguage, equals('en'));
      expect(q1.confidence, greaterThanOrEqualTo(0.9));

      final q2 = KitchenVoiceEngine.parse('कति सिट्ठी बाँकी छ?');
      expect(q2.intent, equals(KitchenVoiceIntent.queryWhistles));
      expect(q2.detectedLanguage, equals('ne'));
      expect(q2.feedbackNe, contains('सिट्ठी सङ्ख्या'));

      final q3 = KitchenVoiceEngine.parse('कितनी सीटी बची हैं?');
      expect(q3.intent, equals(KitchenVoiceIntent.queryWhistles));
      expect(q3.detectedLanguage, equals('hi'));
      expect(q3.feedbackHi, contains('सीटी'));
    });

    test('tolerates noise and conversational fillers', () {
      final noisy = KitchenVoiceEngine.parse('hey assistant, can you please tell me how many whistles left?');
      expect(noisy.intent, equals(KitchenVoiceIntent.queryWhistles));

      final noisyNe = KitchenVoiceEngine.parse('कृपया हजुर, अर्को चरण देखाउनुहोस्');
      expect(noisyNe.intent, equals(KitchenVoiceIntent.nextStep));
    });

    test('parses step navigation commands (next, previous, repeat)', () {
      // Next step
      expect(KitchenVoiceEngine.parse('Next step').intent, equals(KitchenVoiceIntent.nextStep));
      expect(KitchenVoiceEngine.parse('अर्को चरण').intent, equals(KitchenVoiceIntent.nextStep));
      expect(KitchenVoiceEngine.parse('अगला कदम').intent, equals(KitchenVoiceIntent.nextStep));

      // Previous step
      expect(KitchenVoiceEngine.parse('Previous step').intent, equals(KitchenVoiceIntent.previousStep));
      expect(KitchenVoiceEngine.parse('अघिल्लो चरण').intent, equals(KitchenVoiceIntent.previousStep));
      expect(KitchenVoiceEngine.parse('पिछला कदम').intent, equals(KitchenVoiceIntent.previousStep));

      // Repeat step
      expect(KitchenVoiceEngine.parse('Repeat step').intent, equals(KitchenVoiceIntent.repeatStep));
      expect(KitchenVoiceEngine.parse('फेरि भन्नुहोस्').intent, equals(KitchenVoiceIntent.repeatStep));
      expect(KitchenVoiceEngine.parse('दोहराएं').intent, equals(KitchenVoiceIntent.repeatStep));
    });

    test('parses set timer commands and extracts durations in digits & words', () {
      // English with digits
      final t1 = KitchenVoiceEngine.parse('Set timer for 5 minutes');
      expect(t1.intent, equals(KitchenVoiceIntent.setTimer));
      expect(t1.timerMinutes, equals(5));
      expect(t1.feedbackEn, contains('5 minutes'));

      // English with words
      final t2 = KitchenVoiceEngine.parse('Start timer for ten minutes');
      expect(t2.intent, equals(KitchenVoiceIntent.setTimer));
      expect(t2.timerMinutes, equals(10));

      // Nepali with Devanagari numerals
      final t3 = KitchenVoiceEngine.parse('५ मिनेटको टाइमर राख');
      expect(t3.intent, equals(KitchenVoiceIntent.setTimer));
      expect(t3.timerMinutes, equals(5));
      expect(t3.detectedLanguage, equals('ne'));

      // Nepali with word numerals
      final t4 = KitchenVoiceEngine.parse('दुई मिनेट टाइमर सुरु गर');
      expect(t4.intent, equals(KitchenVoiceIntent.setTimer));
      expect(t4.timerMinutes, equals(2));

      // Hindi
      final t5 = KitchenVoiceEngine.parse('१० मिनट का टाइमर लगाओ');
      expect(t5.intent, equals(KitchenVoiceIntent.setTimer));
      expect(t5.timerMinutes, equals(10));
      expect(t5.detectedLanguage, equals('hi'));
    });

    test('parses pause and resume timer commands', () {
      final p1 = KitchenVoiceEngine.parse('Pause timer');
      expect(p1.intent, equals(KitchenVoiceIntent.pauseTimer));

      final p2 = KitchenVoiceEngine.parse('टाइमर रोक');
      expect(p2.intent, equals(KitchenVoiceIntent.pauseTimer));

      final r1 = KitchenVoiceEngine.parse('Resume timer');
      expect(r1.intent, equals(KitchenVoiceIntent.resumeTimer));

      final r2 = KitchenVoiceEngine.parse('टाइमर सुचारु गर');
      expect(r2.intent, equals(KitchenVoiceIntent.resumeTimer));
    });

    test('parses grocery item additions', () {
      // English
      final g1 = KitchenVoiceEngine.parse('Add salt to grocery list');
      expect(g1.intent, equals(KitchenVoiceIntent.addGrocery));
      expect(g1.groceryItem, equals('salt'));
      expect(g1.feedbackEn, contains('salt'));

      // Nepali
      final g2 = KitchenVoiceEngine.parse('नून बजार सूचीमा थप');
      expect(g2.intent, equals(KitchenVoiceIntent.addGrocery));
      expect(g2.groceryItem, equals('नून'));
      expect(g2.feedbackNe, contains('नून'));

      // Hindi
      final g3 = KitchenVoiceEngine.parse('हल्दी ग्रोसरी लिस्ट में जोड़ो');
      expect(g3.intent, equals(KitchenVoiceIntent.addGrocery));
      expect(g3.groceryItem, equals('हल्दी'));
    });

    test('parses boiling point altitude queries', () {
      final bp = KitchenVoiceEngine.parse('What is the boiling point?');
      expect(bp.intent, equals(KitchenVoiceIntent.queryBoilingPoint));

      final bpNe = KitchenVoiceEngine.parse('उम्लने तापक्रम कति हो?');
      expect(bpNe.intent, equals(KitchenVoiceIntent.queryBoilingPoint));
    });

    test('returns unknown intent for random or empty utterances', () {
      final unk = KitchenVoiceEngine.parse('play some music');
      expect(unk.intent, equals(KitchenVoiceIntent.unknown));

      final empty = KitchenVoiceEngine.parse('   ');
      expect(empty.intent, equals(KitchenVoiceIntent.unknown));
    });

    test('serializes and deserializes KitchenVoiceCommand JSON', () {
      final cmd = KitchenVoiceEngine.parse('Set timer for 15 minutes');
      final json = cmd.toJson();
      final restored = KitchenVoiceCommand.fromJson(json);

      expect(restored.intent, equals(cmd.intent));
      expect(restored.timerMinutes, equals(15));
      expect(restored.rawUtterance, equals(cmd.rawUtterance));
      expect(restored.detectedLanguage, equals(cmd.detectedLanguage));
    });
  });
}
