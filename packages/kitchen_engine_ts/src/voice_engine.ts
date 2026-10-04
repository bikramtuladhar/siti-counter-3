/**
 * Recognizable kitchen voice intents for hands-free cooking (Section 13.3, 16.1).
 */
export type KitchenVoiceIntent =
  | 'queryWhistles'
  | 'nextStep'
  | 'previousStep'
  | 'repeatStep'
  | 'setTimer'
  | 'pauseTimer'
  | 'resumeTimer'
  | 'addGrocery'
  | 'queryBoilingPoint'
  | 'unknown';

export interface KitchenVoiceCommand {
  intent: KitchenVoiceIntent;
  confidence: number;
  rawUtterance: string;
  detectedLanguage: 'en' | 'ne' | 'hi';
  parameters: Record<string, unknown>;
  feedbackEn: string;
  feedbackNe: string;
  feedbackHi: string;
}

/**
 * Offline-first multilingual deterministic voice command parser.
 * Designed for noisy kitchen cooktops and low-literacy users (Section 13.3 & 16.1).
 */
export class KitchenVoiceEngine {
  static parse(utterance: string, options?: { defaultLanguage?: 'en' | 'ne' | 'hi' }): KitchenVoiceCommand {
    const clean = this.normalize(utterance);
    if (!clean) {
      return {
        intent: 'unknown',
        confidence: 0.0,
        rawUtterance: '',
        detectedLanguage: 'en',
        parameters: {},
        feedbackEn: 'I did not catch that. Please try again.',
        feedbackNe: 'मैले बुझिनँ। कृपया फेरि भन्नुहोस्।',
        feedbackHi: 'मैं समझ नहीं पाया। कृपया फिर से कहें।',
      };
    }

    const detectedLang = this.detectLanguage(clean, options?.defaultLanguage ?? 'en');

    // 1. Whistle Queries
    if (this.isWhistleQuery(clean)) {
      return {
        intent: 'queryWhistles',
        confidence: 0.95,
        rawUtterance: utterance,
        detectedLanguage: detectedLang,
        parameters: {},
        feedbackEn: 'Checking whistle count...',
        feedbackNe: 'सिट्ठी सङ्ख्या जाँच गर्दै...',
        feedbackHi: 'सीटी की संख्या जाँची जा रही है...',
      };
    }

    // 2. Next Step
    if (this.isNextStep(clean)) {
      return {
        intent: 'nextStep',
        confidence: 0.95,
        rawUtterance: utterance,
        detectedLanguage: detectedLang,
        parameters: {},
        feedbackEn: 'Advancing to next step.',
        feedbackNe: 'अर्को चरणमा जाँदै।',
        feedbackHi: 'अगले कदम पर जा रहे हैं।',
      };
    }

    // 3. Previous Step
    if (this.isPreviousStep(clean)) {
      return {
        intent: 'previousStep',
        confidence: 0.95,
        rawUtterance: utterance,
        detectedLanguage: detectedLang,
        parameters: {},
        feedbackEn: 'Going back to previous step.',
        feedbackNe: 'अघिल्लो चरणमा फर्किँदै।',
        feedbackHi: 'पिछले कदम पर वापस जा रहे हैं।',
      };
    }

    // 4. Repeat Step
    if (this.isRepeatStep(clean)) {
      return {
        intent: 'repeatStep',
        confidence: 0.95,
        rawUtterance: utterance,
        detectedLanguage: detectedLang,
        parameters: {},
        feedbackEn: 'Repeating current step.',
        feedbackNe: 'हालको चरण फेरि भन्दै।',
        feedbackHi: 'वर्तमान कदम दोहरा रहे हैं।',
      };
    }

    // 5. Timer Commands (Set / Pause / Resume)
    if (this.isPauseTimer(clean)) {
      return {
        intent: 'pauseTimer',
        confidence: 0.95,
        rawUtterance: utterance,
        detectedLanguage: detectedLang,
        parameters: {},
        feedbackEn: 'Timer paused.',
        feedbackNe: 'टाइमर रोकियो।',
        feedbackHi: 'टाइमर रोक दिया गया।',
      };
    }

    if (this.isResumeTimer(clean)) {
      return {
        intent: 'resumeTimer',
        confidence: 0.95,
        rawUtterance: utterance,
        detectedLanguage: detectedLang,
        parameters: {},
        feedbackEn: 'Timer resumed.',
        feedbackNe: 'टाइमर सुचारु गरियो।',
        feedbackHi: 'टाइमर फिर से शुरू किया गया।',
      };
    }

    const timerMinutes = this.extractTimerMinutes(clean);
    if (timerMinutes !== null && timerMinutes > 0) {
      return {
        intent: 'setTimer',
        confidence: 0.95,
        rawUtterance: utterance,
        detectedLanguage: detectedLang,
        parameters: { durationMinutes: timerMinutes },
        feedbackEn: `Timer set for ${timerMinutes} minute${timerMinutes === 1 ? '' : 's'}.`,
        feedbackNe: `${timerMinutes} मिनेटको टाइमर सुरु गरियो।`,
        feedbackHi: `${timerMinutes} मिनट का टाइमर लगाया गया।`,
      };
    }

    // 6. Grocery Item Addition
    const groceryItem = this.extractGroceryItem(clean);
    if (groceryItem) {
      return {
        intent: 'addGrocery',
        confidence: 0.9,
        rawUtterance: utterance,
        detectedLanguage: detectedLang,
        parameters: { item: groceryItem },
        feedbackEn: `Added "${groceryItem}" to grocery list.`,
        feedbackNe: `बजार सूचीमा "${groceryItem}" थपियो।`,
        feedbackHi: `ग्रोसरी लिस्ट में "${groceryItem}" जोड़ा गया।`,
      };
    }

    // 7. Boiling point altitude query
    if (this.isBoilingPointQuery(clean)) {
      return {
        intent: 'queryBoilingPoint',
        confidence: 0.95,
        rawUtterance: utterance,
        detectedLanguage: detectedLang,
        parameters: {},
        feedbackEn: 'Checking altitude boiling point...',
        feedbackNe: 'उम्लने तापक्रम जाँच गर्दै...',
        feedbackHi: 'क्वथनांक तापमान जाँचा जा रहा है...',
      };
    }

    return {
      intent: 'unknown',
      confidence: 0.2,
      rawUtterance: utterance,
      detectedLanguage: detectedLang,
      parameters: {},
      feedbackEn: 'Command not recognized. Say "next step", "how many siti", or "set timer".',
      feedbackNe: 'आदेश बुझिएन। "अर्को चरण", "कति सिट्ठी", वा "टाइमर राख" भन्नुहोस्।',
      feedbackHi: 'आदेश समझ नहीं आया। "अगला कदम", "कितनी सीटी", या "टाइमर लगाओ" कहें।',
    };
  }

