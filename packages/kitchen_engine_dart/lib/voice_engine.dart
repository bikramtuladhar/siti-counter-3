library;

/// Recognizable kitchen voice intents for hands-free cooking (Section 13.3, 16.1).
enum KitchenVoiceIntent {
  /// Check whistle count / remaining whistles (e.g. "How many siti left?")
  queryWhistles,

  /// Advance to the next cooking step
  nextStep,

  /// Return to the previous cooking step
  previousStep,

  /// Read / repeat the current cooking step
  repeatStep,

  /// Start or set a countdown timer with duration
  setTimer,

  /// Pause active timer or cooking session
  pauseTimer,

  /// Resume paused timer or cooking session
  resumeTimer,

  /// Add ingredient or item to grocery / market list
  addGrocery,

  /// Query local boiling point / altitude cooking advisory
  queryBoilingPoint,

  /// Unrecognized utterance
  unknown,
}

/// Extracted voice command result with detected intent, parameters, and multilingual feedback.
class KitchenVoiceCommand {
  final KitchenVoiceIntent intent;
  final double confidence;
  final String rawUtterance;
  final String detectedLanguage; // 'en', 'ne', or 'hi'
  final Map<String, dynamic> parameters;
  final String feedbackEn;
  final String feedbackNe;
  final String feedbackHi;

  const KitchenVoiceCommand({
    required this.intent,
    required this.confidence,
    required this.rawUtterance,
    required this.detectedLanguage,
    this.parameters = const {},
    required this.feedbackEn,
    required this.feedbackNe,
    required this.feedbackHi,
  });

  /// Helper getter for duration if intent == setTimer
  int? get timerMinutes => parameters['durationMinutes'] as int?;

  /// Helper getter for grocery item if intent == addGrocery
  String? get groceryItem => parameters['item'] as String?;

  Map<String, dynamic> toJson() => {
        'intent': intent.name,
        'confidence': confidence,
        'rawUtterance': rawUtterance,
        'detectedLanguage': detectedLanguage,
        'parameters': parameters,
        'feedbackEn': feedbackEn,
        'feedbackNe': feedbackNe,
        'feedbackHi': feedbackHi,
      };

  factory KitchenVoiceCommand.fromJson(Map<String, dynamic> json) =>
      KitchenVoiceCommand(
        intent: KitchenVoiceIntent.values.firstWhere(
          (i) => i.name == json['intent'],
          orElse: () => KitchenVoiceIntent.unknown,
        ),
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
        rawUtterance: json['rawUtterance'] as String? ?? '',
        detectedLanguage: json['detectedLanguage'] as String? ?? 'en',
        parameters: Map<String, dynamic>.from(json['parameters'] as Map? ?? {}),
        feedbackEn: json['feedbackEn'] as String? ?? '',
        feedbackNe: json['feedbackNe'] as String? ?? '',
        feedbackHi: json['feedbackHi'] as String? ?? '',
      );
}

