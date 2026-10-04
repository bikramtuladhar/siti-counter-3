/// Advanced Allergy Protection Engine:
/// 1. Offline bilingual emergency allergy chef/travel cards (Nepali, English, etc.)
/// 2. Evidence-based baby & toddler allergen introduction tracker & pediatric safety rules.
library;

import 'allergen_engine.dart';

/// Supported language pairs for bilingual emergency allergy cards.
enum AllergyCardLanguage {
  englishOnly,
  nepaliOnly,
  bilingualEnNe,
}

/// An emergency contact for an allergy card.
class EmergencyContact {
  final String name;
  final String relationship;
  final String phone;
  final String? secondaryPhone;

  const EmergencyContact({
    required this.name,
    required this.relationship,
    required this.phone,
    this.secondaryPhone,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'relationship': relationship,
        'phone': phone,
        if (secondaryPhone != null) 'secondaryPhone': secondaryPhone,
      };

  factory EmergencyContact.fromJson(Map<String, dynamic> json) => EmergencyContact(
        name: json['name'] as String,
        relationship: json['relationship'] as String,
        phone: json['phone'] as String,
        secondaryPhone: json['secondaryPhone'] as String?,
      );
}

/// Data payload for generating an offline emergency allergy card.
class EmergencyAllergyCard {
  final String memberName;
  final int? memberAge;
  final List<String> severeAllergens;
  final List<String> moderateAllergens;
  final List<EmergencyContact> emergencyContacts;
  final String? medicalNotes;
  final bool carriesEpiPen;
  final String? doctorName;
  final String? doctorPhone;

  const EmergencyAllergyCard({
    required this.memberName,
    this.memberAge,
    required this.severeAllergens,
    this.moderateAllergens = const [],
    required this.emergencyContacts,
    this.medicalNotes,
    this.carriesEpiPen = false,
    this.doctorName,
    this.doctorPhone,
  });

  /// Returns localized allergen name in English.
  static String allergenNameEn(String allergenKey) {
    switch (allergenKey.toLowerCase()) {
      case AllergenCatalog.peanuts:
        return 'Peanuts';
      case AllergenCatalog.nuts:
        return 'Tree Nuts (Walnuts, Almonds, Cashews, Pistachios)';
      case AllergenCatalog.milk:
        return 'Dairy / Cow\'s Milk';
      case AllergenCatalog.eggs:
        return 'Eggs';
      case AllergenCatalog.fish:
        return 'Fish';
      case AllergenCatalog.crustaceans:
        return 'Crustaceans (Shrimp, Prawns, Crab, Lobster)';
      case AllergenCatalog.molluscs:
        return 'Molluscs (Clams, Mussels, Oysters, Squid)';
      case AllergenCatalog.gluten:
        return 'Gluten / Wheat / Barley / Rye';
      case AllergenCatalog.soy:
        return 'Soy / Soya Beans';
      case AllergenCatalog.sesame:
        return 'Sesame Seeds / Sesame Oil';
      case AllergenCatalog.mustard:
        return 'Mustard Seeds / Powder';
      case AllergenCatalog.mustardOil:
        return 'Mustard Oil (तोरीको तेल)';
      case AllergenCatalog.buckwheat:
        return 'Buckwheat (फापर)';
      case AllergenCatalog.fenugreek:
        return 'Fenugreek (मेथी)';
      case AllergenCatalog.celery:
        return 'Celery';
      case AllergenCatalog.lupin:
        return 'Lupin';
      case AllergenCatalog.sulphites:
        return 'Sulphites';
      default:
        return allergenKey;
    }
  }

  /// Returns localized allergen name in Devanagari Nepali.
  static String allergenNameNe(String allergenKey) {
    switch (allergenKey.toLowerCase()) {
      case AllergenCatalog.peanuts:
        return 'बदाम / मूंगफली (Peanuts)';
      case AllergenCatalog.nuts:
        return 'ओखर, काजु, बदाम, पिस्ता (Tree Nuts)';
      case AllergenCatalog.milk:
        return 'दूध, दही, घिउ, पनिर (Dairy / Milk products)';
      case AllergenCatalog.eggs:
        return 'अण्डा (Eggs)';
      case AllergenCatalog.fish:
        return 'माछा (Fish)';
      case AllergenCatalog.crustaceans:
        return 'झिँगे माछा, गँगटो (Shrimp, Crab)';
      case AllergenCatalog.molluscs:
        return 'घोङ्गी, शङ्खेकिरा (Molluscs)';
      case AllergenCatalog.gluten:
        return 'गहुँ, मैदा, जौ, ग्लुटेन (Wheat, Gluten)';
      case AllergenCatalog.soy:
        return 'भटमास, सोया सस, टोफु (Soy, Tofu)';
      case AllergenCatalog.sesame:
        return 'तिल, तिलको तेल (Sesame)';
      case AllergenCatalog.mustard:
        return 'सर्स्युँ, तोरी (Mustard)';
      case AllergenCatalog.mustardOil:
        return 'तोरीको तेल (Mustard Oil)';
      case AllergenCatalog.buckwheat:
        return 'फापर (Buckwheat)';
      case AllergenCatalog.fenugreek:
        return 'मेथी (Fenugreek)';
      case AllergenCatalog.celery:
        return 'सेलरी (Celery)';
      case AllergenCatalog.lupin:
        return 'लुपिन (Lupin)';
      case AllergenCatalog.sulphites:
        return 'सल्फाइट (Sulphites)';
      default:
        return allergenKey;
    }
  }

