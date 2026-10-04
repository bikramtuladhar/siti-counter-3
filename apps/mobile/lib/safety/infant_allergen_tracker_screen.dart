import 'package:flutter/material.dart';
import 'package:kitchen_engine/kitchen_engine.dart';
import '../theme/nepali_typography.dart';
import '../theme/tokens.dart';

/// Screen for tracking baby & toddler allergen introduction (4–11 months)
/// with pediatric disclaimers, choking safety rules, and reaction logs.
class InfantAllergenTrackerScreen extends StatefulWidget {
  final String childName;
  final String childMemberId;
  final List<InfantAllergenLog> initialLogs;
  final String currentLanguage;
  final void Function(InfantAllergenLog newLog)? onLogSaved;

  const InfantAllergenTrackerScreen({
    super.key,
    required this.childName,
    required this.childMemberId,
    this.initialLogs = const [],
    this.currentLanguage = 'ne',
    this.onLogSaved,
  });

  @override
  State<InfantAllergenTrackerScreen> createState() => _InfantAllergenTrackerScreenState();
}

class _InfantAllergenTrackerScreenState extends State<InfantAllergenTrackerScreen> {
  late List<InfantAllergenLog> _logs;

  bool get _isNepali => widget.currentLanguage == 'ne';

  @override
  void initState() {
    super.initState();
    _logs = List.from(widget.initialLogs);
  }