/// Offline-first multilingual deterministic voice command parser.
///
/// Designed for noisy kitchen cooktops and low-literacy users (Section 13.3 & 16.1):
/// - Immune to background kitchen noise and conversational filler words.
/// - Operates 100% on-device with zero network latency.
/// - Understands Nepali (नेपाली), Hindi (हिंदी), and English.
class KitchenVoiceEngine {
  /// Parses an utterance into a structured `KitchenVoiceCommand`.
  static KitchenVoiceCommand parse(
    String utterance, {
    String? defaultLanguage,
  }) {
    final clean = _normalize(utterance);
    if (clean.isEmpty) {
      return const KitchenVoiceCommand(
        intent: KitchenVoiceIntent.unknown,
        confidence: 0.0,
        rawUtterance: '',
        detectedLanguage: 'en',
        feedbackEn: 'I did not catch that. Please try again.',
        feedbackNe: 'मैले बुझिनँ। कृपया फेरि भन्नुहोस्।',
        feedbackHi: 'मैं समझ नहीं पाया। कृपया फिर से कहें।',
      );
    }

    final detectedLang = _detectLanguage(clean, fallback: defaultLanguage ?? 'en');

    // 1. Whistle Queries
    if (_isWhistleQuery(clean)) {
      return KitchenVoiceCommand(
        intent: KitchenVoiceIntent.queryWhistles,
        confidence: 0.95,
        rawUtterance: utterance,
        detectedLanguage: detectedLang,
        feedbackEn: 'Checking whistle count...',
        feedbackNe: 'सिट्ठी सङ्ख्या जाँच गर्दै...',
        feedbackHi: 'सीटी की संख्या जाँची जा रही है...',
      );
    }

    // 2. Next Step
    if (_isNextStep(clean)) {
      return KitchenVoiceCommand(
        intent: KitchenVoiceIntent.nextStep,
        confidence: 0.95,
        rawUtterance: utterance,
        detectedLanguage: detectedLang,
        feedbackEn: 'Advancing to next step.',
        feedbackNe: 'अर्को चरणमा जाँदै।',
        feedbackHi: 'अगले कदम पर जा रहे हैं।',
      );
    }

    // 3. Previous Step
    if (_isPreviousStep(clean)) {
      return KitchenVoiceCommand(
        intent: KitchenVoiceIntent.previousStep,
        confidence: 0.95,
        rawUtterance: utterance,
        detectedLanguage: detectedLang,
        feedbackEn: 'Going back to previous step.',
        feedbackNe: 'अघिल्लो चरणमा फर्किँदै।',
        feedbackHi: 'पिछले कदम पर वापस जा रहे हैं।',
      );
    }

    // 4. Repeat Step
    if (_isRepeatStep(clean)) {
      return KitchenVoiceCommand(
        intent: KitchenVoiceIntent.repeatStep,
        confidence: 0.95,
        rawUtterance: utterance,
        detectedLanguage: detectedLang,
        feedbackEn: 'Repeating current step.',
        feedbackNe: 'हालको चरण फेरि भन्दै।',
        feedbackHi: 'वर्तमान कदम दोहरा रहे हैं।',
      );
    }

    // 5. Timer Commands (Set / Pause / Resume)
    if (_isPauseTimer(clean)) {
      return KitchenVoiceCommand(
        intent: KitchenVoiceIntent.pauseTimer,
        confidence: 0.95,
        rawUtterance: utterance,
        detectedLanguage: detectedLang,
        feedbackEn: 'Timer paused.',
        feedbackNe: 'टाइमर रोकियो।',
        feedbackHi: 'टाइमर रोक दिया गया।',
      );
    }

    if (_isResumeTimer(clean)) {
      return KitchenVoiceCommand(
        intent: KitchenVoiceIntent.resumeTimer,
        confidence: 0.95,
        rawUtterance: utterance,
        detectedLanguage: detectedLang,
        feedbackEn: 'Timer resumed.',
        feedbackNe: 'टाइमर सुचारु गरियो।',
        feedbackHi: 'टाइमर फिर से शुरू किया गया।',
      );
    }

    final timerMinutes = _extractTimerMinutes(clean);
    if (timerMinutes != null && timerMinutes > 0) {
      return KitchenVoiceCommand(
        intent: KitchenVoiceIntent.setTimer,
        confidence: 0.95,
        rawUtterance: utterance,
        detectedLanguage: detectedLang,
        parameters: {'durationMinutes': timerMinutes},
        feedbackEn: 'Timer set for $timerMinutes minute${timerMinutes == 1 ? '' : 's'}.',
        feedbackNe: '$timerMinutes मिनेटको टाइमर सुरु गरियो।',
        feedbackHi: '$timerMinutes मिनट का टाइमर लगाया गया।',
      );
    }

    // 6. Grocery Addition
    final groceryItem = _extractGroceryItem(clean);
    if (groceryItem != null && groceryItem.isNotEmpty) {
      return KitchenVoiceCommand(
        intent: KitchenVoiceIntent.addGrocery,
        confidence: 0.90,
        rawUtterance: utterance,
        detectedLanguage: detectedLang,
        parameters: {'item': groceryItem},
        feedbackEn: 'Added "$groceryItem" to grocery list.',
        feedbackNe: 'बजार सूचीमा "$groceryItem" थपियो।',
        feedbackHi: 'ग्रोसरी लिस्ट में "$groceryItem" जोड़ा गया।',
      );
    }

    // 7. Boiling point query
    if (_isBoilingPointQuery(clean)) {
      return KitchenVoiceCommand(
        intent: KitchenVoiceIntent.queryBoilingPoint,
        confidence: 0.95,
        rawUtterance: utterance,
        detectedLanguage: detectedLang,
        feedbackEn: 'Checking altitude boiling point...',
        feedbackNe: 'उम्लने तापक्रम जाँच गर्दै...',
        feedbackHi: 'क्वथनांक तापमान जाँचा जा रहा है...',
      );
    }

    // Unmatched fallback
    return KitchenVoiceCommand(
      intent: KitchenVoiceIntent.unknown,
      confidence: 0.2,
      rawUtterance: utterance,
      detectedLanguage: detectedLang,
      feedbackEn: 'Command not recognized. Say "next step", "how many siti", or "set timer".',
      feedbackNe: 'आदेश बुझिएन। "अर्को चरण", "कति सिट्ठी", वा "टाइमर राख" भन्नुहोस्।',
      feedbackHi: 'आदेश समझ नहीं आया। "अगला कदम", "कितनी सीटी", या "टाइमर लगाओ" कहें।',
    );
  }

