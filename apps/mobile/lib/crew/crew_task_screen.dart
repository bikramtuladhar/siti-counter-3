import 'package:flutter/material.dart';
import 'package:kitchen_engine/crew_engine.dart';
import 'package:kitchen_engine/region_pack.dart';
import '../screens/active_cooking_session_screen.dart';
import '../screens/recipe_detail_screen.dart' show CooktopType;
import '../theme/nepali_typography.dart';
import '../theme/tokens.dart';
import 'crew_repository.dart';
import 'fair_share_screen.dart';

/// Screen for parallel task splitting, crew assignment, and lead cook invitation (Section 12.6, Issue #29).
class CrewTaskScreen extends StatefulWidget {
  final RegionRecipe recipe;
  final CrewRepository repository;
  final String currentLanguage;
  final CooktopType cooktop;
  final List<MemberCrewProfile>? initialCrew;
  final List<CookTask>? initialTasks;

  const CrewTaskScreen({
    super.key,
    required this.recipe,
    required this.repository,
    this.currentLanguage = 'en',
    this.cooktop = CooktopType.lpgGas,
    this.initialCrew,
    this.initialTasks,
  });

  @override
  State<CrewTaskScreen> createState() => _CrewTaskScreenState();
}

class _CrewTaskScreenState extends State<CrewTaskScreen> {
  List<MemberCrewProfile> _crew = [];
  List<CookTask> _tasks = [];
  String _invitationPrompt = '';
  MemberCrewProfile? _leadCook;
  bool _loading = true;

  bool get _isNepali => widget.currentLanguage == 'ne';