  /// Common hidden sources and cross-contact risks for the severe allergens on this card.
  List<String> get hiddenSourceWarningsEn {
    final warnings = <String>[];
    for (final a in severeAllergens) {
      switch (a.toLowerCase()) {
        case AllergenCatalog.milk:
          warnings.add('Dairy: Also avoid butter, ghee, milk powder, paneer, whey, and cheese.');
          break;
        case AllergenCatalog.peanuts:
          warnings.add('Peanut: Also avoid peanut oil, groundnut paste, and cross-reactive fenugreek (methi).');
          break;
        case AllergenCatalog.nuts:
          warnings.add('Tree Nuts: Watch out for nut pastes, pesto, sweets (halwa, barfi), and marzipan.');
          break;
        case AllergenCatalog.gluten:
          warnings.add('Gluten: Watch out for maida, semolina (suji), soy sauce with wheat, and hing diluted with wheat.');
          break;
        case AllergenCatalog.mustard:
        case AllergenCatalog.mustardOil:
          warnings.add('Mustard: Watch out for mixed vegetable oils, pickles (achar), and spice blends.');
          break;
        case AllergenCatalog.sesame:
          warnings.add('Sesame: Watch out for sesame oil, tahini, til ko chukauni, and achar tempering.');
          break;
      }
    }
    return warnings;
  }

  /// Common hidden sources and cross-contact risks in Nepali.
  List<String> get hiddenSourceWarningsNe {
    final warnings = <String>[];
    for (final a in severeAllergens) {
      switch (a.toLowerCase()) {
        case AllergenCatalog.milk:
          warnings.add('दूधजन्य: घिउ, नौनी, खुवा, पनिर, बटर, दूधको धुलो र चीजबाट पनि पूर्ण टाढा राख्नुहोस्।');
          break;
        case AllergenCatalog.peanuts:
          warnings.add('बदाम: बदामको तेल, पेष्ट र यससँग मिल्दोजुल्दो मेथी (Fenugreek) बाट पनि जोगिनुहोस्।');
          break;
        case AllergenCatalog.nuts:
          warnings.add('ओखर/काजु: मिठाई (बर्फी, हलुवा), पेस्ट र ग्रेभीमा प्रयोग हुने काजुको पेस्टबाट जोगिनुहोस्।');
          break;
        case AllergenCatalog.gluten:
          warnings.add('ग्लुटेन: मैदा, सुजी, गहुँको पिठो, र मैदा मिसाइएको हिंगबाट पूर्ण परहेज गर्नुहोस्।');
          break;
        case AllergenCatalog.mustard:
        case AllergenCatalog.mustardOil:
          warnings.add('तोरी: तोरीको तेल, अचार, झान्न प्रयोग गरिने सर्स्युँ र मिश्रित खानेतेलबाट जोगिनुहोस्।');
          break;
        case AllergenCatalog.sesame:
          warnings.add('तिल: तिलको तेल, चुकाउनी, छोप र अचारमा हालिएको तिलबाट परहेज गर्नुहोस्।');
          break;
      }
    }
    return warnings;
  }