  // --- Normalization & Language Detection ---

  static String _normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s\u0900-\u097F]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _detectLanguage(String text, {required String fallback}) {
    // Check for Devanagari script
    if (RegExp(r'[\u0900-\u097F]').hasMatch(text)) {
      // Differentiate Nepali vs Hindi via common markers
      if (text.contains('सिट्ठी') ||
          text.contains('सिट्टी') ||
          text.contains('बाँकी') ||
          text.contains('बाकी') ||
          text.contains('अर्को') ||
          text.contains('अघिल्लो') ||
          text.contains('राख') ||
          text.contains('थप') ||
          text.contains('मिनेट') ||
          text.contains('पकाउनु') ||
          text.contains('होला')) {
        return 'ne';
      }
      if (text.contains('सीटी') ||
          text.contains('कदम') ||
          text.contains('जोड़ो') ||
          text.contains('लगाओ') ||
          text.contains('मिनट') ||
          text.contains('रोको')) {
        return 'hi';
      }
      return 'ne'; // Default Devanagari to Nepali in Siti Counter
    }
    return 'en';
  }

  // --- Intent Pattern Matchers ---

  static bool _isWhistleQuery(String text) {
    final enPatterns = [
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
    for (final p in enPatterns) {
      if (text.contains(p)) return true;
    }

    final nePatterns = [
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
    for (final p in nePatterns) {
      if (text.contains(p)) return true;
    }

    final hiPatterns = [
      'कितनी सीटी',
      'सीटी कितनी',
      'कितनी सीटी बची',
      'सीटी बची है',
      'सीटी स्टेटस',
    ];
    for (final p in hiPatterns) {
      if (text.contains(p)) return true;
    }

    return false;
  }

  static bool _isNextStep(String text) {
    final en = ['next step', 'go next', 'advance step', 'step forward'];
    for (final p in en) {
      if (text.contains(p)) return true;
    }
    if (text == 'next' || text == 'next please') return true;

    final ne = ['अर्को चरण', 'अर्को स्टेप', 'अगाडि बढ्नुहोस्', 'अगाडिको चरण', 'अर्को'];
    for (final p in ne) {
      if (text.contains(p)) return true;
    }

    final hi = ['अगला कदम', 'अगला स्टेप', 'आगे बढ़ो', 'अगला'];
    for (final p in hi) {
      if (text.contains(p)) return true;
    }

    return false;
  }

  static bool _isPreviousStep(String text) {
    final en = ['previous step', 'prev step', 'go back', 'step back', 'last step'];
    for (final p in en) {
      if (text.contains(p)) return true;
    }
    if (text == 'previous' || text == 'back') return true;

    final ne = ['अघिल्लो चरण', 'अघिल्लो स्टेप', 'पछाडि जानुहोस्', 'पछाडिको चरण', 'पछाडि', 'अघिल्लो'];
    for (final p in ne) {
      if (text.contains(p)) return true;
    }

    final hi = ['पिछला कदम', 'पिछला स्टेप', 'पीछे जाओ', 'पिछला'];
    for (final p in hi) {
      if (text.contains(p)) return true;
    }

    return false;
  }

  static bool _isRepeatStep(String text) {
    final en = ['repeat step', 'repeat', 'say again', 'read again', 'what was that'];
    for (final p in en) {
      if (text.contains(p)) return true;
    }

    final ne = ['फेरि भन्नुहोस्', 'फेरि पढ्नुहोस्', 'दोहोर्याउनुहोस्', 'दोहोराउ', 'फेरि'];
    for (final p in ne) {
      if (text.contains(p)) return true;
    }

    final hi = ['दोहराएं', 'दोहराओ', 'फिर से बोलो', 'फिर से पढ़ो', 'रिपीट'];
    for (final p in hi) {
      if (text.contains(p)) return true;
    }

    return false;
  }

  static bool _isPauseTimer(String text) {
    return text.contains('pause timer') ||
        text.contains('stop timer') ||
        text.contains('halt timer') ||
        text.contains('टाइमर रोक') ||
        text.contains('रोक्नुहोस्') ||
        text.contains('टाइमर पज') ||
        text.contains('टाइमर रोको') ||
        text.contains('रुकिए');
  }

  static bool _isResumeTimer(String text) {
    return text.contains('resume timer') ||
        text.contains('continue timer') ||
        text.contains('unpause timer') ||
        text.contains('टाइमर सुचारु') ||
        text.contains('सुचारु गर्नुहोस्') ||
        text.contains('टाइमर चालू') ||
        text.contains('कंटिन्यू');
  }

  static int? _extractTimerMinutes(String text) {
    if (!text.contains('timer') &&
        !text.contains('टाइमर') &&
        !text.contains('मिनेट') &&
        !text.contains('मिनट')) {
      return null;
    }

    // Pattern 1: standard digit before minutes
    final digitMatch = RegExp(r'(\d+)\s*(?:min|minute|minutes|मिनेट|मिनट)').firstMatch(text);
    if (digitMatch != null) {
      return int.tryParse(digitMatch.group(1)!);
    }

    // Pattern 2: Devanagari digit before minutes
    final devMatch = RegExp(r'([०-९]+)\s*(?:मिनेट|मिनट)').firstMatch(text);
    if (devMatch != null) {
      final western = _devanagariDigitsToWestern(devMatch.group(1)!);
      return int.tryParse(western);
    }

    // Pattern 3: Word numbers
    final wordMap = {
      'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5,
      'six': 6, 'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10,
      'fifteen': 15, 'twenty': 20, 'thirty': 30, 'forty five': 45,
      // Nepali words
      'एक': 1, 'दुई': 2, 'तीन': 3, 'चार': 4, 'पाँच': 5, 'पाच': 5,
      'छ': 6, 'सात': 7, 'आठ': 8, 'नौ': 9, 'दस': 10,
      'पन्ध्र': 15, 'बीस': 20, 'तीस': 30,
      // Hindi words
      'दो': 2, 'पांच': 5, 'छह': 6, 'पंद्रह': 15,
    };

    for (final entry in wordMap.entries) {
      if (text.contains(entry.key) &&
          (text.contains('minute') ||
              text.contains('min') ||
              text.contains('मिनेट') ||
              text.contains('मिनट') ||
              text.contains('timer') ||
              text.contains('टाइमर'))) {
        return entry.value;
      }
    }

    return null;
  }

  static String? _extractGroceryItem(String text) {
    // English: "add <item> to grocery/shopping list", "add <item> to list"
    final enMatch = RegExp(
      r'add\s+(.+?)\s+to\s+(?:the\s+)?(?:grocery|shopping|market)?\s*list',
      caseSensitive: false,
    ).firstMatch(text);
    if (enMatch != null) {
      return enMatch.group(1)!.trim();
    }

    // Alternative English: "buy <item>"
    if (text.startsWith('buy ')) {
      return text.substring(4).trim();
    }

    // Nepali: "<item> बजार सूचीमा थप", "<item> सूचीमा थप", "<item> लिस्टमा थप"
    final neMatch = RegExp(
      r'(.+?)\s+(?:बजार\s+)?(?:सूचीमा|लिस्टमा)\s+(?:थप|राख|जोड)',
      caseSensitive: false,
    ).firstMatch(text);
    if (neMatch != null) {
      return neMatch.group(1)!.trim();
    }

    // Hindi: "<item> ग्रोसरी लिस्ट में जोड़ो", "<item> लिस्ट में डालो"
    final hiMatch = RegExp(
      r'(.+?)\s+(?:ग्रोसरी\s+)?लिस्ट\s+में\s+(?:जोड़ो|डालो|रखो)',
      caseSensitive: false,
    ).firstMatch(text);
    if (hiMatch != null) {
      return hiMatch.group(1)!.trim();
    }

    return null;
  }

  static bool _isBoilingPointQuery(String text) {
    return text.contains('boiling point') ||
        text.contains('boiling temperature') ||
        text.contains('उम्लने तापक्रम') ||
        text.contains('उमाल्ने बिन्दु') ||
        text.contains('क्वथनांक');
  }

  static String _devanagariDigitsToWestern(String devanagari) {
    const devMap = {
      '०': '0', '१': '1', '२': '2', '३': '3', '४': '4',
      '५': '5', '६': '6', '७': '7', '८': '8', '९': '9',
    };
    var result = devanagari;
    devMap.forEach((k, v) {
      result = result.replaceAll(k, v);
    });
    return result;
  }
}