  void _openAddExposureDialog(String allergen) {
    double portionGrams = 2.5;
    int dayOfProtocol = 1;
    ReactionSeverity reaction = ReactionSeverity.none;
    final foodCtrl = TextEditingController(
      text: allergen == AllergenCatalog.peanuts
          ? 'Thin peanut butter in banana puree'
          : (allergen == AllergenCatalog.eggs
              ? 'Mashed boiled egg yolk'
              : 'Small test portion'),
    );
    final symptomsCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    // Check spacing protocol
    final canIntroduce = InfantAllergenEngine.canIntroduceNewAllergen(
      recentLogs: _logs,
      newAllergen: allergen,
      candidateDate: DateTime.now(),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(dialogCtx).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _isNepali ? 'नयाँ खुराक दर्ता गर्नुहोस्' : 'Log Allergen Exposure',
                          style: NepaliTypography.titleMedium.copyWith(fontWeight: FontWeight.w800),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(dialogCtx),
                        ),
                      ],
                    ),
                    const Divider(),

                    // Spacing warning banner if applicable
                    if (!canIntroduce) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.shade300),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _isNepali
                                    ? 'चेतावनी: भर्खरै अर्को खानामा प्रतिक्रिया देखिएको थियो। नयाँ खाना सुरु गर्नु अघि ३–५ दिन पर्खनुहोस्।'
                                    : 'Warning: A reaction occurred recently. Pediatric protocol recommends waiting 3-5 days before testing another new food.',
                                style: NepaliTypography.bodySmall.copyWith(
                                  color: Colors.orange.shade900,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Allergen Name & Choking Advice
                    Text(
                      '${EmergencyAllergyCard.allergenNameEn(allergen)} (${EmergencyAllergyCard.allergenNameNe(allergen)})',
                      style: NepaliTypography.headlineSmall.copyWith(
                        fontWeight: FontWeight.w800,
                        color: SitiColors.terracotta,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Text(
                        _isNepali
                            ? InfantAllergenEngine.getChokingSafetyGuidanceNe(allergen)
                            : InfantAllergenEngine.getChokingSafetyGuidanceEn(allergen),
                        style: NepaliTypography.bodySmall.copyWith(color: Colors.amber.shade900),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Food Description
                    TextField(
                      controller: foodCtrl,
                      decoration: InputDecoration(
                        labelText: _isNepali ? 'खानाको विवरण (Food preparation)' : 'Food preparation',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Portion & Day of Protocol
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: dayOfProtocol,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: _isNepali ? 'प्रोटोकल दिन' : 'Protocol Day',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            items: const [
                              DropdownMenuItem(value: 1, child: Text('Day 1 (Tiny test)')),
                              DropdownMenuItem(value: 2, child: Text('Day 2 (Medium test)')),
                              DropdownMenuItem(value: 3, child: Text('Day 3 (Full portion)')),
                            ],
                            onChanged: (v) => setSheetState(() => dayOfProtocol = v ?? 1),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<double>(
                            value: portionGrams,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: _isNepali ? 'मात्रा (Portion)' : 'Portion',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            items: const [
                              DropdownMenuItem(value: 1.0, child: Text('1/4 tsp (~1g)')),
                              DropdownMenuItem(value: 2.5, child: Text('1/2 tsp (~2.5g)')),
                              DropdownMenuItem(value: 5.0, child: Text('1 tsp (~5g)')),
                              DropdownMenuItem(value: 10.0, child: Text('2 tsp (~10g)')),
                            ],
                            onChanged: (v) => setSheetState(() => portionGrams = v ?? 2.5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Reaction Observer
                    Text(
                      _isNepali ? 'प्रतिक्रिया (Reaction observed):' : 'Reaction observed within 2 hours:',
                      style: NepaliTypography.labelLarge.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: ReactionSeverity.values.map((r) {
                        final isSel = reaction == r;
                        return ChoiceChip(
                          label: Text(r.name.toUpperCase()),
                          selected: isSel,
                          onSelected: (s) => setSheetState(() => reaction = r),
                          selectedColor: r == ReactionSeverity.none
                              ? Colors.green.shade100
                              : (r == ReactionSeverity.mild
                                  ? Colors.amber.shade100
                                  : Colors.red.shade100),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),

                    // Reaction symptoms if any
                    if (reaction != ReactionSeverity.none) ...[
                      TextField(
                        controller: symptomsCtrl,
                        decoration: InputDecoration(
                          labelText: _isNepali
                              ? 'लक्षणहरू (e.g. hives, swelling, vomiting)'
                              : 'Symptoms observed',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Save Button
                    ElevatedButton(
                      onPressed: () {
                        final newLog = InfantAllergenLog(
                          id: 'log-${DateTime.now().millisecondsSinceEpoch}',
                          memberId: widget.childMemberId,
                          allergen: allergen,
                          foodDescription: foodCtrl.text.trim().isNotEmpty
                              ? foodCtrl.text.trim()
                              : 'Test portion',
                          exposureDate: DateTime.now(),
                          portionGrams: portionGrams,
                          dayOfProtocol: dayOfProtocol,
                          reactionSeverity: reaction,
                          reactionSymptoms: symptomsCtrl.text.trim().isNotEmpty
                              ? symptomsCtrl.text.trim()
                              : null,
                          notes: notesCtrl.text.trim().isNotEmpty
                              ? notesCtrl.text.trim()
                              : null,
                        );

                        setState(() {
                          _logs.add(newLog);
                        });
                        widget.onLogSaved?.call(newLog);
                        Navigator.pop(dialogCtx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SitiColors.terracotta,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(_isNepali ? 'सुरक्षित गर्नुहोस्' : 'Save Exposure Log'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final summaries = InfantAllergenEngine.aggregateSummaries(logs: _logs);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isNepali ? 'शिशु एलर्जी ट्र्याकर' : 'Baby Allergen Tracker',
          style: NepaliTypography.titleMedium.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Child Banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.teal.shade50, Colors.teal.shade100.withValues(alpha: 0.5)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.teal.shade200),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.child_care_rounded, color: Colors.teal, size: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.childName,
                            style: NepaliTypography.titleMedium.copyWith(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            _isNepali
                                ? '४–११ महिना: शीर्ष एलर्जीहरूको प्रारम्भिक परिचय'
                                : '4–11 Months: Early Allergen Introduction',
                            style: NepaliTypography.bodySmall.copyWith(color: Colors.teal.shade900),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Prominent Pediatric Disclaimer
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.health_and_safety_rounded, color: Colors.amber.shade900, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          _isNepali ? 'बालरोग विशेषज्ञ सल्लाह (Pediatric Disclaimer)' : 'Pediatric Disclaimer',
                          style: NepaliTypography.labelLarge.copyWith(
                            color: Colors.amber.shade900,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isNepali
                          ? InfantAllergenEngine.pediatricDisclaimerNe
                          : InfantAllergenEngine.pediatricDisclaimerEn,
                      style: NepaliTypography.bodySmall.copyWith(
                        color: Colors.brown.shade900,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Priority Allergen Cards List
              Text(
                _isNepali ? 'शीर्ष एलर्जीहरूको सूची' : 'Priority Introduction Foods',
                style: NepaliTypography.titleSmall.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),

              ...InfantAllergenEngine.priorityBabyAllergens.map((allergen) {
                final summary = summaries[allergen]!;
                return _buildAllergenItemCard(allergen, summary);
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAllergenItemCard(String allergen, InfantAllergenSummary summary) {
    Color badgeColor;
    String badgeText;
    IconData badgeIcon;

    switch (summary.status) {
      case InfantIntroductionStatus.notIntroduced:
        badgeColor = Colors.grey.shade600;
        badgeText = _isNepali ? 'सुरु भएको छैन' : 'Not Started';
        badgeIcon = Icons.radio_button_unchecked_rounded;
        break;
      case InfantIntroductionStatus.introducing:
        badgeColor = Colors.blue.shade700;
        badgeText = _isNepali
            ? 'परिचय हुँदैछ (${summary.totalExposures}/३)'
            : 'In Progress (${summary.totalExposures}/3)';
        badgeIcon = Icons.hourglass_top_rounded;
        break;
      case InfantIntroductionStatus.toleratedSafely:
        badgeColor = Colors.green.shade700;
        badgeText = _isNepali ? 'सफलतापूर्वक पच्यो' : 'Safely Tolerated';
        badgeIcon = Icons.check_circle_rounded;
        break;
      case InfantIntroductionStatus.adverseReaction:
        badgeColor = Colors.red.shade700;
        badgeText = _isNepali ? 'प्रतिक्रिया देखियो' : 'Adverse Reaction';
        badgeIcon = Icons.cancel_rounded;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          title: Text(
            EmergencyAllergyCard.allergenNameEn(allergen),
            style: NepaliTypography.titleSmall.copyWith(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            EmergencyAllergyCard.allergenNameNe(allergen),
            style: NepaliTypography.bodySmall.copyWith(color: Colors.grey.shade700),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(badgeIcon, size: 14, color: badgeColor),
                const SizedBox(width: 4),
                Text(
                  badgeText,
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Choking hazard tip
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _isNepali
                          ? InfantAllergenEngine.getChokingSafetyGuidanceNe(allergen)
                          : InfantAllergenEngine.getChokingSafetyGuidanceEn(allergen),
                      style: NepaliTypography.bodySmall.copyWith(
                        color: Colors.brown.shade900,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Past logs
                  if (summary.logs.isNotEmpty) ...[
                    Text(
                      _isNepali ? 'पहिलेका खुराकिङ रेकर्ड:' : 'Exposure History:',
                      style: NepaliTypography.labelSmall.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    ...summary.logs.map((log) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: Row(
                            children: [
                              Icon(
                                log.hadAdverseReaction
                                    ? Icons.warning_rounded
                                    : Icons.check_circle_outline_rounded,
                                size: 14,
                                color: log.hadAdverseReaction ? Colors.red : Colors.green,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Day ${log.dayOfProtocol} (${log.portionGrams}g): ${log.foodDescription}' +
                                      (log.reactionSymptoms != null
                                          ? ' - Reaction: ${log.reactionSymptoms}'
                                          : ''),
                                  style: NepaliTypography.bodySmall.copyWith(fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                        )),
                    const SizedBox(height: 12),
                  ],

                  // Action button to add exposure
                  OutlinedButton.icon(
                    onPressed: () => _openAddExposureDialog(allergen),
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                    label: Text(_isNepali ? '+ नयाँ खुराक थप्नुहोस्' : '+ Log New Exposure'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: SitiColors.terracotta,
                      side: const BorderSide(color: SitiColors.terracotta),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
