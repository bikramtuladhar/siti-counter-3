import 'package:flutter/material.dart';
import 'package:kitchen_engine/crew_engine.dart';
import '../theme/nepali_typography.dart';
import '../theme/tokens.dart';
import 'crew_repository.dart';

/// Screen displaying the fair-share cooking rota summary and celebrating household teamwork without guilt.
class FairShareScreen extends StatefulWidget {
  final CrewRepository repository;
  final String currentLanguage;
  final FairShareSummary? initialSummary;

  const FairShareScreen({
    super.key,
    required this.repository,
    required this.currentLanguage,
    this.initialSummary,
  });

  @override
  State<FairShareScreen> createState() => _FairShareScreenState();
}

class _FairShareScreenState extends State<FairShareScreen> {
  FairShareSummary? _summary;
  bool _loading = true;

  bool get _isNepali => widget.currentLanguage == 'ne';

  @override
  void initState() {
    super.initState();
    if (widget.initialSummary != null) {
      _summary = widget.initialSummary;
      _loading = false;
    } else {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final summary = await widget.repository.getFairShareSummary();
    if (mounted) {
      setState(() {
        _summary = summary;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isNepali ? 'भान्सा सहकार्य र योगदान' : 'Cooking Crew & Fair-Share Rota',
          style: NepaliTypography.headlineMedium.copyWith(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: SitiColors.dark,
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF9F7F4),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: SitiColors.terracotta))
          : _summary == null
              ? const SizedBox.shrink()
              : RefreshIndicator(
                  onRefresh: _loadData,
                  color: SitiColors.terracotta,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    children: [
                      _buildCelebratoryHeader(_summary!),
                      const SizedBox(height: 16),
                      _buildTeamworkInsightCard(_summary!),
                      const SizedBox(height: 20),
                      Text(
                        _isNepali ? 'सदस्यहरूको योगदान र सम्मान' : 'Household Contributions',
                        style: NepaliTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: SitiColors.dark,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._summary!.memberSummaries.map(_buildMemberCard),
                      const SizedBox(height: 20),
                      _buildRotationTipCard(_summary!),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
    );
  }

  Widget _buildCelebratoryHeader(FairShareSummary summary) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            SitiColors.terracotta.withAlpha(230),
            const Color(0xFFE65100),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: SitiColors.terracotta.withAlpha(40),
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
              const Icon(Icons.celebration_rounded, color: Colors.amber, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  summary.celebratoryHeadline,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatPill(
                icon: Icons.soup_kitchen_rounded,
                value: '${summary.totalSessions}',
                label: _isNepali ? 'साझा भोजन' : 'Crew Meals',
              ),
              const SizedBox(width: 12),
              _buildStatPill(
                icon: Icons.task_alt_rounded,
                value: '${summary.totalTasksCompleted}',
                label: _isNepali ? 'पूरा कार्य' : 'Tasks Done',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(50),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withAlpha(220),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamworkInsightCard(FairShareSummary summary) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.favorite_rounded, color: Colors.amber, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isNepali ? 'सद्भाव र एकता' : 'Teamwork Harmony',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: SitiColors.dark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  summary.teamworkInsight,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberCard(MemberContributionSummary member) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: SitiColors.terracotta.withAlpha(30),
                child: Text(
                  member.memberName.isNotEmpty ? member.memberName[0] : '?',
                  style: const TextStyle(
                    color: SitiColors.terracotta,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.memberName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: SitiColors.dark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        member.celebratoryBadge,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.brown.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${member.totalTasksCompleted}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: SitiColors.terracotta,
                    ),
                  ),
                  Text(
                    _isNepali ? 'कार्यहरू' : 'tasks',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: member.tasksByType.entries
                .where((e) => e.value > 0)
                .map((e) => Chip(
                      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: Colors.grey.shade100,
                      avatar: CircleAvatar(
                        radius: 10,
                        backgroundColor: SitiColors.terracotta,
                        child: Text(
                          '${e.value}',
                          style: const TextStyle(color: Colors.white, fontSize: 10),
                        ),
                      ),
                      label: Text(
                        _isNepali ? e.key.labelNe : e.key.labelEn,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRotationTipCard(FairShareSummary summary) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F8E9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDCEDC8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline_rounded, color: Color(0xFF558B2F), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isNepali ? 'अर्को पटकको रमाइलो सुझाव' : 'Joyful Rotation Tip',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF33691E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  summary.rotationSuggestion,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF33691E),
                    height: 1.3,
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