  /// Generates a clean printable markdown representation of the bilingual emergency card.
  String generateMarkdownCard() {
    final buffer = StringBuffer();
    buffer.writeln('# 🚨 EMERGENCY ALLERGY CARD / आकस्मिक एलर्जी कार्ड');
    buffer.writeln('**Name / नाम:** $memberName' + (memberAge != null ? ' (Age: $memberAge)' : ''));
    buffer.writeln();

    buffer.writeln('## 🛑 SEVERE LIFE-THREATENING ALLERGIES / गम्भीर एलर्जीहरू');
    buffer.writeln('> **ATTENTION CHEF / SERVER / RESTAURANT:**');
    buffer.writeln('> I have severe, life-threatening food allergies. Please ensure that my food, cooking surfaces, pans, utensils, and oil DO NOT come into contact with:');
    for (final a in severeAllergens) {
      buffer.writeln('> • **${allergenNameEn(a)}** (${allergenNameNe(a)})');
    }
    buffer.writeln('> Even trace cross-contact can cause severe anaphylactic shock. Thank you for your care.');
    buffer.writeln();

    buffer.writeln('> **शेफ / भान्से / वेटरको ध्यानाकर्षण:**');
    buffer.writeln('> मलाई यी खाद्य पदार्थहरूबाट ज्यान जोखिममा पर्न सक्ने गम्भीर एलर्जी छ। कृपया मेरो खाना, भाँडाकुँडा, डाडु, पन्यु, चुलो र तेल यी परिकारहरूसँग पटक्कै नछुन दिनुहोला:');
    for (final a in severeAllergens) {
      buffer.writeln('> • **${allergenNameNe(a)}**');
    }
    buffer.writeln('> अलिकति मात्र सम्पर्क वा लसपस भए पनि गम्भीर खतरा हुन सक्छ। सहयोगको लागि धन्यवाद।');
    buffer.writeln();

    if (moderateAllergens.isNotEmpty) {
      buffer.writeln('### ⚠️ Moderate Allergies / अन्य एलर्जीहरू:');
      for (final a in moderateAllergens) {
        buffer.writeln('- ${allergenNameEn(a)} / ${allergenNameNe(a)}');
      }
      buffer.writeln();
    }

    final hiddenEn = hiddenSourceWarningsEn;
    if (hiddenEn.isNotEmpty) {
      buffer.writeln('### 🔍 Hidden Ingredients & Cross-Contact / लुकेका सामग्रीहरू:');
      for (final h in hiddenEn) {
        buffer.writeln('- $h');
      }
      buffer.writeln();
    }

    if (carriesEpiPen) {
      buffer.writeln('### 💉 EMERGENCY MEDICAL ACTION / आकस्मिक उपचार:');
      buffer.writeln('**THIS PERSON CARRIES AN EPINEPHRINE AUTO-INJECTOR (EpiPen).**');
      buffer.writeln('In case of breathing difficulty, swelling, or allergic collapse:');
      buffer.writeln('1. Administer Epinephrine auto-injector into outer mid-thigh immediately.');
      buffer.writeln('2. Call Emergency Ambulance immediately (Nepal: 102, Intl: 911 / 112).');
      buffer.writeln('3. Keep person lying down with legs elevated.');
      buffer.writeln();
    }

    if (emergencyContacts.isNotEmpty) {
      buffer.writeln('### 📞 EMERGENCY CONTACTS / आकस्मिक सम्पर्क:');
      for (final c in emergencyContacts) {
        buffer.writeln('• **${c.name}** (${c.relationship}): [${c.phone}](tel:${c.phone})' +
            (c.secondaryPhone != null ? ' / ${c.secondaryPhone}' : ''));
      }
      buffer.writeln();
    }

    if (doctorName != null) {
      buffer.writeln('**Physician / चिकित्सक:** $doctorName' +
          (doctorPhone != null ? ' (${doctorPhone})' : ''));
    }

    return buffer.toString();
  }
}

/// Clinical reaction severity rating observed during infant allergen exposure.
enum ReactionSeverity {
  none,
  mild, // Localized redness around mouth, mild scattered hives, minor itch
  moderate, // Generalized hives, persistent vomiting, diarrhea, lip/eye swelling
  severe, // Wheezing, stridor, coughing, lethargy, paleness, anaphylaxis (EMERGENCY)
}

/// Status of an allergen within the infant introduction protocol.
enum InfantIntroductionStatus {
  notIntroduced,
  introducing, // First exposures in progress (e.g. Day 1 - Day 3)
  toleratedSafely, // Successfully tolerated without allergic reaction
  adverseReaction, // Allergic reaction triggered; introduction paused
}

/// A logged exposure record for baby/toddler allergen introduction.
class InfantAllergenLog {
  final String id;
  final String memberId;
  final String allergen;
  final String foodDescription;
  final DateTime exposureDate;
  final double portionGrams;
  final String portionUnitLabel; // e.g. "1/4 teaspoon", "1/2 teaspoon", "grams"
  final int dayOfProtocol; // Day 1, Day 2, Day 3
  final ReactionSeverity reactionSeverity;
  final String? reactionSymptoms;
  final String? notes;

