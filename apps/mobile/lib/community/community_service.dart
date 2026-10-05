import 'package:flutter/foundation.dart';
import 'package:kitchen_engine/kitchen_engine.dart';

typedef ApiClientFunction = Future<Map<String, dynamic>> Function(
  String method,
  String path,
  Map<String, dynamic>? body,
);

class CommunityService extends ChangeNotifier {
  final ApiClientFunction? _apiClient;
  final List<CommunityContribution> _localContributions = [];
  bool _isLoading = false;

  CommunityService({this._apiClient});

  bool get isLoading => _isLoading;
  List<CommunityContribution> get contributions => List.unmodifiable(_localContributions);

  /// Submits a new community recipe. Runs on-device pre-screening before network call.
  Future<CommunityContribution> submitRecipe(CommunityRecipePayload payload) async {
    _isLoading = true;
    notifyListeners();

    try {
      if (_apiClient != null) {
        final res = await _apiClient('POST', '/v1/community/contribute/recipe', payload.toJson());
        final contribution = _parseContribution(res);
        _localContributions.insert(0, contribution);
        return contribution;
      }

      // Offline / Local Engine fallback
      final scorecard = CommunityModerationEngine.screenRecipe(payload);
      final status = !scorecard.isSafe
          ? (scorecard.automatedAction == AutomatedAction.autoReject
              ? ContributionStatus.rejected
              : ContributionStatus.flagged)
          : ContributionStatus.autoApproved;

      final contribution = CommunityContribution(
        id: 'local_${DateTime.now().millisecondsSinceEpoch}',
        type: ContributionType.recipe,
        payload: payload.toJson(),
        status: status,
        badge: VerificationBadge.community,
        moderation: scorecard,
        submittedAt: DateTime.now().toIso8601String(),
      );

      _localContributions.insert(0, contribution);
      return contribution;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Submits an ingredient alias suggestion.
  Future<CommunityContribution> submitIngredientAlias(
      CommunityIngredientAliasPayload payload) async {
    _isLoading = true;
    notifyListeners();

    try {
      if (_apiClient != null) {
        final res = await _apiClient(
            'POST', '/v1/community/contribute/ingredient-alias', payload.toJson());
        final contribution = _parseContribution(res);
        _localContributions.insert(0, contribution);
        return contribution;
      }

      final scorecard = CommunityModerationEngine.screenIngredientAlias(payload);
      final status = !scorecard.isSafe
          ? (scorecard.automatedAction == AutomatedAction.autoReject
              ? ContributionStatus.rejected
              : ContributionStatus.flagged)
          : ContributionStatus.autoApproved;

      final contribution = CommunityContribution(
        id: 'local_${DateTime.now().millisecondsSinceEpoch}',
        type: ContributionType.ingredientAlias,
        payload: payload.toJson(),
        status: status,
        badge: VerificationBadge.community,
        moderation: scorecard,
        submittedAt: DateTime.now().toIso8601String(),
      );

      _localContributions.insert(0, contribution);
      return contribution;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Submits a crowdsourced haat bazaar / market price report.
  Future<CommunityContribution> submitPriceReport(
      CommunityPriceReportPayload payload,
      {double? baselineAvgPrice}) async {
    _isLoading = true;
    notifyListeners();

    try {
      if (_apiClient != null) {
        final res = await _apiClient(
            'POST', '/v1/community/contribute/price-report', payload.toJson());
        final contribution = _parseContribution(res);
        _localContributions.insert(0, contribution);
        return contribution;
      }

      final scorecard =
          CommunityModerationEngine.screenPriceReport(payload, baselineAvgPrice);
      final status = !scorecard.isSafe
          ? (scorecard.automatedAction == AutomatedAction.autoReject
              ? ContributionStatus.rejected
              : ContributionStatus.flagged)
          : ContributionStatus.autoApproved;

      final contribution = CommunityContribution(
        id: 'local_${DateTime.now().millisecondsSinceEpoch}',
        type: ContributionType.priceObservation,
        payload: payload.toJson(),
        status: status,
        badge: VerificationBadge.community,
        moderation: scorecard,
        submittedAt: DateTime.now().toIso8601String(),
      );

      _localContributions.insert(0, contribution);
      return contribution;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Human reviewer action to promote to "Verified" or reject.
  Future<CommunityContribution?> reviewContribution({
    required String contributionId,
    required String reviewerId,
    required String decision,
    String? notes,
  }) async {
    final idx = _localContributions.indexWhere((c) => c.id == contributionId);
    if (idx == -1) return null;

    final updated = CommunityModerationEngine.applyHumanReview(
      _localContributions[idx],
      reviewerId: reviewerId,
      decision: decision,
      reviewerNotes: notes,
    );

    _localContributions[idx] = updated;
    notifyListeners();
    return updated;
  }

  CommunityContribution _parseContribution(Map<String, dynamic> json) {
    final modJson = json['moderation'] as Map<String, dynamic>? ?? {};
    final statusStr = json['status'] as String? ?? 'pending';
    final badgeStr = json['badge'] as String? ?? 'community';

    final status = ContributionStatus.values.firstWhere(
      (e) => e.name == statusStr || e.name == _snakeToCamel(statusStr),
      orElse: () => ContributionStatus.pending,
    );

    final badge = VerificationBadge.values.firstWhere(
      (e) => e.name == badgeStr,
      orElse: () => VerificationBadge.community,
    );

    return CommunityContribution(
      id: json['id'] as String? ?? '',
      type: ContributionType.values.firstWhere(
        (e) => e.name == json['type'] || e.name == _snakeToCamel(json['type'] ?? ''),
        orElse: () => ContributionType.recipe,
      ),
      payload: (json['payload'] as Map<String, dynamic>?) ?? {},
      status: status,
      badge: badge,
      moderation: ModerationScorecard(
        isSafe: modJson['isSafe'] as bool? ?? true,
        toxicityScore: (modJson['toxicityScore'] as num?)?.toDouble() ?? 0.0,
        spamScore: (modJson['spamScore'] as num?)?.toDouble() ?? 0.0,
        medicalClaimDetected: modJson['medicalClaimDetected'] as bool? ?? false,
        profanityDetected: modJson['profanityDetected'] as bool? ?? false,
        priceAnomalyDetected: modJson['priceAnomalyDetected'] as bool? ?? false,
        structuralIssues: (modJson['structuralIssues'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        automatedAction: AutomatedAction.values.firstWhere(
          (e) =>
              e.name == modJson['automatedAction'] ||
              e.name == _snakeToCamel(modJson['automatedAction'] ?? ''),
          orElse: () => AutomatedAction.autoApproveCommunity,
        ),
        suggestedBadge: VerificationBadge.values.firstWhere(
          (e) => e.name == modJson['suggestedBadge'],
          orElse: () => VerificationBadge.community,
        ),
        feedbackEn: modJson['feedbackEn'] as String? ?? '',
        feedbackNe: modJson['feedbackNe'] as String? ?? '',
      ),
      submittedAt: json['submittedAt'] as String? ?? DateTime.now().toIso8601String(),
      reviewedAt: json['reviewedAt'] as String?,
      reviewerId: json['reviewerId'] as String?,
      reviewerNotes: json['reviewerNotes'] as String?,
    );
  }

  String _snakeToCamel(String s) {
    final parts = s.split('_');
    if (parts.isEmpty) return s;
    return parts.first +
        parts.skip(1).map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : '').join('');
  }
}