  private static normalize(input: string): string {
    return input
      .toLowerCase()
      .replace(/[^\w\s\u0900-\u097F]/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();
  }

  private static detectLanguage(text: string, fallback: 'en' | 'ne' | 'hi'): 'en' | 'ne' | 'hi' {
    if (/[\u0900-\u097F]/.test(text)) {
      if (
        text.includes('सिट्ठी') ||
        text.includes('सिट्टी') ||
        text.includes('बाँकी') ||
        text.includes('बाकी') ||
        text.includes('अर्को') ||
        text.includes('अघिल्लो') ||
        text.includes('राख') ||
        text.includes('थप') ||
        text.includes('मिनेट') ||
        text.includes('पकाउनु')
      ) {
        return 'ne';
      }
      if (
        text.includes('सीटी') ||
        text.includes('कदम') ||
        text.includes('जोड़ो') ||
        text.includes('लगाओ') ||
        text.includes('मिनट') ||
        text.includes('रोको')
      ) {
        return 'hi';
      }
      return 'ne';
    }
    return fallback;
  }

  private static isWhistleQuery(text: string): boolean {
    const enPatterns = [
      'how many siti',
      'how many whistles',
      'whistle count',
      'siti count',
      'how many whistle left',
      'how many siti left',
      'siti left',
      'whistles left',
      'siti status',
      'whistle status',
    ];
    for (const p of enPatterns) {
      if (text.includes(p)) return true;
    }

    const nePatterns = [
      'कति सिट्ठी',
      'कति सिट्टी',
      'सिट्ठी कति',
      'सिट्टी कति',
      'सिट्ठी बाँकी',
      'सिट्ठी बाकी',
      'सिट्टी बाँकी',
      'सिट्टी बाकी',
      'कति बाकी छ',
      'कति बाँकी छ',
      'सिट्ठी भयो',
    ];
    for (const p of nePatterns) {
      if (text.includes(p)) return true;
    }

    const hiPatterns = [
      'कितनी सीटी',
      'सीटी कितनी',
      'कितनी सीटी बची',
      'सीटी बची है',
      'सीटी स्टेटस',
    ];
    for (const p of hiPatterns) {
      if (text.includes(p)) return true;
    }

    return false;
  }

  private static isNextStep(text: string): boolean {
    const en = ['next step', 'go next', 'advance step', 'step forward'];
    for (const p of en) {
      if (text.includes(p)) return true;
    }
    if (text === 'next' || text === 'next please') return true;

    const ne = ['अर्को चरण', 'अर्को स्टेप', 'अगाडि बढ्नुहोस्', 'अगाडिको चरण', 'अर्को'];
    for (const p of ne) {
      if (text.includes(p)) return true;
    }

    const hi = ['अगला कदम', 'अगला स्टेप', 'आगे बढ़ो', 'अगला'];
    for (const p of hi) {
      if (text.includes(p)) return true;
    }

    return false;
  }

  private static isPreviousStep(text: string): boolean {
    const en = ['previous step', 'prev step', 'go back', 'step back', 'last step'];
    for (const p of en) {
      if (text.includes(p)) return true;
    }
    if (text === 'previous' || text === 'back') return true;

    const ne = ['अघिल्लो चरण', 'अघिल्लो स्टेप', 'पछाडि जानुहोस्', 'पछाडिको चरण', 'पछाडि', 'अघिल्लो'];
    for (const p of ne) {
      if (text.includes(p)) return true;
    }

    const hi = ['पिछला कदम', 'पिछला स्टेप', 'पीछे जाओ', 'पिछला'];
    for (const p of hi) {
      if (text.includes(p)) return true;
    }

    return false;
  }

  private static isRepeatStep(text: string): boolean {
    const en = ['repeat step', 'repeat', 'say again', 'read again', 'what was that'];
    for (const p of en) {
      if (text.includes(p)) return true;
    }

    const ne = ['फेरि भन्नुहोस्', 'फेरि पढ्नुहोस्', 'दोहोर्याउनुहोस्', 'दोहोराउ', 'फेरि'];
    for (const p of ne) {
      if (text.includes(p)) return true;
    }

    const hi = ['दोहराएं', 'दोहराओ', 'फिर से बोलो', 'फिर से पढ़ो', 'रिपीट'];
    for (const p of hi) {
      if (text.includes(p)) return true;
    }

    return false;
  }

  private static isPauseTimer(text: string): boolean {
    return (
      text.includes('pause timer') ||
      text.includes('stop timer') ||
      text.includes('halt timer') ||
      text.includes('टाइमर रोक') ||
      text.includes('रोक्नुहोस्') ||
      text.includes('टाइमर पज') ||
      text.includes('टाइमर रोको') ||
      text.includes('रुकिए')
    );
  }

  private static isResumeTimer(text: string): boolean {
    return (
      text.includes('resume timer') ||
      text.includes('continue timer') ||
      text.includes('unpause timer') ||
      text.includes('टाइमर सुचारु') ||
      text.includes('सुचारु गर्नुहोस्') ||
      text.includes('टाइमर चालू') ||
      text.includes('कंटिन्यू')
    );
  }

  private static extractTimerMinutes(text: string): number | null {
    if (
      !text.includes('timer') &&
      !text.includes('टाइमर') &&
      !text.includes('मिनेट') &&
      !text.includes('मिनट')
    ) {
      return null;
    }

    // 1. Digits
    const digitMatch = /(\d+)\s*(?:min|minute|minutes|मिनेट|मिनट)/.exec(text);
    if (digitMatch) {
      return parseInt(digitMatch[1], 10);
    }

    // 2. Devanagari numerals
    const devMatch = /([०-९]+)\s*(?:मिनेट|मिनट)/.exec(text);
    if (devMatch) {
      const western = this.devanagariDigitsToWestern(devMatch[1]);
      return parseInt(western, 10);
    }

    // 3. Word numbers
    const wordMap: Record<string, number> = {
      one: 1, two: 2, three: 3, four: 4, five: 5,
      six: 6, seven: 7, eight: 8, nine: 9, ten: 10,
      fifteen: 15, twenty: 20, thirty: 30,
      एक: 1, दुई: 2, तीन: 3, चार: 4, पाँच: 5, पाच: 5,
      छ: 6, सात: 7, आठ: 8, नौ: 9, दस: 10,
      पन्ध्र: 15, बीस: 20, तीस: 30,
      दो: 2, पांच: 5, छह: 6, पंद्रह: 15,
    };

    for (const [word, val] of Object.entries(wordMap)) {
      if (
        text.includes(word) &&
        (text.includes('minute') ||
          text.includes('min') ||
          text.includes('मिनेट') ||
          text.includes('मिनट') ||
          text.includes('timer') ||
          text.includes('टाइमर'))
      ) {
        return val;
      }
    }

    return null;
  }

  private static extractGroceryItem(text: string): string | null {
    const enMatch = /add\s+(.+?)\s+to\s+(?:the\s+)?(?:grocery|shopping|market)?\s*list/i.exec(text);
    if (enMatch) return enMatch[1].trim();

    if (text.startsWith('buy ')) return text.substring(4).trim();

    const neMatch = /(.+?)\s+(?:बजार\s+)?(?:सूचीमा|लिस्टमा)\s+(?:थप|राख|जोड)/i.exec(text);
    if (neMatch) return neMatch[1].trim();

    const hiMatch = /(.+?)\s+(?:ग्रोसरी\s+)?लिस्ट\s+में\s+(?:जोड़ो|डालो|रखो)/i.exec(text);
    if (hiMatch) return hiMatch[1].trim();

    return null;
  }

  private static isBoilingPointQuery(text: string): boolean {
    return (
      text.includes('boiling point') ||
      text.includes('boiling temperature') ||
      text.includes('उम्लने तापक्रम') ||
      text.includes('उमाल्ने बिन्दु') ||
      text.includes('क्वथनांक')
    );
  }

  private static devanagariDigitsToWestern(devanagari: string): string {
    const devMap: Record<string, string> = {
      '०': '0', '१': '1', '२': '2', '३': '3', '४': '4',
      '५': '5', '६': '6', '७': '7', '८': '8', '९': '9',
    };
    let result = devanagari;
    for (const [k, v] of Object.entries(devMap)) {
      result = result.replaceAll(k, v);
    }
    return result;
  }
}
