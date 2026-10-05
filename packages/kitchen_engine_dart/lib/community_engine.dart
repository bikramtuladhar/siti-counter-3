/// Siti Counter 3 - Community Engine (Dart)
/// Section 17 & 20.2: Community contributions, AI screening, moderation scorecards & verification badges.

enum ContributionType {
  recipe,
  ingredientAlias,
  priceObservation,
}

enum ContributionStatus {
  pending,
  screening,
  autoApproved,
  flagged,
  verified,
  rejected,
}

enum VerificationBadge {
  community,
  verified,
}

enum AutomatedAction {
  autoApproveCommunity,
  requireHumanReview,
  autoReject,
}

class CommunityIngredientItem {
  final String nameEn;
  final String nameNe;
  final double quantity;
  final String unit;
  final List<String> allergens;

  const CommunityIngredientItem({
    required this.nameEn,
    required this.nameNe,
    required this.quantity,
    required this.unit,
    this.allergens = const [],
  });

  Map<String, dynamic> toJson() => {
        'nameEn': nameEn,
        'nameNe': nameNe,
        'quantity': quantity,
        'unit': unit,
        'allergens': allergens,
      };

  factory CommunityIngredientItem.fromJson(Map<String, dynamic> json) =>
      CommunityIngredientItem(
        nameEn: json['nameEn'] as String? ?? '',
        nameNe: json['nameNe'] as String? ?? '',
        quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
        unit: json['unit'] as String? ?? '',
        allergens: (json['allergens'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
      );
}

class CommunityRecipeStepItem {
  final int order;
  final String instructionEn;
  final String instructionNe;
  final bool isWhistleStep;
  final int? whistles;
  final int? timerMinutes;

  const CommunityRecipeStepItem({
    required this.order,
    required this.instructionEn,
    required this.instructionNe,
    this.isWhistleStep = false,
    this.whistles,
    this.timerMinutes,
  });

  Map<String, dynamic> toJson() => {
        'order': order,
        'instructionEn': instructionEn,
        'instructionNe': instructionNe,
        'isWhistleStep': isWhistleStep,
        if (whistles != null) 'whistles': whistles,
        if (timerMinutes != null) 'timerMinutes': timerMinutes,
      };

  factory CommunityRecipeStepItem.fromJson(Map<String, dynamic> json) =>
      CommunityRecipeStepItem(
        order: (json['order'] as num?)?.toInt() ?? 1,
        instructionEn: json['instructionEn'] as String? ?? '',
        instructionNe: json['instructionNe'] as String? ?? '',
        isWhistleStep: json['isWhistleStep'] as bool? ?? false,
        whistles: (json['whistles'] as num?)?.toInt(),
        timerMinutes: (json['timerMinutes'] as num?)?.toInt(),
      );
}

class CommunityRecipePayload {
  final String titleEn;
  final String titleNe;
  final String cuisine;
  final int servings;
  final int prepTimeMinutes;
  final int cookTimeMinutes;
  final int? whistleCount;
  final List<CommunityIngredientItem> ingredients;
  final List<CommunityRecipeStepItem> steps;
  final String authorHouseholdId;
  final String authorDisplayName;
  final String? culturalStory;
  final String? photoUrl;

  const CommunityRecipePayload({
    required this.titleEn,
    required this.titleNe,
    required this.cuisine,
    required this.servings,
    required this.prepTimeMinutes,
    required this.cookTimeMinutes,
    this.whistleCount,
    required this.ingredients,
    required this.steps,
    required this.authorHouseholdId,
    required this.authorDisplayName,
    this.culturalStory,
    this.photoUrl,
  });

  Map<String, dynamic> toJson() => {
        'titleEn': titleEn,
        'titleNe': titleNe,
        'cuisine': cuisine,
        'servings': servings,
        'prepTimeMinutes': prepTimeMinutes,
        'cookTimeMinutes': cookTimeMinutes,
        if (whistleCount != null) 'whistleCount': whistleCount,
        'ingredients': ingredients.map((e) => e.toJson()).toList(),
        'steps': steps.map((e) => e.toJson()).toList(),
        'authorHouseholdId': authorHouseholdId,
        'authorDisplayName': authorDisplayName,
        if (culturalStory != null) 'culturalStory': culturalStory,
        if (photoUrl != null) 'photoUrl': photoUrl,
      };

  factory CommunityRecipePayload.fromJson(Map<String, dynamic> json) =>
      CommunityRecipePayload(
        titleEn: json['titleEn'] as String? ?? '',
        titleNe: json['titleNe'] as String? ?? '',
        cuisine: json['cuisine'] as String? ?? 'Nepali',
        servings: (json['servings'] as num?)?.toInt() ?? 4,
        prepTimeMinutes: (json['prepTimeMinutes'] as num?)?.toInt() ?? 15,
        cookTimeMinutes: (json['cookTimeMinutes'] as num?)?.toInt() ?? 20,
        whistleCount: (json['whistleCount'] as num?)?.toInt(),
        ingredients: (json['ingredients'] as List<dynamic>?)
                ?.map((e) =>
                    CommunityIngredientItem.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        steps: (json['steps'] as List<dynamic>?)
                ?.map((e) => CommunityRecipeStepItem.fromJson(
                    e as Map<String, dynamic>))
                .toList() ??
            const [],
        authorHouseholdId: json['authorHouseholdId'] as String? ?? '',
        authorDisplayName: json['authorDisplayName'] as String? ?? '',
        culturalStory: json['culturalStory'] as String?,
        photoUrl: json['photoUrl'] as String?,
      );
}

class CommunityIngredientAliasPayload {
  final String canonicalIngredientId;
  final String dialectRegion;
  final String aliasEn;
  final String aliasNe;
  final String? notes;
  final String authorHouseholdId;
  final String authorDisplayName;

  const CommunityIngredientAliasPayload({
    required this.canonicalIngredientId,
    required this.dialectRegion,
    required this.aliasEn,
    required this.aliasNe,
    this.notes,
    required this.authorHouseholdId,
    required this.authorDisplayName,
  });

  Map<String, dynamic> toJson() => {
        'canonicalIngredientId': canonicalIngredientId,
        'dialectRegion': dialectRegion,
        'aliasEn': aliasEn,
        'aliasNe': aliasNe,
        if (notes != null) 'notes': notes,
        'authorHouseholdId': authorHouseholdId,
        'authorDisplayName': authorDisplayName,
      };

  factory CommunityIngredientAliasPayload.fromJson(Map<String, dynamic> json) =>
      CommunityIngredientAliasPayload(
        canonicalIngredientId: json['canonicalIngredientId'] as String? ?? '',
        dialectRegion: json['dialectRegion'] as String? ?? '',
        aliasEn: json['aliasEn'] as String? ?? '',
        aliasNe: json['aliasNe'] as String? ?? '',
        notes: json['notes'] as String?,
        authorHouseholdId: json['authorHouseholdId'] as String? ?? '',
        authorDisplayName: json['authorDisplayName'] as String? ?? '',
      );
}

class CommunityPriceReportPayload {
  final String commodityId;
  final String commodityNameEn;
  final String commodityNameNe;
  final String marketName;
  final String marketType;
  final double observedPrice;
  final String unit;
  final String district;
  final String reporterHouseholdId;
  final String reporterDisplayName;

  const CommunityPriceReportPayload({
    required this.commodityId,
    required this.commodityNameEn,
    required this.commodityNameNe,
    required this.marketName,
    required this.marketType,
    required this.observedPrice,
    this.unit = 'kg',
    required this.district,
    required this.reporterHouseholdId,
    required this.reporterDisplayName,
  });

  Map<String, dynamic> toJson() => {
        'commodityId': commodityId,
        'commodityNameEn': commodityNameEn,
        'commodityNameNe': commodityNameNe,
        'marketName': marketName,
        'marketType': marketType,
        'observedPrice': observedPrice,
        'unit': unit,
        'district': district,
        'reporterHouseholdId': reporterHouseholdId,
        'reporterDisplayName': reporterDisplayName,
      };

  factory CommunityPriceReportPayload.fromJson(Map<String, dynamic> json) =>
      CommunityPriceReportPayload(
        commodityId: json['commodityId'] as String? ?? '',
        commodityNameEn: json['commodityNameEn'] as String? ?? '',
        commodityNameNe: json['commodityNameNe'] as String? ?? '',
        marketName: json['marketName'] as String? ?? '',
        marketType: json['marketType'] as String? ?? 'haat_bazaar',
        observedPrice: (json['observedPrice'] as num?)?.toDouble() ?? 0.0,
        unit: json['unit'] as String? ?? 'kg',
        district: json['district'] as String? ?? 'Kathmandu',
        reporterHouseholdId: json['reporterHouseholdId'] as String? ?? '',
        reporterDisplayName: json['reporterDisplayName'] as String? ?? '',
      );
}

class ModerationScorecard {
  final bool isSafe;
  final double toxicityScore;
  final double spamScore;
  final bool medicalClaimDetected;
  final bool profanityDetected;
  final bool priceAnomalyDetected;
  final List<String> structuralIssues;
  final AutomatedAction automatedAction;
  final VerificationBadge suggestedBadge;
  final String feedbackEn;
  final String feedbackNe;

  const ModerationScorecard({
    required this.isSafe,
    this.toxicityScore = 0.0,
    this.spamScore = 0.0,
    this.medicalClaimDetected = false,
    this.profanityDetected = false,
    this.priceAnomalyDetected = false,
    this.structuralIssues = const [],
    required this.automatedAction,
    required this.suggestedBadge,
    required this.feedbackEn,
    required this.feedbackNe,
  });

  Map<String, dynamic> toJson() => {
        'isSafe': isSafe,
        'toxicityScore': toxicityScore,
        'spamScore': spamScore,
        'medicalClaimDetected': medicalClaimDetected,
        'profanityDetected': profanityDetected,
        'priceAnomalyDetected': priceAnomalyDetected,
        'structuralIssues': structuralIssues,
        'automatedAction': automatedAction.name,
        'suggestedBadge': suggestedBadge.name,
        'feedbackEn': feedbackEn,
        'feedbackNe': feedbackNe,
      };
}

class CommunityContribution {
  final String id;
  final ContributionType type;
  final Map<String, dynamic> payload;
  final ContributionStatus status;
  final VerificationBadge badge;
  final ModerationScorecard moderation;
  final String submittedAt;
  final String? reviewedAt;
  final String? reviewerId;
  final String? reviewerNotes;

  const CommunityContribution({
    required this.id,
    required this.type,
    required this.payload,
    required this.status,
    required this.badge,
    required this.moderation,
    required this.submittedAt,
    this.reviewedAt,
    this.reviewerId,
    this.reviewerNotes,
  });

  CommunityContribution copyWith({
    ContributionStatus? status,
    VerificationBadge? badge,
    String? reviewedAt,
    String? reviewerId,
    String? reviewerNotes,
  }) =>
      CommunityContribution(
        id: id,
        type: type,
        payload: payload,
        status: status ?? this.status,
        badge: badge ?? this.badge,
        moderation: moderation,
        submittedAt: submittedAt,
        reviewedAt: reviewedAt ?? this.reviewedAt,
        reviewerId: reviewerId ?? this.reviewerId,
        reviewerNotes: reviewerNotes ?? this.reviewerNotes,
      );
}

class CommunityModerationEngine {
  static const List<String> _bannedKeywords = [
    'scam',
    'fake',
    'casino',
    'viagra',
    'crypto',
    'hack',
    'terro',
    'f***',
    'asshole',
    'bullshit',
  ];

  static final List<RegExp> _medicalClaimPatterns = [
    RegExp(r'cures\s+cancer', caseSensitive: false),
    RegExp(r'cures\s+diabetes', caseSensitive: false),
    RegExp(r'prevents\s+covid', caseSensitive: false),
    RegExp(r'रोग\s*निको\s*पार्छ'),
    RegExp(r'क्यान्सर\s*निको'),
    RegExp(r'मधुमेह\s*निको'),
    RegExp(r'औषधि\s*हो'),
  ];

  /// Screens a recipe contribution for completeness, food safety, spam, and medical claims.
  static ModerationScorecard screenRecipe(CommunityRecipePayload payload) {
    final issues = <String>[];
    double toxicityScore = 0.0;
    double spamScore = 0.0;
    bool medicalClaim = false;
    bool profanity = false;

    if (payload.titleEn.trim().isEmpty && payload.titleNe.trim().isEmpty) {
      issues.add('Recipe title is required in English or Nepali');
    }
    if (payload.ingredients.isEmpty) {
      issues.add('At least one ingredient is required');
    }
    if (payload.steps.isEmpty) {
      issues.add('At least one preparation or cooking step is required');
    }
    if (payload.servings < 1 || payload.servings > 100) {
      issues.add('Servings must be between 1 and 100');
    }
    if (payload.cookTimeMinutes < 0 || payload.cookTimeMinutes > 480) {
      issues.add('Cook time must be reasonable (0 to 480 minutes)');
    }

    final combinedText = [
      payload.titleEn,
      payload.titleNe,
      payload.culturalStory ?? '',
      ...payload.steps.map((s) => '${s.instructionEn} ${s.instructionNe}'),
      ...payload.ingredients.map((i) => '${i.nameEn} ${i.nameNe}'),
    ].join(' ').toLowerCase();

    for (final kw in _bannedKeywords) {
      if (combinedText.contains(kw.toLowerCase())) {
        profanity = true;
        toxicityScore = 0.9;
        issues.add('Prohibited word detected: "$kw"');
        break;
      }
    }

    for (final pat in _medicalClaimPatterns) {
      if (pat.hasMatch(combinedText)) {
        medicalClaim = true;
        toxicityScore = toxicityScore > 0.7 ? toxicityScore : 0.7;
        issues.add('Unverified medical cure or treatment claims are strictly prohibited.');
        break;
      }
    }

    if (RegExp(r'https?://', caseSensitive: false).hasMatch(combinedText)) {
      spamScore += 0.6;
      issues.add('External hyperlinks in recipe instructions are flagged for spam prevention');
    }

    final isSafe = !profanity && !medicalClaim && issues.isEmpty;
    AutomatedAction automatedAction = AutomatedAction.autoApproveCommunity;
    VerificationBadge suggestedBadge = VerificationBadge.community;

    if (profanity || medicalClaim || toxicityScore > 0.6 || spamScore > 0.7) {
      automatedAction = AutomatedAction.autoReject;
    } else if (issues.isNotEmpty || spamScore > 0.3) {
      automatedAction = AutomatedAction.requireHumanReview;
    } else {
      if (payload.culturalStory != null &&
          payload.culturalStory!.length > 50 &&
          payload.steps.length >= 3) {
        suggestedBadge = VerificationBadge.community;
        automatedAction = AutomatedAction.autoApproveCommunity;
      }
    }

    final feedbackEn = isSafe
        ? 'Recipe passed automated safety screening. Published as Community recipe!'
        : 'Recipe requires attention: ${issues.join('; ')}';

    final feedbackNe = isSafe
        ? 'रेसिपी स्वचालित सुरक्षा जाँचमा उत्तीर्ण भयो। सामुदायिक रेसिपीको रूपमा प्रकाशित भयो!'
        : 'रेसिपीमा सुधार आवश्यक छ: ${issues.join('; ')}';

    return ModerationScorecard(
      isSafe: isSafe,
      toxicityScore: toxicityScore,
      spamScore: spamScore,
      medicalClaimDetected: medicalClaim,
      profanityDetected: profanity,
      priceAnomalyDetected: false,
      structuralIssues: issues,
      automatedAction: automatedAction,
      suggestedBadge: suggestedBadge,
      feedbackEn: feedbackEn,
      feedbackNe: feedbackNe,
    );
  }

  /// Screens regional ingredient alias suggestions.
  static ModerationScorecard screenIngredientAlias(
      CommunityIngredientAliasPayload payload) {
    final issues = <String>[];
    bool profanity = false;
    bool spam = false;

    if (payload.canonicalIngredientId.trim().isEmpty) {
      issues.add('Canonical ingredient ID is required');
    }
    if (payload.aliasEn.trim().isEmpty && payload.aliasNe.trim().isEmpty) {
      issues.add('Alias name must be provided in English or Nepali');
    }
    if (payload.dialectRegion.trim().isEmpty) {
      issues.add('Dialect region or cultural community is required');
    }

    final text =
        '${payload.aliasEn} ${payload.aliasNe} ${payload.notes ?? ''}'.toLowerCase();

    for (final kw in _bannedKeywords) {
      if (text.contains(kw)) {
        profanity = true;
        issues.add('Prohibited word in alias: "$kw"');
        break;
      }
    }

    if (text.length > 200 || RegExp(r'https?://', caseSensitive: false).hasMatch(text)) {
      spam = true;
      issues.add('Alias text is unusually long or contains links');
    }

    final isSafe = !profanity && !spam && issues.isEmpty;
    final automatedAction = profanity
        ? AutomatedAction.autoReject
        : (isSafe
            ? AutomatedAction.autoApproveCommunity
            : AutomatedAction.requireHumanReview);

    return ModerationScorecard(
      isSafe: isSafe,
      toxicityScore: profanity ? 0.9 : 0.0,
      spamScore: spam ? 0.8 : 0.0,
      medicalClaimDetected: false,
      profanityDetected: profanity,
      priceAnomalyDetected: false,
      structuralIssues: issues,
      automatedAction: automatedAction,
      suggestedBadge: VerificationBadge.community,
      feedbackEn: isSafe ? 'Ingredient alias accepted.' : issues.join('; '),
      feedbackNe:
          isSafe ? 'सामग्रीको स्थानीय नाम स्वीकार गरियो।' : issues.join('; '),
    );
  }

  /// Screens crowdsourced price sightings against Kalimati baseline price bounds.
  static ModerationScorecard screenPriceReport(
    CommunityPriceReportPayload payload, [
    double? baselineAvgPrice,
  ]) {
    final issues = <String>[];
    bool priceAnomaly = false;

    if (payload.commodityId.trim().isEmpty) {
      issues.add('Commodity ID is required');
    }
    if (payload.observedPrice <= 0) {
      issues.add('Observed price must be greater than zero');
    }
    if (payload.marketName.trim().isEmpty) {
      issues.add('Market name is required');
    }

    if (baselineAvgPrice != null &&
        baselineAvgPrice > 0 &&
        payload.observedPrice > 0) {
      final ratio = payload.observedPrice / baselineAvgPrice;
      if (ratio > 5.0 || ratio < 0.15) {
        priceAnomaly = true;
        issues.add(
            'Price anomaly detected: NPR ${payload.observedPrice} is far outside baseline wholesale average of NPR $baselineAvgPrice');
      }
    }

    final isSafe = issues.isEmpty;
    final automatedAction = priceAnomaly
        ? AutomatedAction.requireHumanReview
        : (isSafe
            ? AutomatedAction.autoApproveCommunity
            : AutomatedAction.autoReject);

    return ModerationScorecard(
      isSafe: !priceAnomaly && isSafe,
      toxicityScore: 0.0,
      spamScore: 0.0,
      medicalClaimDetected: false,
      profanityDetected: false,
      priceAnomalyDetected: priceAnomaly,
      structuralIssues: issues,
      automatedAction: automatedAction,
      suggestedBadge: VerificationBadge.community,
      feedbackEn: isSafe
          ? 'Market price sighting approved.'
          : (priceAnomaly
              ? 'Price differs substantially from market baseline. Sent for verification.'
              : issues.join('; ')),
      feedbackNe: isSafe
          ? 'बजार मूल्य रिपोर्ट स्वीकृत भयो।'
          : (priceAnomaly
              ? 'मूल्य बजारको औसतभन्दा धेरै फरक छ। समीक्षाको लागि पठाइयो।'
              : issues.join('; ')),
    );
  }

  /// Applies human moderation review to promote to "Verified" or "Community".
  static CommunityContribution applyHumanReview(
    CommunityContribution currentContribution, {
    required String reviewerId,
    required String decision, // 'promote_to_verified', 'approve_community', 'reject'
    String? reviewerNotes,
  }) {
    ContributionStatus newStatus = currentContribution.status;
    VerificationBadge newBadge = currentContribution.badge;

    switch (decision) {
      case 'promote_to_verified':
        newStatus = ContributionStatus.verified;
        newBadge = VerificationBadge.verified;
        break;
      case 'approve_community':
        newStatus = ContributionStatus.autoApproved;
        newBadge = VerificationBadge.community;
        break;
      case 'request_changes':
        newStatus = ContributionStatus.flagged;
        break;
      case 'reject':
        newStatus = ContributionStatus.rejected;
        break;
    }

    return currentContribution.copyWith(
      status: newStatus,
      badge: newBadge,
      reviewedAt: DateTime.now().toIso8601String(),
      reviewerId: reviewerId,
      reviewerNotes: reviewerNotes,
    );
  }
}
