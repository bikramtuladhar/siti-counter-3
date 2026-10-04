import 'package:flutter/material.dart';
import 'package:kitchen_engine/consumption_engine.dart';
import '../theme/tokens.dart';
import '../theme/nepali_typography.dart';
import 'consumption_repository.dart';

/// Modal dialog for quick-adding outside snacks or restaurant meals.
class QuickAddOutsideFoodDialog extends StatefulWidget {
  final String currentLanguage;
  final ConsumptionRepository repository;
  final List<MemberDietaryProfile> members;
  final ValueChanged<OutsideFoodEntry>? onAdded;

  const QuickAddOutsideFoodDialog({
    super.key,
    required this.currentLanguage,
    required this.repository,
    required this.members,
    this.onAdded,
  });

  @override
  State<QuickAddOutsideFoodDialog> createState() => _QuickAddOutsideFoodDialogState();
}

class _QuickAddOutsideFoodDialogState extends State<QuickAddOutsideFoodDialog> {
  late String _selectedMemberId;
  final _foodController = TextEditingController();
  String _selectedPortionSize = 'medium';
  String _selectedMealSlot = 'afternoon-khaja';

  bool get _isNepali => widget.currentLanguage == 'ne';

  final List<({String en, String ne, int calories})> _popularNepaliSnacks = const [
    (en: 'Buff Momo', ne: 'बफ म:म', calories: 380),
    (en: 'Veg Chowmein', ne: 'भेज चाउमिन', calories: 320),
    (en: 'Pani Puri', ne: 'पानी पुरी', calories: 180),
    (en: 'Samosa Tarkari', ne: 'समोसा तरकारी', calories: 260),
    (en: 'Sel Roti & Chiya', ne: 'सेलरोटी र चिया', calories: 240),
    (en: 'Chatpate', ne: 'चटपटे', calories: 190),
    (en: 'Bara / Wo', ne: 'बारा / वोह', calories: 210),
  ];

  @override
  void initState() {
    super.initState();
    _selectedMemberId = widget.members.isNotEmpty ? widget.members.first.memberId : '';
  }

  @override
  void dispose() {
    _foodController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedMember = widget.members.firstWhere(
      (m) => m.memberId == _selectedMemberId,
      orElse: () => widget.members.first,
    );

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.fastfood_rounded,
                                color: Colors.orange.shade900, size: 22),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _isNepali ? 'बाहिरको खाजा / स्न्याक्स' : 'Outside Snack / Meal',
                              style: NepaliTypography.titleMedium.copyWith(
                                fontWeight: FontWeight.w700,
                                color: SitiColors.dark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              const SizedBox(height: 14),

              // Member Dropdown
              Text(
                _isNepali ? 'कसले खायो? (Who ate?)' : 'Who ate?',
                style: NepaliTypography.labelMedium.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                key: const Key('outside_member_picker'),
                value: _selectedMemberId,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
                items: widget.members.map((m) {
                  return DropdownMenuItem(
                    value: m.memberId,
                    child: Row(
                      children: [
                        Icon(
                          m.isChildOrBaby ? Icons.child_care_rounded : Icons.person_rounded,
                          size: 16,
                          color: SitiColors.terracotta,
                        ),
                        const SizedBox(width: 8),
                        Text(m.name),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedMemberId = val;
                    });
                  }
                },
              ),
              const SizedBox(height: 14),

              // Food Name Input
              Text(
                _isNepali ? 'खाजाको नाम' : 'Food / Snack Name',
                style: NepaliTypography.labelMedium.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              TextField(
                key: const Key('outside_food_name_input'),
                controller: _foodController,
                decoration: InputDecoration(
                  hintText: _isNepali ? 'जस्तै: बफ म:म वा चाउमिन' : 'e.g. Momo, Samosa, Chaat',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 8),

              // Popular quick chips
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _popularNepaliSnacks.map((snack) {
                  final label = _isNepali ? snack.ne : snack.en;
                  return ActionChip(
                    label: Text(label, style: const TextStyle(fontSize: 11)),
                    backgroundColor: SitiColors.warmWhite,
                    side: BorderSide(color: Colors.grey.shade300),
                    onPressed: () {
                      setState(() {
                        _foodController.text = label;
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              // Portion Size Segmented Buttons
              Text(
                _isNepali ? 'मात्रा (Portion Size)' : 'Portion Size',
                style: NepaliTypography.labelMedium.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'small',
                    label: Text(_isNepali ? 'सानो (Small)' : 'Small'),
                  ),
                  ButtonSegment(
                    value: 'medium',
                    label: Text(_isNepali ? 'मध्यम' : 'Medium'),
                  ),
                  ButtonSegment(
                    value: 'large',
                    label: Text(_isNepali ? 'ठूलो (Large)' : 'Large'),
                  ),
                ],
                selected: {_selectedPortionSize},
                onSelectionChanged: (set) {
                  setState(() {
                    _selectedPortionSize = set.first;
                  });
                },
              ),
              const SizedBox(height: 20),

              // Save Button
              ElevatedButton.icon(
                key: const Key('save_outside_food_button'),
                onPressed: () async {
                  final foodName = _foodController.text.trim();
                  if (foodName.isEmpty) return;

                  final entry = ConsumptionEngine.quickAddOutsideFood(
                    memberId: selectedMember.memberId,
                    memberName: selectedMember.name,
                    foodName: foodName,
                    mealSlot: _selectedMealSlot,
                    portionSize: _selectedPortionSize,
                    estimatedCalories: selectedMember.isChildOrBaby ? null : 350,
                    tags: ['outside', 'quick-add'],
                  );

                  widget.onAdded?.call(entry);
                  await widget.repository.logOutsideFood(entry);

                  if (context.mounted) {
                    final messenger = ScaffoldMessenger.maybeOf(context);
                    Navigator.of(context).pop();
                    messenger?.showSnackBar(
                      SnackBar(
                        content: Text(
                          _isNepali
                              ? 'खाजा रेकर्ड गरियो: $foodName ✓'
                              : 'Logged outside snack: $foodName ✓',
                        ),
                        backgroundColor: Colors.orange.shade800,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.check_rounded, size: 18),
                label: Text(
                  _isNepali ? 'रेकर्ड गर्नुहोस्' : 'Log Outside Snack',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SitiColors.terracotta,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
}
