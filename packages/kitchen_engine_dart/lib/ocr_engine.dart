library;

import 'allergen_engine.dart';

class ParsedReceiptItem {
  final String rawLine;
  final String name;
  final String? matchedIngredientId;
  final double? quantityGrams;
  final String? unit;
  final double? price;
  final double confidence;

  const ParsedReceiptItem({
    required this.rawLine,
    required this.name,
    this.matchedIngredientId,
    this.quantityGrams,
    this.unit,
    this.price,
    this.confidence = 1.0,
  });

  Map<String, dynamic> toJson() => {
        'rawLine': rawLine,
        'name': name,
        'matchedIngredientId': matchedIngredientId,
        'quantityGrams': quantityGrams,
        'unit': unit,
        'price': price,
        'confidence': confidence,
      };
}

class ParsedReceipt {
  final String? merchantName;
  final String? receiptDate;
  final List<ParsedReceiptItem> items;
  final double? totalAmount;
  final String currency;
  final String rawText;

  const ParsedReceipt({
    this.merchantName,
    this.receiptDate,
    required this.items,
    this.totalAmount,
    this.currency = 'NPR',
    required this.rawText,
  });

  Map<String, dynamic> toJson() => {
        'merchantName': merchantName,
        'receiptDate': receiptDate,
        'items': items.map((i) => i.toJson()).toList(),
        'totalAmount': totalAmount,
        'currency': currency,
        'rawText': rawText,
      };
}

enum AllergenWarningType {
  contains,
  mayContain;

  String toJson() => this == AllergenWarningType.contains ? 'contains' : 'may_contain';

  static AllergenWarningType fromJson(String value) =>
      value == 'contains' ? AllergenWarningType.contains : AllergenWarningType.mayContain;
}

class MemberAllergenAlert {
  final String memberId;
  final String memberName;
  final String allergen;
  final AllergySeverity severity;
  final AllergenWarningType warningType;
  final String matchedSnippet;
  final String alertEn;
  final String alertNe;

  const MemberAllergenAlert({
    required this.memberId,
    required this.memberName,
    required this.allergen,
    required this.severity,
    required this.warningType,
    required this.matchedSnippet,
    required this.alertEn,
    required this.alertNe,
  });

  Map<String, dynamic> toJson() => {
        'memberId': memberId,
        'memberName': memberName,
        'allergen': allergen,
        'severity': severity.name,
        'warningType': warningType.toJson(),
        'matchedSnippet': matchedSnippet,
        'alertEn': alertEn,
        'alertNe': alertNe,
      };
}

class LabelHighlightSpan {
  final int start;
  final int end;
  final String matchedText;
  final String allergen;
  final AllergenWarningType warningType;

  const LabelHighlightSpan({
    required this.start,
    required this.end,
    required this.matchedText,
    required this.allergen,
    required this.warningType,
  });

  Map<String, dynamic> toJson() => {
        'start': start,
        'end': end,
        'matchedText': matchedText,
        'allergen': allergen,
        'warningType': warningType.toJson(),
      };
}

class LabelScanResult {
  final String rawText;
  final List<String> detectedAllergens;
  final List<String> facilityWarnings;
  final List<MemberAllergenAlert> memberAlerts;
  final bool isSafeForHousehold;
  final List<LabelHighlightSpan> highlightSpans;

  const LabelScanResult({
    required this.rawText,
    required this.detectedAllergens,
    required this.facilityWarnings,
    required this.memberAlerts,
    required this.isSafeForHousehold,
    required this.highlightSpans,
  });

  Map<String, dynamic> toJson() => {
        'rawText': rawText,
        'detectedAllergens': detectedAllergens,
        'facilityWarnings': facilityWarnings,
        'memberAlerts': memberAlerts.map((a) => a.toJson()).toList(),
        'isSafeForHousehold': isSafeForHousehold,
        'highlightSpans': highlightSpans.map((s) => s.toJson()).toList(),
      };
}

class HouseholdMemberAllergyInput {
  final String memberId;
  final String memberName;
  final String allergen;
  final AllergySeverity severity;

  const HouseholdMemberAllergyInput({
    required this.memberId,
    required this.memberName,
    required this.allergen,
    required this.severity,
  });
}

class _IngredientPattern {
  final String id;
  final List<String> patterns;
  final double defaultGrams;

  const _IngredientPattern(this.id, this.patterns, this.defaultGrams);
}