  const InfantAllergenLog({
    required this.id,
    required this.memberId,
    required this.allergen,
    required this.foodDescription,
    required this.exposureDate,
    required this.portionGrams,
    this.portionUnitLabel = 'grams',
    this.dayOfProtocol = 1,
    this.reactionSeverity = ReactionSeverity.none,
    this.reactionSymptoms,
    this.notes,
  });

  bool get hadAdverseReaction => reactionSeverity != ReactionSeverity.none;

  Map<String, dynamic> toJson() => {
        'id': id,
        'memberId': memberId,
        'allergen': allergen,
        'foodDescription': foodDescription,
        'exposureDate': exposureDate.toIso8601String(),
        'portionGrams': portionGrams,
        'portionUnitLabel': portionUnitLabel,
        'dayOfProtocol': dayOfProtocol,
        'reactionSeverity': reactionSeverity.name,
        if (reactionSymptoms != null) 'reactionSymptoms': reactionSymptoms,
        if (notes != null) 'notes': notes,
      };

  factory InfantAllergenLog.fromJson(Map<String, dynamic> json) => InfantAllergenLog(
        id: json['id'] as String,
        memberId: json['memberId'] as String,
        allergen: json['allergen'] as String,
        foodDescription: json['foodDescription'] as String,
        exposureDate: DateTime.parse(json['exposureDate'] as String),
        portionGrams: (json['portionGrams'] as num).toDouble(),
        portionUnitLabel: json['portionUnitLabel'] as String? ?? 'grams',
        dayOfProtocol: json['dayOfProtocol'] as int? ?? 1,
        reactionSeverity: ReactionSeverity.values.firstWhere(
          (e) => e.name == json['reactionSeverity'],
          orElse: () => ReactionSeverity.none,
        ),
        reactionSymptoms: json['reactionSymptoms'] as String?,
        notes: json['notes'] as String?,
      );
}

/// Clinical guidance and summary for baby/toddler allergen introduction.
class InfantAllergenSummary {
  final String allergen;
  final InfantIntroductionStatus status;
  final int totalExposures;
  final DateTime? firstExposed;
  final DateTime? lastExposed;
  final ReactionSeverity worstReaction;
  final List<InfantAllergenLog> logs;

  const InfantAllergenSummary({
    required this.allergen,
    required this.status,
    required this.totalExposures,
    this.firstExposed,
    this.lastExposed,
    this.worstReaction = ReactionSeverity.none,
    this.logs = const [],
  });
}

/// Engine providing pediatric safety rules, introduction protocols, and progress aggregation.
class InfantAllergenEngine {
  /// Prominent pediatric disclaimer required on all baby & toddler introduction views.
  static const String pediatricDisclaimerEn =
      'PEDIATRIC DISCLAIMER: This tracker provides educational guidelines based on clinical pediatric protocols. '
      'Always consult your pediatrician or pediatric allergist before starting early allergen introduction, '
      'especially if your infant has severe eczema or existing egg allergy. Never feed whole nuts or thick paste (choking hazard). '
      'If your child develops facial swelling, wheezing, vomiting, or breathing difficulty, seek immediate emergency medical care.';

  static const String pediatricDisclaimerNe =
      'बालरोग विशेषज्ञ सल्लाह: यो ट्र्याकर चिकित्सकीय बालरोग निर्देशिकामा आधारित शैक्षिक जानकारी मात्र हो। '
      'बच्चालाई नयाँ खाना वा एलर्जी हुने तत्व खुवाउनु अघि बालरोग विशेषज्ञ (Pediatrician) सँग परामर्श लिनुहोस्, '
      'विशेष गरी बच्चालाई कडा दाद (Eczema) वा छालाको समस्या छ भने। सिंगो दाना वा बाक्लो पेस्ट कहिल्यै नखुवाउनुहोस् (घाँटीमा अड्किने जोखिम)। '
      'यदि बच्चाको अनुहार सुन्निने, सास फेर्न गाह्रो हुने वा बान्ता हुने भएमा तुरुन्त आकस्मिक अस्पताल लैजानुहोस्।';

  /// Standard pediatric high-priority introduction allergens.
  static const List<String> priorityBabyAllergens = [
    AllergenCatalog.peanuts,
    AllergenCatalog.eggs,
    AllergenCatalog.milk,
    AllergenCatalog.sesame,
    AllergenCatalog.fish,
    AllergenCatalog.gluten,
    AllergenCatalog.soy,
    AllergenCatalog.nuts,
  ];

