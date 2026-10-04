import 'package:flutter/material.dart';
import 'package:kitchen_engine/waste_engine.dart';
import '../theme/tokens.dart';
import '../theme/nepali_typography.dart';
import 'consumption_repository.dart';

/// Leftover tracking ("Eat first") and recurring food waste analytics screen (Sections 8.4, 11.3).
class LeftoverScreen extends StatefulWidget {
  final String currentLanguage;
  final ConsumptionRepository repository;
  final DateTime? now;

  const LeftoverScreen({
    super.key,
    required this.currentLanguage,
    required this.repository,
    this.now,
  });

  @override
  State<LeftoverScreen> createState() => _LeftoverScreenState();
}

class _LeftoverScreenState extends State<LeftoverScreen> {
  bool _loading = true;
  List<TrackedLeftover> _leftovers = [];
  HouseholdWasteSummary? _summary;
  List<WasteInsight> _insights = [];

  bool get _isNepali => widget.currentLanguage == 'ne';
  DateTime get _currentTime => widget.now ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final leftovers = await widget.repository.getTrackedLeftovers(activeOnly: false);
    final summary = await widget.repository.getWasteSummary(now: _currentTime);
    final insights = await widget.repository.getWasteInsights(now: _currentTime);

    if (mounted) {
      setState(() {
        _leftovers = leftovers;
        _summary = summary;
        _insights = insights;
        _loading = false;
      });
    }
  }

  Future<void> _markConsumed(TrackedLeftover leftover) async {
    await widget.repository.markLeftoverConsumed(leftover.id, _currentTime);
    await _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isNepali
              ? '${leftover.titleNe} खाइयो: खाना बचत भयो ✓'
              : 'Marked ${leftover.titleEn} as consumed: food saved ✓',
          ),
          backgroundColor: SitiColors.freshGreen,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _markDiscarded(TrackedLeftover leftover) async {
    await widget.repository.markLeftoverDiscarded(leftover.id, 'expired');
    await _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isNepali ? 'हटाउनुभयो' : 'Item removed',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(_isNepali ? 'बाँकी खाना र बचत' : 'Leftovers & Waste')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final activeLeftovers = _leftovers.where((l) => !l.isConsumed && !l.isDiscarded).toList();
    final eatFirstList = activeLeftovers.where((l) => l.isEatFirst(_currentTime)).toList();
    final otherActiveList = activeLeftovers.where((l) => !l.isEatFirst(_currentTime)).toList();

    return Scaffold(
      backgroundColor: SitiColors.warmWhite,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _isNepali ? 'बाँकी खाना (Eat First)' : 'Leftovers ("Eat First")',
          style: NepaliTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
            color: SitiColors.dark,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Gentle Non-Shaming Waste Summary Card
              if (_summary != null) _buildSummaryCard(_summary!),
              const SizedBox(height: 16),

              // "Eat First" Section
              if (eatFirstList.isNotEmpty) ...[
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.priority_high_rounded, color: Colors.red.shade700, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            _isNepali ? 'पहिले खानुहोस् (Eat First)' : 'Eat First',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.red.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ...eatFirstList.map((item) => _buildLeftoverCard(item, isPriority: true)),
                const SizedBox(height: 16),
              ],

              // Other Fresh Stored Leftovers
              if (otherActiveList.isNotEmpty) ...[
                Text(
                  _isNepali ? 'सुरक्षित भण्डारण गरिएका परिकार' : 'Freshly Stored Dishes',
                  style: NepaliTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: SitiColors.dark,
                  ),
                ),
                const SizedBox(height: 10),
                ...otherActiveList.map((item) => _buildLeftoverCard(item, isPriority: false)),
                const SizedBox(height: 16),
              ],

              if (activeLeftovers.isEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.kitchen_rounded, size: 40, color: Colors.grey.shade400),
                      const SizedBox(height: 8),
                      Text(
                        _isNepali ? 'फ्रिजमा कुनै बाँकी खाना छैन' : 'No leftovers in fridge',
                        style: NepaliTypography.titleSmall.copyWith(
                          fontWeight: FontWeight.w700,
                          color: SitiColors.dark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isNepali
                            ? 'खाना पकाउँदा बढी भएमा स्वतः यहाँ दर्ता हुनेछ।'
                            : 'Leftovers will automatically appear here when excess food is logged.',
                        style: NepaliTypography.bodySmall.copyWith(color: Colors.grey.shade600),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Recurring Waste Analytics Insights
              if (_insights.isNotEmpty) ...[
                Text(
                  _isNepali ? 'खाना बचत अन्तर्दृष्टि' : 'Food Waste Prevention Insights',
                  style: NepaliTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: SitiColors.dark,
                  ),
                ),
                const SizedBox(height: 10),
                ..._insights.map((insight) => _buildInsightCard(insight)),
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(HouseholdWasteSummary summary) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: SitiColors.freshGreen.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.recycling_rounded, color: SitiColors.freshGreen, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _isNepali ? 'भान्साको खाना बचत लय' : 'Kitchen Waste Prevention',
                  style: NepaliTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: SitiColors.dark,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${summary.wastePreventionRate.round()}% ${_isNepali ? 'बचत दर' : 'saved'}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _isNepali ? summary.gentleFeedbackNe : summary.gentleFeedbackEn,
            style: NepaliTypography.bodyMedium.copyWith(
              color: SitiColors.dark,
              height: 1.4,
            ),
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetricColumn(
                label: _isNepali ? 'बाँकी परिकार' : 'Active Leftovers',
                value: '${summary.activeLeftoversCount}',
                color: SitiColors.terracotta,
              ),
              Container(width: 1, height: 28, color: Colors.grey.shade200),
              _buildMetricColumn(
                label: _isNepali ? 'पहिले खानुपर्ने' : 'Eat First',
                value: '${summary.eatFirstCount}',
                color: summary.eatFirstCount > 0 ? Colors.red.shade700 : SitiColors.dark,
              ),
              Container(width: 1, height: 28, color: Colors.grey.shade200),
              _buildMetricColumn(
                label: _isNepali ? 'बचत भएको' : 'Food Saved',
                value: '${summary.totalGramsSaved.round()} g',
                color: SitiColors.freshGreen,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricColumn({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: NepaliTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: NepaliTypography.bodySmall.copyWith(
            color: Colors.grey.shade600,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildLeftoverCard(TrackedLeftover item, {required bool isPriority}) {
    final urgency = item.getUrgency(_currentTime);
    final remainingMinutes = item.useByDate.difference(_currentTime).inMinutes;
    final remainingHours = item.useByDate.difference(_currentTime).inHours;

    Color badgeBg;
    Color badgeText;
    String badgeLabel;

    if (urgency == LeftoverUrgency.expired) {
      badgeBg = Colors.red.shade100;
      badgeText = Colors.red.shade900;
      badgeLabel = _isNepali ? 'समय नाघ्यो' : 'Expired';
    } else if (urgency == LeftoverUrgency.urgent) {
      badgeBg = Colors.orange.shade100;
      badgeText = Colors.orange.shade900;
      badgeLabel = _isNepali
          ? '$remainingMinutes मिनेट बाँकी'
          : '$remainingMinutes min left';
    } else if (urgency == LeftoverUrgency.eatSoon) {
      badgeBg = Colors.amber.shade100;
      badgeText = Colors.amber.shade900;
      badgeLabel = _isNepali
          ? '$remainingHours घण्टा बाँकी'
          : '$remainingHours hrs left';
    } else {
      badgeBg = Colors.green.shade50;
      badgeText = Colors.green.shade800;
      badgeLabel = _isNepali ? 'ताजा' : 'Fresh';
    }

    final isRefrig = item.storageCondition == StorageCondition.refrigerated;

    return Container(
      key: Key('leftover_card_${item.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPriority ? Colors.orange.shade300 : Colors.grey.shade200,
          width: isPriority ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isPriority
                      ? Colors.orange.shade50
                      : SitiColors.terracotta.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.rice_bowl_rounded,
                  color: isPriority ? Colors.orange.shade800 : SitiColors.terracotta,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isNepali ? item.titleNe : item.titleEn,
                      style: NepaliTypography.bodyLarge.copyWith(
                        fontWeight: FontWeight.w700,
                        color: SitiColors.dark,
                      ),
                    ),
                    Text(
                      '~${item.remainingGrams.round()} g (${item.servingsRemaining} ${_isNepali ? 'भाग' : 'servings'})',
                      style: NepaliTypography.bodySmall.copyWith(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badgeLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: badgeText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Storage condition & gentle warning
          Row(
            children: [
              Icon(
                isRefrig ? Icons.ac_unit_rounded : Icons.wb_sunny_rounded,
                size: 14,
                color: isRefrig ? Colors.blue.shade700 : Colors.orange.shade700,
              ),
              const SizedBox(width: 4),
              Text(
                isRefrig
                    ? (_isNepali ? 'फ्रिजमा राखिएको' : 'Refrigerated')
                    : (_isNepali ? 'कोठाको तापक्रममा' : 'Room Temperature'),
                style: NepaliTypography.labelSmall.copyWith(color: Colors.grey.shade700),
              ),
              const Spacer(),
              // Quick action buttons: Consumed or Discard
              TextButton(
                key: Key('discard_button_${item.id}'),
                onPressed: () => _markDiscarded(item),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey.shade600,
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(_isNepali ? 'हटाउने' : 'Discard'),
              ),
              ElevatedButton(
                key: Key('consumed_button_${item.id}'),
                onPressed: () => _markConsumed(item),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SitiColors.freshGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(_isNepali ? 'खाइयो ✓' : 'Ate it ✓'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard(WasteInsight insight) {
    return Container(
      key: Key('waste_insight_${insight.recipeId}_${insight.dayOfWeek}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.lightbulb_outline_rounded, color: Colors.amber.shade900, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isNepali ? insight.insightNe : insight.insightEn,
                  style: NepaliTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.brown.shade900,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _isNepali
                      ? 'अनुमानित बचत: रु ${insight.estimatedMonthlySavingsNpr.round()} प्रति महिना'
                      : 'Estimated monthly savings: NPR ${insight.estimatedMonthlySavingsNpr.round()}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.brown.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