const List<_IngredientPattern> _ingredientKeywords = [
  _IngredientPattern('potato', [
    r'potato',
    r'aloo',
    r'alu',
    r'आलु',
  ], 1000),
  _IngredientPattern('tomato', [
    r'tomato',
    r'golbheda',
    r'गोलभेडा',
  ], 500),
  _IngredientPattern('onion', [
    r'onion',
    r'pyaj',
    r'प्यार्ज',
  ], 1000),
  _IngredientPattern('cauliflower', [
    r'cauliflower',
    r'gobi',
    r'kauli',
    r'काउली',
  ], 800),
  _IngredientPattern('cabbage', [
    r'cabbage',
    r'banda',
    r'बन्दा',
  ], 700),
  _IngredientPattern('mustard_greens', [
    r'mustard\s*green',
    r'rayo',
    r'रायो',
  ], 400),
  _IngredientPattern('spinach', [
    r'spinach',
    r'palungo',
    r'पालुङ्गो',
  ], 300),
  _IngredientPattern('ginger', [
    r'ginger',
    r'aduwa',
    r'अदुवा',
  ], 200),
  _IngredientPattern('garlic', [
    r'garlic',
    r'lasun',
    r'लसुन',
  ], 200),
  _IngredientPattern('cilantro', [
    r'coriander',
    r'dhaniya',
    r'धनिया',
  ], 150),
  _IngredientPattern('rice', [
    r'basmati',
    r'rice',
    r'chamal',
    r'चामल',
  ], 5000),
  _IngredientPattern('lentils_yellow', [
    r'yellow\s*lentil',
    r'moong',
    r'मुङ्ग',
  ], 1000),
  _IngredientPattern('lentils_black', [
    r'black\s*lentil',
    r'maas',
    r'मास',
  ], 1000),
  _IngredientPattern('mustard_oil', [
    r'mustard\s*oil',
    r'tori.*tel',
    r'तोरीको\s*तेल',
  ], 1000),
  _IngredientPattern('sunflower_oil', [
    r'sunflower\s*oil',
    r'सूर्यमुखी',
  ], 1000),
  _IngredientPattern('flour_wheat', [
    r'wheat\s*flour',
    r'atta',
    r'आटा',
  ], 2000),
  _IngredientPattern('salt', [
    r'salt',
    r'noon',
    r'नुन',
  ], 1000),
];