  /// Safety preparation instructions to prevent infant choking.
  static String getChokingSafetyGuidanceEn(String allergenKey) {
    switch (allergenKey.toLowerCase()) {
      case AllergenCatalog.peanuts:
      case AllergenCatalog.nuts:
        return 'CHOKING HAZARD: Never feed whole nuts or thick sticky nut butter to infants. '
            'Thin smooth peanut/nut butter with warm water, breastmilk, or fruit puree until loose and runny.';
      case AllergenCatalog.eggs:
        return 'Ensure egg is thoroughly cooked. Mash hard-boiled egg yolk or soft scrambled egg thoroughly into a smooth puree.';
      case AllergenCatalog.fish:
        return 'Thoroughly check for and remove all tiny bones. Puree or flake cooked white fish into fine pieces.';
      default:
        return 'Offer small age-appropriate soft textures. Always supervise baby closely during eating.';
    }
  }

  /// Safety preparation instructions in Nepali.
  static String getChokingSafetyGuidanceNe(String allergenKey) {
    switch (allergenKey.toLowerCase()) {
      case AllergenCatalog.peanuts:
      case AllergenCatalog.nuts:
        return 'घाँटीमा अड्किने चेतावनी: शिशुलाई सिंगो बदाम वा काजु कहिल्यै नदिनुहोस्। '
            'बदामको पेस्टलाई तातो पानी, आमाको दूध वा फलफूलको प्युरीमा मिसाएर पातलो र नरम बनाएर मात्र चटाउनुहोस्।';
      case AllergenCatalog.eggs:
        return 'अण्डा राम्ररी पाकेको हुनुपर्छ। उसिनेको अण्डाको पहेंलो भागलाई आमाको दूध वा तरकारीको रसमा राम्ररी मिचेर नरम बनाउनुहोस्।';
      case AllergenCatalog.fish:
        return 'माछाको काँडा राम्ररी छानेर हटाउनुहोस्। काँडा नभएको उसिनेको माछालाई मसिनो गरी मुछेर मात्र दिनुहोस्।';
      default:
        return 'बच्चाको उमेर अनुसार नरम र पातलो बनाएर मात्र खुवाउनुहोस्। खुवाउँदा सधैं बच्चासँगै बस्नुहोस्।';
    }
  }

  /// Evaluates readiness to introduce a new allergen based on exposure history.
  /// Rule: Only introduce one new top allergen at a time; observe for 3-5 days.
  static bool canIntroduceNewAllergen({
    required List<InfantAllergenLog> recentLogs,
    required String newAllergen,
    required DateTime candidateDate,
  }) {
    if (recentLogs.isEmpty) return true;

    // Check logs within the last 3 days
    for (final log in recentLogs) {
      if (log.allergen != newAllergen) {
        final diff = candidateDate.difference(log.exposureDate).inDays.abs();
        if (diff < 3 && log.hadAdverseReaction) {
          // If a reaction occurred in last 3 days, pause new introduction
          return false;
        }
      }
    }
    return true;
  }

  /// Aggregates a list of exposure logs into allergen-by-allergen progress summaries.
  static Map<String, InfantAllergenSummary> aggregateSummaries({
    required List<InfantAllergenLog> logs,
    List<String>? targetAllergens,
  }) {
    final allergens = targetAllergens ?? priorityBabyAllergens;
    final map = <String, InfantAllergenSummary>{};

    for (final allergen in allergens) {
      final matching = logs.where((l) => l.allergen == allergen).toList();
      matching.sort((a, b) => a.exposureDate.compareTo(b.exposureDate));

      if (matching.isEmpty) {
        map[allergen] = InfantAllergenSummary(
          allergen: allergen,
          status: InfantIntroductionStatus.notIntroduced,
          totalExposures: 0,
        );
      } else {
        final hasAdverse = matching.any((l) => l.hadAdverseReaction);
        final worst = matching.fold<ReactionSeverity>(
          ReactionSeverity.none,
          (prev, curr) => curr.reactionSeverity.index > prev.index ? curr.reactionSeverity : prev,
        );

        InfantIntroductionStatus status;
        if (hasAdverse) {
          status = InfantIntroductionStatus.adverseReaction;
        } else if (matching.length >= 3) {
          // Reached 3 safe exposures over multiple days
          status = InfantIntroductionStatus.toleratedSafely;
        } else {
          status = InfantIntroductionStatus.introducing;
        }

        map[allergen] = InfantAllergenSummary(
          allergen: allergen,
          status: status,
          totalExposures: matching.length,
          firstExposed: matching.first.exposureDate,
          lastExposed: matching.last.exposureDate,
          worstReaction: worst,
          logs: matching,
        );
      }
    }

    return map;
  }
}