  @override
  void initState() {
    super.initState();
    if (widget.initialTasks != null && widget.initialCrew != null) {
      _crew = widget.initialCrew!;
      _tasks = widget.initialTasks!;
      _leadCook = _crew.isNotEmpty ? _crew.first : null;
      _updateInvitation();
      _loading = false;
    } else {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final crew = await widget.repository.getCrewProfiles();
    final history = await widget.repository.getContributionHistory();

    final splitTasks = CrewEngine.splitRecipe(recipe: widget.recipe);
    final lead = crew.isNotEmpty ? crew.first : null;

    final assignedTasks = CrewEngine.assignTasks(
      tasks: splitTasks,
      crew: crew,
      leadCookMemberId: lead?.memberId,
      history: history,
    );

    if (mounted) {
      setState(() {
        _crew = crew;
        _tasks = assignedTasks;
        _leadCook = lead;
        _updateInvitation();
        _loading = false;
      });
    }
  }

  void _updateInvitation() {
    if (_leadCook != null && _crew.isNotEmpty) {
      _invitationPrompt = CrewEngine.generateInvitationPrompt(
        recipe: widget.recipe,
        leadCook: _leadCook!,
        crew: _crew,
        assignedTasks: _tasks,
      );
    } else {
      _invitationPrompt = 'Ready to cook ${widget.recipe.titleEn} together!';
    }
  }

  void _changeAssignee(CookTask task, MemberCrewProfile newMember) {
    setState(() {
      task.assignedMemberId = newMember.memberId;
      task.assignedMemberName = newMember.name;
      _updateInvitation();
    });
  }

  void _toggleTaskStatus(CookTask task) {
    setState(() {
      if (task.status == TaskStatus.pending) {
        task.status = TaskStatus.inProgress;
      } else if (task.status == TaskStatus.inProgress) {
        task.status = TaskStatus.completed;
      } else {
        task.status = TaskStatus.pending;
      }
    });

    if (task.status == TaskStatus.completed && task.assignedMemberId != null) {
      // Log contribution record to SQLite
      widget.repository.logContribution(
        RotaContributionRecord(
          id: '${task.id}_${DateTime.now().millisecondsSinceEpoch}',
          sessionId: 'session_${widget.recipe.id}_${DateTime.now().day}',
          recipeId: widget.recipe.id,
          memberId: task.assignedMemberId!,
          memberName: task.assignedMemberName ?? 'Crew Member',
          taskType: task.taskType,
          role: task.assignedMemberId == _leadCook?.memberId ? 'leadCook' : 'coCook',
          completedAt: DateTime.now(),
          durationMinutes: task.estimatedMinutes,
        ),
      );
    }
  }

  void _startActiveCooking() {
    final effectiveWhistles = widget.recipe.pressureCooker.enabled
        ? widget.recipe.pressureCooker.recommendedWhistles + widget.cooktop.whistleAdjustment
        : 0;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ActiveCookingSessionScreen(
          recipe: widget.recipe,
          targetWhistles: effectiveWhistles,
          cooktop: widget.cooktop,
          currentLanguage: widget.currentLanguage,
        ),
      ),
    );
  }

  void _openFairShareScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FairShareScreen(
          repository: widget.repository,
          currentLanguage: widget.currentLanguage,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isNepali ? 'सह-भोजन र कार्य विभाजन' : 'Co-Cooking Crew Tasks',
          style: NepaliTypography.headlineMedium.copyWith(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: SitiColors.dark,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.stars_rounded, color: Colors.amber),
            tooltip: _isNepali ? 'सहकार्य इतिहास' : 'Fair-Share Rota',
            onPressed: _openFairShareScreen,
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF9F7F4),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: SitiColors.terracotta))
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              children: [
                _buildInvitationBanner(),
                const SizedBox(height: 16),
                _buildCrewPillsRow(),
                const SizedBox(height: 20),
                _buildSectionHeader(_isNepali ? '१. पूर्व तयारी (Prep)' : '1. Prep Tasks (Wash, Chop, Grind)'),
                const SizedBox(height: 8),
                ..._tasks
                    .where((t) => t.taskType == TaskType.washChop || t.taskType == TaskType.grindMasala)
                    .map(_buildTaskCard),
                const SizedBox(height: 16),
                _buildSectionHeader(_isNepali ? '२. मुख्य पकाउने (Cooking & Whistles)' : '2. Active Cooking & Whistles'),
                const SizedBox(height: 8),
                ..._tasks
                    .where((t) =>
                        t.taskType == TaskType.watchCooker ||
                        t.taskType == TaskType.rollRotis ||
                        t.taskType == TaskType.simmerStir)
                    .map(_buildTaskCard),
                const SizedBox(height: 16),
                _buildSectionHeader(_isNepali ? '३. सफा र थाल लगाउने (Clean-up & Table)' : '3. Clean-up & Table Prep'),
                const SizedBox(height: 8),
                ..._tasks.where((t) => t.taskType == TaskType.cleanUp).map(_buildTaskCard),
                const SizedBox(height: 24),
                _buildActionButtons(),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildInvitationBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFCC80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.waving_hand_rounded, color: Color(0xFFE65100), size: 22),
              const SizedBox(width: 8),
              Text(
                _isNepali ? 'सहयोगी निमन्त्रणा' : 'Lead Cook Crew Invitation',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFFE65100),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _invitationPrompt,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: SitiColors.dark,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_isNepali
                      ? 'भान्सा टोलीलाई निमन्त्रणा पठाइयो!'
                      : 'Cooking crew notified on household channel!'),
                  backgroundColor: SitiColors.terracotta,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.share_rounded, size: 18),
            label: Text(_isNepali ? 'टोलीलाई बोलाउनुहोस्' : 'Invite Crew to Kitchen'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFE65100),
              side: const BorderSide(color: Color(0xFFE65100)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCrewPillsRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Text(
            _isNepali ? 'भान्सा टोली:' : 'Active Crew:',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: SitiColors.dark),
          ),
          const SizedBox(width: 8),
          ..._crew.map((member) {
            final isLead = member.memberId == _leadCook?.memberId;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InputChip(
                avatar: CircleAvatar(
                  backgroundColor: isLead ? SitiColors.terracotta : Colors.amber.shade700,
                  child: Text(
                    member.name.isNotEmpty ? member.name[0] : '?',
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
                label: Text(
                  isLead ? '${member.name} (Lead)' : member.name,
                  style: TextStyle(
                    fontWeight: isLead ? FontWeight.bold : FontWeight.normal,
                    color: isLead ? SitiColors.terracotta : SitiColors.dark,
                  ),
                ),
                selected: isLead,
                selectedColor: SitiColors.terracotta.withAlpha(30),
                onPressed: () {
                  setState(() {
                    _leadCook = member;
                    _updateInvitation();
                  });
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: NepaliTypography.titleMedium.copyWith(
        fontWeight: FontWeight.bold,
        color: SitiColors.dark,
      ),
    );
  }

  Widget _buildTaskCard(CookTask task) {
    final isDone = task.status == TaskStatus.completed;
    final isInProgress = task.status == TaskStatus.inProgress;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDone
              ? Colors.green.shade300
              : isInProgress
                  ? SitiColors.terracotta
                  : Colors.grey.shade200,
          width: isDone || isInProgress ? 1.5 : 1,
        ),
      ),
      elevation: 0,
      color: isDone ? const Color(0xFFF1F8E9) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  onPressed: () => _toggleTaskStatus(task),
                  icon: Icon(
                    isDone
                        ? Icons.check_circle_rounded
                        : isInProgress
                            ? Icons.timelapse_rounded
                            : Icons.radio_button_unchecked_rounded,
                    color: isDone
                        ? Colors.green
                        : isInProgress
                            ? SitiColors.terracotta
                            : Colors.grey.shade400,
                    size: 26,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isNepali ? task.titleNe : task.titleEn,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: isDone ? Colors.grey.shade700 : SitiColors.dark,
                          decoration: isDone ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isNepali ? task.descriptionNe : task.descriptionEn,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '~${task.estimatedMinutes}m',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (task.isKidFriendly)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded, size: 13, color: Colors.amber),
                        const SizedBox(width: 3),
                        Text(
                          _isNepali ? 'बालबालिका अनुकूल' : 'Kid-Friendly',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.brown.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                const Spacer(),
                // Assignee picker
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: SitiColors.terracotta.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isDense: true,
                      value: task.assignedMemberId,
                      hint: Text(_isNepali ? 'जिम्मा दिने' : 'Assign to...'),
                      icon: const Icon(Icons.arrow_drop_down, color: SitiColors.terracotta, size: 20),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: SitiColors.terracotta,
                      ),
                      onChanged: (String? newMemberId) {
                        if (newMemberId != null) {
                          final selected = _crew.firstWhere((m) => m.memberId == newMemberId);
                          _changeAssignee(task, selected);
                        }
                      },
                      items: _crew.map((member) {
                        final canDo = member.canPerformTask(task.taskType);
                        return DropdownMenuItem<String>(
                          value: member.memberId,
                          child: Text(
                            canDo ? member.name : '${member.name} (Supervise)',
                            style: TextStyle(
                              color: canDo ? SitiColors.dark : Colors.grey.shade500,
                              fontWeight: canDo ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _startActiveCooking,
            icon: const Icon(Icons.soup_kitchen_rounded, color: Colors.white),
            label: Text(
              _isNepali ? 'टोलीसँग पकाउन सुरु गर्नुहोस्' : 'Start Cooking with Crew',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: SitiColors.terracotta,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton.icon(
            onPressed: _openFairShareScreen,
            icon: const Icon(Icons.emoji_events_outlined, color: SitiColors.terracotta),
            label: Text(
              _isNepali ? 'सहकार्य इतिहास र सम्मान हेर्नुहोस्' : 'View Fair-Share Teamwork Rota',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: SitiColors.terracotta,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: SitiColors.terracotta),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }
}