final Map<String, List<RegExp>> _allergenKeywordMap = {
  AllergenCatalog.gluten: [
    RegExp(r'gluten', caseSensitive: false),
    RegExp(r'wheat', caseSensitive: false),
    RegExp(r'barley', caseSensitive: false),
    RegExp(r'rye', caseSensitive: false),
    RegExp(r'oats', caseSensitive: false),
    RegExp(r'spelt', caseSensitive: false),
    RegExp(r'maida', caseSensitive: false),
    RegExp(r'sooji', caseSensitive: false),
    RegExp(r'semolina', caseSensitive: false),
    RegExp(r'गहुँ', caseSensitive: false),
    RegExp(r'मैदा', caseSensitive: false),
    RegExp(r'सूजी', caseSensitive: false),
    RegExp(r'जौ', caseSensitive: false),
  ],
  AllergenCatalog.milk: [
    RegExp(r'milk', caseSensitive: false),
    RegExp(r'dairy', caseSensitive: false),
    RegExp(r'whey', caseSensitive: false),
    RegExp(r'casein', caseSensitive: false),
    RegExp(r'butter', caseSensitive: false),
    RegExp(r'ghee', caseSensitive: false),
    RegExp(r'cheese', caseSensitive: false),
    RegExp(r'paneer', caseSensitive: false),
    RegExp(r'curd', caseSensitive: false),
    RegExp(r'dahi', caseSensitive: false),
    RegExp(r'chhurpi', caseSensitive: false),
    RegExp(r'lactose', caseSensitive: false),
    RegExp(r'दूध', caseSensitive: false),
    RegExp(r'घ्यु', caseSensitive: false),
    RegExp(r'पनीर', caseSensitive: false),
    RegExp(r'दही', caseSensitive: false),
  ],
  AllergenCatalog.peanuts: [
    RegExp(r'peanut', caseSensitive: false),
    RegExp(r'groundnut', caseSensitive: false),
    RegExp(r'बदाम', caseSensitive: false),
  ],
  AllergenCatalog.nuts: [
    RegExp(r'tree\s*nut', caseSensitive: false),
    RegExp(r'almond', caseSensitive: false),
    RegExp(r'cashew', caseSensitive: false),
    RegExp(r'walnut', caseSensitive: false),
    RegExp(r'pistachio', caseSensitive: false),
    RegExp(r'hazelnut', caseSensitive: false),
    RegExp(r'काजु', caseSensitive: false),
    RegExp(r'हाडे\s*बदाम', caseSensitive: false),
    RegExp(r'ओखर', caseSensitive: false),
    RegExp(r'पिस्ता', caseSensitive: false),
  ],
  AllergenCatalog.soy: [
    RegExp(r'soy', caseSensitive: false),
    RegExp(r'soya', caseSensitive: false),
    RegExp(r'soybean', caseSensitive: false),
    RegExp(r'tofu', caseSensitive: false),
    RegExp(r'भटमास', caseSensitive: false),
  ],
  AllergenCatalog.eggs: [
    RegExp(r'egg', caseSensitive: false),
    RegExp(r'albumin', caseSensitive: false),
    RegExp(r'अण्डा', caseSensitive: false),
  ],
  AllergenCatalog.fish: [
    RegExp(r'fish', caseSensitive: false),
    RegExp(r'माछा', caseSensitive: false),
  ],
  AllergenCatalog.crustaceans: [
    RegExp(r'crustacean', caseSensitive: false),
    RegExp(r'shrimp', caseSensitive: false),
    RegExp(r'prawn', caseSensitive: false),
    RegExp(r'crab', caseSensitive: false),
    RegExp(r'lobster', caseSensitive: false),
    RegExp(r'झिङ्गे\s*माछा', caseSensitive: false),
  ],
  AllergenCatalog.mustard: [
    RegExp(r'mustard', caseSensitive: false),
    RegExp(r'सरस्यूँ', caseSensitive: false),
    RegExp(r'तोरी', caseSensitive: false),
  ],
  AllergenCatalog.mustardOil: [
    RegExp(r'mustard\s*oil', caseSensitive: false),
    RegExp(r'तोरीको\s*तेल', caseSensitive: false),
  ],
  AllergenCatalog.sesame: [
    RegExp(r'sesame', caseSensitive: false),
    RegExp(r'til', caseSensitive: false),
    RegExp(r'तिल', caseSensitive: false),
  ],
  AllergenCatalog.buckwheat: [
    RegExp(r'buckwheat', caseSensitive: false),
    RegExp(r'fapar', caseSensitive: false),
    RegExp(r'फापर', caseSensitive: false),
  ],
  AllergenCatalog.fenugreek: [
    RegExp(r'fenugreek', caseSensitive: false),
    RegExp(r'methi', caseSensitive: false),
    RegExp(r'मेथी', caseSensitive: false),
  ],
  AllergenCatalog.sulphites: [
    RegExp(r'sulphite', caseSensitive: false),
    RegExp(r'sulfite', caseSensitive: false),
    RegExp(r'sulphur\s*dioxide', caseSensitive: false),
  ],
  AllergenCatalog.celery: [
    RegExp(r'celery', caseSensitive: false),
  ],
};

String _toAsciiDigits(String input) {
  const devanagariMap = {
    '०': '0',
    '१': '1',
    '२': '2',
    '३': '3',
    '४': '4',
    '५': '5',
    '६': '6',
    '७': '7',
    '८': '8',
    '९': '9',
  };
  var result = input;
  devanagariMap.forEach((d, a) {
    result = result.replaceAll(d, a);
  });
  return result;
}

