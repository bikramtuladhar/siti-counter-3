import { test, describe } from 'node:test';
import assert from 'node:assert/strict';
import { KitchenVoiceEngine } from './voice_engine.js';

describe('KitchenVoiceEngine TypeScript Parity Tests', () => {
  test('parses whistle queries in English, Nepali, and Hindi', () => {
    const q1 = KitchenVoiceEngine.parse('How many siti left?');
    assert.strictEqual(q1.intent, 'queryWhistles');
    assert.strictEqual(q1.detectedLanguage, 'en');
    assert.ok(q1.confidence >= 0.9);

    const q2 = KitchenVoiceEngine.parse('कति सिट्ठी बाँकी छ?');
    assert.strictEqual(q2.intent, 'queryWhistles');
    assert.strictEqual(q2.detectedLanguage, 'ne');
    assert.ok(q2.feedbackNe.includes('सिट्ठी सङ्ख्या'));

    const q3 = KitchenVoiceEngine.parse('कितनी सीटी बची हैं?');
    assert.strictEqual(q3.intent, 'queryWhistles');
    assert.strictEqual(q3.detectedLanguage, 'hi');
    assert.ok(q3.feedbackHi.includes('सीटी'));
  });

  test('tolerates noise and conversational fillers', () => {
    const noisy = KitchenVoiceEngine.parse('hey assistant, can you please tell me how many whistles left?');
    assert.strictEqual(noisy.intent, 'queryWhistles');

    const noisyNe = KitchenVoiceEngine.parse('कृपया हजुर, अर्को चरण देखाउनुहोस्');
    assert.strictEqual(noisyNe.intent, 'nextStep');
  });

  test('parses step navigation commands (next, previous, repeat)', () => {
    // Next
    assert.strictEqual(KitchenVoiceEngine.parse('Next step').intent, 'nextStep');
    assert.strictEqual(KitchenVoiceEngine.parse('अर्को चरण').intent, 'nextStep');
    assert.strictEqual(KitchenVoiceEngine.parse('अगला कदम').intent, 'nextStep');

    // Previous
    assert.strictEqual(KitchenVoiceEngine.parse('Previous step').intent, 'previousStep');
    assert.strictEqual(KitchenVoiceEngine.parse('अघिल्लो चरण').intent, 'previousStep');
    assert.strictEqual(KitchenVoiceEngine.parse('पिछला कदम').intent, 'previousStep');

    // Repeat
    assert.strictEqual(KitchenVoiceEngine.parse('Repeat step').intent, 'repeatStep');
    assert.strictEqual(KitchenVoiceEngine.parse('फेरि भन्नुहोस्').intent, 'repeatStep');
    assert.strictEqual(KitchenVoiceEngine.parse('दोहराएं').intent, 'repeatStep');
  });

  test('parses set timer commands with digits, Devanagari numerals, and words', () => {
    const t1 = KitchenVoiceEngine.parse('Set timer for 5 minutes');
    assert.strictEqual(t1.intent, 'setTimer');
    assert.strictEqual(t1.parameters.durationMinutes, 5);

    const t2 = KitchenVoiceEngine.parse('Start timer for ten minutes');
    assert.strictEqual(t2.intent, 'setTimer');
    assert.strictEqual(t2.parameters.durationMinutes, 10);

    const t3 = KitchenVoiceEngine.parse('५ मिनेटको टाइमर राख');
    assert.strictEqual(t3.intent, 'setTimer');
    assert.strictEqual(t3.parameters.durationMinutes, 5);
    assert.strictEqual(t3.detectedLanguage, 'ne');

    const t4 = KitchenVoiceEngine.parse('१० मिनट का टाइमर लगाओ');
    assert.strictEqual(t4.intent, 'setTimer');
    assert.strictEqual(t4.parameters.durationMinutes, 10);
    assert.strictEqual(t4.detectedLanguage, 'hi');
  });

  test('parses pause and resume timer commands', () => {
    assert.strictEqual(KitchenVoiceEngine.parse('Pause timer').intent, 'pauseTimer');
    assert.strictEqual(KitchenVoiceEngine.parse('टाइमर रोक').intent, 'pauseTimer');
    assert.strictEqual(KitchenVoiceEngine.parse('Resume timer').intent, 'resumeTimer');
    assert.strictEqual(KitchenVoiceEngine.parse('टाइमर सुचारु गर').intent, 'resumeTimer');
  });

  test('parses grocery item additions', () => {
    const g1 = KitchenVoiceEngine.parse('Add salt to grocery list');
    assert.strictEqual(g1.intent, 'addGrocery');
    assert.strictEqual(g1.parameters.item, 'salt');

    const g2 = KitchenVoiceEngine.parse('नून बजार सूचीमा थप');
    assert.strictEqual(g2.intent, 'addGrocery');
    assert.strictEqual(g2.parameters.item, 'नून');

    const g3 = KitchenVoiceEngine.parse('हल्दी ग्रोसरी लिस्ट में जोड़ो');
    assert.strictEqual(g3.intent, 'addGrocery');
    assert.strictEqual(g3.parameters.item, 'हल्दी');
  });

  test('parses boiling point altitude queries', () => {
    assert.strictEqual(KitchenVoiceEngine.parse('What is the boiling point?').intent, 'queryBoilingPoint');
    assert.strictEqual(KitchenVoiceEngine.parse('उम्लने तापक्रम कति हो?').intent, 'queryBoilingPoint');
  });

  test('returns unknown intent for random or empty utterances', () => {
    assert.strictEqual(KitchenVoiceEngine.parse('play jazz music').intent, 'unknown');
    assert.strictEqual(KitchenVoiceEngine.parse('   ').intent, 'unknown');
  });
});