class OcrReceiptParser {
  static ParsedReceipt parseReceipt(String rawText) {
    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    String? merchantName;
    String? receiptDate;
    double? totalAmount;
    final items = <ParsedReceiptItem>[];

    // 1. Merchant Detection
    final merchantPatterns = [
      (name: 'Bhatbhateni Supermarket', regex: RegExp(r'bhatbhateni|bbsm', caseSensitive: false)),
      (name: 'BigMart Online', regex: RegExp(r'big\s*mart', caseSensitive: false)),
      (name: 'SalesBerry Department Store', regex: RegExp(r'salesberry', caseSensitive: false)),
      (name: 'Namaste Supermarket', regex: RegExp(r'namaste\s*supermarket', caseSensitive: false)),
      (name: 'Haat Bazaar Bill', regex: RegExp(r'haat\s*bazaar|कृषि\s*बजार', caseSensitive: false)),
    ];

    for (final line in lines.take(6)) {
      for (final m in merchantPatterns) {
        if (m.regex.hasMatch(line)) {
          merchantName = m.name;
          break;
        }
      }
      if (merchantName != null) break;
    }

    // 2. Date Detection
    final dateRegex = RegExp(r'(\d{4}[-/.]\d{1,2}[-/.]\d{1,2})|(\d{1,2}[-/.]\d{1,2}[-/.]\d{2,4})');
    for (final line in lines) {
      final match = dateRegex.firstMatch(line);
      if (match != null) {
        receiptDate = match.group(0);
        break;
      }
    }

    // 3. Items and Prices
    final priceRegex = RegExp(r'(?:rs\.?|npr|रु\.?)?\s*([0-9०-९]+(?:[.,][0-9०-९]{2}))\b', caseSensitive: false);
    final qtyRegex = RegExp(
      r'([0-9०-९]+(?:\.[0-9०-९]+)?)\s*(kg|g|gm|ltr|l|ml|packet|pkt|pcs|pc|के\.?जी\.?|माना|पाउ|धार्नी)',
      caseSensitive: false,
    );
    final headerFooterRegex = RegExp(
      r'subtotal|total|cash|change|vat|tax|invoice|phone|pan\s*no|thank\s*you|जम्मा|कुल|रसिद|मिति|धन्यवाद',
      caseSensitive: false,
    );
    final totalValueRegex = RegExp(
      r'(?:total|net\s*amt|grand\s*total|जम्मा|कुल)\D*([0-9०-९]+(?:\.[0-9०-९]{2})?)',
      caseSensitive: false,
    );

    for (final line in lines) {
      if (headerFooterRegex.hasMatch(line)) {
        final totalMatch = totalValueRegex.firstMatch(line);
        if (totalMatch != null) {
          final rawVal = totalMatch.group(1);
          if (rawVal != null) {
            totalAmount = double.tryParse(_toAsciiDigits(rawVal));
          }
        }
        continue;
      }

      final priceMatch = priceRegex.firstMatch(line);
      double? price;
      if (priceMatch != null) {
        final rawPrice = priceMatch.group(1)?.replaceAll(',', '');
        if (rawPrice != null) {
          price = double.tryParse(_toAsciiDigits(rawPrice));
        }
      }

      final qtyMatch = qtyRegex.firstMatch(line);
      double? quantityGrams;
      String? unit;

      if (qtyMatch != null) {
        final rawVal = qtyMatch.group(1);
        final rawUnit = qtyMatch.group(2);
        if (rawVal != null && rawUnit != null) {
          final val = double.tryParse(_toAsciiDigits(rawVal)) ?? 1.0;
          unit = rawUnit.toLowerCase();
          if (unit == 'kg' || unit.contains('के')) {
            quantityGrams = val * 1000;
          } else if (unit == 'g' || unit == 'gm') {
            quantityGrams = val;
          } else if (unit == 'l' || unit == 'ltr') {
            quantityGrams = val * 1000;
          } else if (unit == 'ml') {
            quantityGrams = val;
          } else if (unit == 'पाउ') {
            quantityGrams = val * 250;
          } else if (unit == 'धार्नी') {
            quantityGrams = val * 2500;
          } else if (unit == 'माना') {
            quantityGrams = val * 500;
          } else {
            quantityGrams = val * 1000;
          }
        }
      }

      String? matchedIngredientId;
      for (final ing in _ingredientKeywords) {
        final matches = ing.patterns.any((p) => RegExp(p, caseSensitive: false).hasMatch(line));
        if (matches) {
          matchedIngredientId = ing.id;
          quantityGrams ??= ing.defaultGrams;
          break;
        }
      }

      if (matchedIngredientId != null || (price != null && price > 0 && line.length > 5)) {
        var cleanName = line
            .replaceAll(priceRegex, '')
            .replaceAll(RegExp(r'[0-9]+(?:\.[0-9]+)?\s*(?:kg|g|gm|l|ltr|ml|pkt|pcs)\b', caseSensitive: false), '')
            .replaceAll(RegExp(r'[@#*]'), '')
            .trim();

        items.add(ParsedReceiptItem(
          rawLine: line,
          name: cleanName.isNotEmpty ? cleanName : (matchedIngredientId ?? 'Grocery Item'),
          matchedIngredientId: matchedIngredientId,
          quantityGrams: quantityGrams,
          unit: unit ?? 'g',
          price: price,
          confidence: matchedIngredientId != null ? 0.95 : 0.7,
        ));
      }
    }

    if (totalAmount == null && items.isNotEmpty) {
      totalAmount = items.fold<double>(0.0, (acc, curr) => acc + (curr.price ?? 0.0));
    }

    return ParsedReceipt(
      merchantName: merchantName,
      receiptDate: receiptDate,
      items: items,
      totalAmount: totalAmount,
      currency: 'NPR',
      rawText: rawText,
    );
  }
}

class FoodLabelScanner {
  static LabelScanResult scanLabel(
    String rawText, {
    List<HouseholdMemberAllergyInput> householdMembers = const [],
  }) {
    final textLower = rawText.toLowerCase();
    final detectedAllergens = <String>{};
    final facilityWarnings = <String>{};
    final highlightSpans = <LabelHighlightSpan>[];

    final mayContainRegex = RegExp(
      r'may\s+contain|facility|traces\s+of|processed\s+on\s+shared|अवशेष\s+हुन\s+सक्छ',
      caseSensitive: false,
    );
    final mayContainMatch = mayContainRegex.firstMatch(textLower);

    final containsSection = mayContainMatch != null ? textLower.substring(0, mayContainMatch.start) : textLower;
    final mayContainSection = mayContainMatch != null ? textLower.substring(mayContainMatch.start) : '';

    _allergenKeywordMap.forEach((allergen, patterns) {
      for (final pattern in patterns) {
        final containsMatch = pattern.firstMatch(containsSection);
        if (containsMatch != null) {
          detectedAllergens.add(allergen);
          highlightSpans.add(LabelHighlightSpan(
            start: containsMatch.start,
            end: containsMatch.end,
            matchedText: containsMatch.group(0) ?? '',
            allergen: allergen,
            warningType: AllergenWarningType.contains,
          ));
          break;
        }

        if (mayContainSection.isNotEmpty) {
          final mayMatch = pattern.firstMatch(mayContainSection);
          if (mayMatch != null) {
            facilityWarnings.add(allergen);
            final globalStart = (mayContainMatch?.start ?? 0) + mayMatch.start;
            final globalEnd = (mayContainMatch?.start ?? 0) + mayMatch.end;
            highlightSpans.add(LabelHighlightSpan(
              start: globalStart,
              end: globalEnd,
              matchedText: mayMatch.group(0) ?? '',
              allergen: allergen,
              warningType: AllergenWarningType.mayContain,
            ));
            break;
          }
        }
      }
    });

    final memberAlerts = <MemberAllergenAlert>[];
    var isSafeForHousehold = true;

    for (final member in householdMembers) {
      final isContains = detectedAllergens.contains(member.allergen);
      final isMayContain = facilityWarnings.contains(member.allergen);

      if (isContains || isMayContain) {
        final warningType = isContains ? AllergenWarningType.contains : AllergenWarningType.mayContain;

        if (member.severity == AllergySeverity.severe || isContains) {
          isSafeForHousehold = false;
        }

        final allergenNameEn = member.allergen.replaceAll('_', ' ');
        final snippet = isContains ? 'Contains $allergenNameEn' : 'May contain $allergenNameEn';

        final alertEn = isContains
            ? 'DANGER: Contains $allergenNameEn! ${member.memberName} has ${member.severity.name} allergy.'
            : 'CAUTION: Traces of $allergenNameEn possible. ${member.memberName} has ${member.severity.name} allergy.';

        final alertNe = isContains
            ? 'खतरा: यसमा $allergenNameEn समावेश छ! ${member.memberName} लाई कडा एलर्जी छ।'
            : 'सावधानी: यसमा $allergenNameEn को अवशेष हुन सक्छ। ${member.memberName} लाई एलर्जी छ।';

        memberAlerts.add(MemberAllergenAlert(
          memberId: member.memberId,
          memberName: member.memberName,
          allergen: member.allergen,
          severity: member.severity,
          warningType: warningType,
          matchedSnippet: snippet,
          alertEn: alertEn,
          alertNe: alertNe,
        ));
      }
    }

    return LabelScanResult(
      rawText: rawText,
      detectedAllergens: detectedAllergens.toList(),
      facilityWarnings: facilityWarnings.toList(),
      memberAlerts: memberAlerts,
      isSafeForHousehold: isSafeForHousehold,
      highlightSpans: highlightSpans,
    );
  }
}
