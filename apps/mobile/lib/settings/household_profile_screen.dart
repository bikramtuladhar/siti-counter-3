import 'dart:async';

import 'package:flutter/material.dart';

import '../consumption/consumption_repository.dart';
import '../onboarding/language_toggle.dart';
import '../settings/settings_service.dart';
import '../settings/setup_progress.dart';
import '../theme/nepali_typography.dart';
import '../theme/tokens.dart';

/// One step of the progressive household setup, with a localized title and description.
class SetupSection {
  final String id;
  final String titleNe;
  final String titleEn;
  final String descriptionNe;
  final String descriptionEn;
  final IconData icon;

  const SetupSection({
    required this.id,
    required this.titleNe,
    required this.titleEn,
    required this.descriptionNe,
    required this.descriptionEn,
    required this.icon,
  });
}

class HouseholdProfileScreen extends StatefulWidget {
  final HouseholdSettings settings;
  final ConsumptionRepository? consumptionRepository;

  /// Called whenever an answer changes, so the home screen can refresh its checklist.
  final VoidCallback? onChanged;

  /// Pre-supplied household facts, skipping the initial load.
  ///
  /// Lets previews and widget tests render the screen without a live database, whose real
  /// I/O does not complete inside `testWidgets`' fake-async zone.
  final SetupInputs? initialInputs;

  const HouseholdProfileScreen({
    super.key,
    required this.settings,
    this.consumptionRepository,
    this.onChanged,
    this.initialInputs,
  });

  @override
  State<HouseholdProfileScreen> createState() => _HouseholdProfileScreenState();
}

class _HouseholdProfileScreenState extends State<HouseholdProfileScreen> {
  static const List<SetupSection> _sections = [
    SetupSection(
      id: SetupTaskIds.mealRhythm,
      titleNe: 'खानाको समय',
      titleEn: 'Meal rhythm',
      descriptionNe: 'तपाईंले कुन बेला खाना खानुहुन्छ?',
      descriptionEn: 'Which meal slots your household actually eats.',
      icon: Icons.schedule_rounded,
    ),
    SetupSection(
      id: SetupTaskIds.units,
      titleNe: 'नाप प्रणाली',
      titleEn: 'Measurements',
      descriptionNe: 'पाउ, माना वा मिट्रिक — र आफ्नै बर्तन माप्नुहोस्।',
      descriptionEn: 'Pau, mana or metric — then calibrate your own bowls.',
      icon: Icons.straighten_rounded,
    ),
    SetupSection(
      id: SetupTaskIds.members,
      titleNe: 'घरका सदस्य',
      titleEn: 'Household members',
      descriptionNe: 'नाम, उमेर र एलर्जी — सही हिसाबका लागि।',
      descriptionEn: 'Names, ages and allergies for accurate portions.',
      icon: Icons.groups_rounded,
    ),
    SetupSection(
      id: SetupTaskIds.cookingRhythm,
      titleNe: 'भान्साको बानी',
      titleEn: 'Cooking rhythm',
      descriptionNe: 'कति दिनमा खाना पकाउनुहुन्छ, र व्रतका दिनहरू।',
      descriptionEn: 'How often you cook, and any fasting days.',
      icon: Icons.local_fire_department_rounded,
    ),
  ];

  bool _isNepali = true;
  bool _loading = true;
  late SetupProgress _progress = deriveSetupProgress(const SetupInputs());

  CookingRhythm _rhythm = CookingRhythm.mostDays;
  UnitSystem _units = UnitSystem.metricWithTraditional;
  List<String> _fastingDays = const [];
  List<String> _enabledSlots = const [];
  int _memberCount = 0;
  int _calibratedVesselCount = 0;

  @override
  void initState() {
    super.initState();
    final injected = widget.initialInputs;
    if (injected != null) {
      _applyInputs(injected);
      _loading = false;
      // Still resolve the stored language so an injected snapshot renders in the
      // household's chosen language rather than defaulting to Nepali.
      unawaited(_loadLanguage());
    } else {
      _load();
    }
  }

  Future<void> _loadLanguage() async {
    final language = await widget.settings.language;
    if (mounted) setState(() => _isNepali = language == 'ne');
  }

  bool get _isNe => _isNepali;

  Future<void> _load() async {
    final settings = widget.settings;

    final language = await settings.language;
    var members = 0;
    var calibrated = 0;
    final consumption = widget.consumptionRepository;
    if (consumption != null) {
      try {
        members = (await consumption.getMembers()).length;
        calibrated = await consumption.countCalibratedVessels();
      } catch (_) {
        // Consumption database unavailable: report these as outstanding rather than
        // failing the whole screen.
      }
    }

    if (!mounted) return;

    setState(() {
      _isNepali = language == 'ne';
      _memberCount = members;
      _calibratedVesselCount = calibrated;
      _loading = false;
    });

    _applyInputs(
      SetupInputs(
        enabledMealSlots: await settings.enabledMealSlots,
        calibratedVesselCount: calibrated,
        memberCount: members,
        cookingRhythm: await settings.cookingRhythm,
        fastingDays: await settings.fastingDays,
      ),
    );
    _applyStoredUnitSystem();
  }

  Future<void> _applyStoredUnitSystem() async {
    final units = await widget.settings.unitSystem;
    if (mounted) setState(() => _units = units);
  }

  void _applyInputs(SetupInputs inputs) {
    _enabledSlots = inputs.enabledMealSlots;
    _rhythm = inputs.cookingRhythm;
    _fastingDays = inputs.fastingDays;
    _memberCount = inputs.memberCount;
    _calibratedVesselCount = inputs.calibratedVesselCount;
    _progress = deriveSetupProgress(inputs);
  }

  void _notifyChanged() {
    _progress = deriveSetupProgress(
      SetupInputs(
        enabledMealSlots: _enabledSlots,
        calibratedVesselCount: _calibratedVesselCount,
        memberCount: _memberCount,
        cookingRhythm: _rhythm,
        fastingDays: _fastingDays,
      ),
    );
    widget.onChanged?.call();
    if (mounted) setState(() {});
  }

  // --- Section editors ---

  Future<void> _editMealRhythm() async {
    final slots = await _showSlotPicker();
    if (slots == null) return;
    await widget.settings.setEnabledMealSlots(slots);
    if (!mounted) return;
    setState(() => _enabledSlots = slots);
    _notifyChanged();
  }

  Future<void> _editUnits() async {
    final choice = await _showUnitPicker();
    if (choice == null) return;
    await widget.settings.setUnitSystem(choice);
    if (!mounted) return;
    setState(() => _units = choice);
    _notifyChanged();
  }

  Future<void> _editCookingRhythm() async {
    final result = await _showRhythmPicker();
    if (result == null) return;
    await widget.settings.setCookingRhythm(result.rhythm);
    await widget.settings.setFastingDays(result.fastingDays);
    if (!mounted) return;
    setState(() {
      _rhythm = result.rhythm;
      _fastingDays = result.fastingDays;
    });
    _notifyChanged();
  }

  Future<void> _editMembers() async {
    final consumption = widget.consumptionRepository;
    if (consumption == null) {
      _toast(
        _isNe
            ? 'सदस्य थप्नका लागि खपत डाटाबेस चल्नुपर्छ।'
            : 'Add members once the consumption database is available.',
      );
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => HouseholdMemberSetupScreen(
          repository: consumption,
          currentLanguage: _isNe ? 'ne' : 'en',
        ),
      ),
    );
    await _load();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<List<String>?> _showSlotPicker() async {
    const options = [
      ('breakfast', 'बिहानीको खाना', 'Breakfast'),
      ('morning-dal-bhat', 'बिहाने दाल-भात', 'Morning Dal Bhat'),
      ('lunch', 'दिउँसोको खाना', 'Lunch'),
      ('evening-snack', 'बेलुका खाजा', 'Evening Snack'),
      ('dinner', 'रातिको खाना', 'Dinner'),
    ];

    final selected = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _SelectionSheet<String>(
        title: _isNe ? 'कुन-कुन समय खाना खानुहुन्छ?' : 'Which meals do you eat?',
        subtitle: _isNe
            ? 'सबै छान्नुहोस् वा केही छोड्नुहोस्।'
            : 'Select all that apply.',
        options: options
            .map((o) => _SelectionOption<String>(
                  value: o.$1,
                  label: _isNe ? o.$2 : o.$3,
                  subtitle: _isNe ? o.$3 : o.$2,
                ))
            .toList(),
        initialSelection: _enabledSlots,
        allowMultiple: true,
      ),
    );
    return selected;
  }

  Future<UnitSystem?> _showUnitPicker() async {
    const options = [
      (UnitSystem.metricWithTraditional, 'पाउ / माना / मिट्रिक', 'Pau, mana & metric'),
      (UnitSystem.metric, 'मिट्रिक (के.जी., ग्राम, मिली)', 'Metric (kg, g, ml)'),
      (UnitSystem.imperial, 'इम्पीरियल (पाउन्ड, कप)', 'Imperial (lb, cups)'),
    ];

    return showModalBottomSheet<UnitSystem>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _SelectionSheet<UnitSystem>(
        title: _isNe ? 'कस्तो नाप प्रयोग गर्नुहुन्छ?' : 'Which measurements do you use?',
        options: options
            .map((o) => _SelectionOption<UnitSystem>(
                  value: o.$1,
                  label: _isNe ? o.$2 : o.$3,
                  subtitle: _isNe ? o.$3 : o.$2,
                ))
            .toList(),
        initialSelection: [_units],
      ),
    );
  }

  Future<({CookingRhythm rhythm, List<String> fastingDays})?> _showRhythmPicker() {
    return showModalBottomSheet<({CookingRhythm rhythm, List<String> fastingDays})>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _CookingRhythmSheet(
        isNepali: _isNe,
        initialRhythm: _rhythm,
        initialFastingDays: _fastingDays,
      ),
    );
  }

  /// Counts a noun, so "1 slot" does not read as "1 slots".
  static String _count(int n, String singular, String plural) =>
      n == 1 ? '$n $singular' : '$n $plural';

  String _summaryFor(SetupSection section) {
    switch (section.id) {
      case SetupTaskIds.mealRhythm:
        if (_enabledSlots.isEmpty) {
          return _isNe ? 'अहिलेसम्म छानिएको छैन' : 'Not chosen yet';
        }
        return _isNe
            ? '${_enabledSlots.length} समय छानिएको'
            : _count(_enabledSlots.length, 'slot', 'slots') + ' selected';
      case SetupTaskIds.units:
        if (_calibratedVesselCount == 0) {
          return _units == UnitSystem.metricWithTraditional
              ? (_isNe ? 'पाउ / माना / मिट्रिक' : 'Pau, mana & metric')
              : (_isNe ? 'मिट्रिक' : 'Metric');
        }
        return _isNe
            ? '$_calibratedVesselCount बर्तन मापिएको'
            : _count(_calibratedVesselCount, 'vessel', 'vessels') +
                  ' calibrated';
      case SetupTaskIds.members:
        if (_memberCount == 0) {
          return _isNe ? 'कुनै सदस्य थपिएको छैन' : 'No members added';
        }
        return _isNe
            ? '$_memberCount जना सदस्य'
            : _count(_memberCount, 'member', 'members');
      case SetupTaskIds.cookingRhythm:
        final fastingNote = _fastingDays.isEmpty
            ? (_isNe ? 'व्रतको दिन छैन' : 'no fasting days')
            : (_isNe
                  ? '${_fastingDays.length} व्रत दिन'
                  : _count(_fastingDays.length, 'fasting day', 'fasting days'));
        final rhythm = switch (_rhythm) {
          CookingRhythm.daily => _isNe ? 'हरेक दिन' : 'Every day',
          CookingRhythm.mostDays => _isNe ? 'धेरैजसो दिन' : 'Most days',
          CookingRhythm.occasionally => _isNe ? 'कहिलेकाहीँ' : 'Occasionally',
          CookingRhythm.festivalsOnly => _isNe ? 'पर्वमा मात्र' : 'Festivals only',
        };
        return '$rhythm • $fastingNote';
      default:
        return '';
    }
  }

  void _openSection(SetupSection section) {
    switch (section.id) {
      case SetupTaskIds.mealRhythm:
        _editMealRhythm();
      case SetupTaskIds.units:
        _editUnits();
      case SetupTaskIds.members:
        _editMembers();
      case SetupTaskIds.cookingRhythm:
        _editCookingRhythm();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SitiColors.warmWhite,
      appBar: AppBar(
        backgroundColor: SitiColors.warmWhite,
        elevation: 0,
        title: Text(
          _isNe ? 'घरको सेटअप' : 'Household setup',
          style: NepaliTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w800,
            color: SitiColors.dark,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: LanguageToggle(
                compact: true,
                language: _isNe ? 'ne' : 'en',
                onChanged: (code) async {
                  await widget.settings.setLanguage(code);
                  if (mounted) setState(() => _isNepali = code == 'ne');
                },
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: _progress.fraction,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        SitiColors.terracotta,
                      ),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _isNe
                        ? '${_progress.completed} / ${_progress.total} पूरा भयो'
                        : '${_progress.completed} of ${_progress.total} complete',
                    style: NepaliTypography.bodySmall.copyWith(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ..._sections.map((section) {
                    final isDone = _progress.completedIds.contains(section.id);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _SetupSectionCard(
                        section: section,
                        isNepali: _isNe,
                        isComplete: isDone,
                        summary: _summaryFor(section),
                        onTap: () => _openSection(section),
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }
}

// --- Supporting widgets ---

class _SetupSectionCard extends StatelessWidget {
  final SetupSection section;
  final bool isNepali;
  final bool isComplete;
  final String summary;
  final VoidCallback onTap;

  const _SetupSectionCard({
    required this.section,
    required this.isNepali,
    required this.isComplete,
    required this.summary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: Key('setup_section_${section.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isComplete
                  ? SitiColors.freshGreen.withValues(alpha: 0.5)
                  : Colors.grey.shade300,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (isComplete ? SitiColors.freshGreen : SitiColors.terracotta)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isComplete ? Icons.check_rounded : section.icon,
                  color: isComplete ? SitiColors.freshGreen : SitiColors.terracotta,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isNepali ? section.titleNe : section.titleEn,
                      style: NepaliTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      summary,
                      style: NepaliTypography.bodySmall.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                isComplete ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
                color: isComplete ? SitiColors.freshGreen : Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionOption<T> {
  final T value;
  final String label;
  final String subtitle;

  const _SelectionOption({
    required this.value,
    required this.label,
    required this.subtitle,
  });
}

class _SelectionSheet<T> extends StatefulWidget {
  final String title;
  final String? subtitle;
  final List<_SelectionOption<T>> options;
  final List<T> initialSelection;
  final bool allowMultiple;

  const _SelectionSheet({
    required this.title,
    required this.options,
    required this.initialSelection,
    this.subtitle,
    this.allowMultiple = false,
  });

  @override
  State<_SelectionSheet<T>> createState() => _SelectionSheetState<T>();
}

class _SelectionSheetState<T> extends State<_SelectionSheet<T>> {
  late final Set<T> _selected = widget.initialSelection.toSet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.title,
              style: NepaliTypography.titleLarge.copyWith(
                fontWeight: FontWeight.w800,
                color: SitiColors.dark,
              ),
            ),
            if (widget.subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                widget.subtitle!,
                style: NepaliTypography.bodySmall.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  ...widget.options.map((option) {
                    final isSelected = _selected.contains(option.value);
                    return ListTile(
                      key: Key('sheet_option_${option.value}'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        widget.allowMultiple
                            ? (isSelected
                                  ? Icons.check_box_rounded
                                  : Icons.check_box_outline_blank_rounded)
                            : (isSelected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked),
                        color: isSelected ? SitiColors.terracotta : Colors.grey,
                      ),
                      title: Text(
                        option.label,
                        style: const TextStyle(fontSize: 15),
                      ),
                      subtitle: Text(
                        option.subtitle,
                        style: const TextStyle(fontSize: 12),
                      ),
                      onTap: () {
                        setState(() {
                          if (widget.allowMultiple) {
                            if (!_selected.remove(option.value)) {
                              _selected.add(option.value);
                            }
                          } else {
                            // Single-select replaces, and re-tapping the active row is a
                            // no-op rather than clearing the only valid selection.
                            if (_selected.length == 1 && isSelected) return;
                            _selected
                              ..clear()
                              ..add(option.value);
                          }
                        });
                      },
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                // A single-select route expects the value, not a list; popping a list
                // here throws at runtime.
                if (widget.allowMultiple) {
                  Navigator.pop(context, _selected.toList());
                } else {
                  if (_selected.isEmpty) {
                    Navigator.pop(context);
                    return;
                  }
                  Navigator.pop(context, _selected.first);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: SitiColors.terracotta,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                widget.allowMultiple ? 'Save' : 'Select',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Minimal member editor: add a household member with a role and allergies.
///
/// Backed by the consumption database's existing `household_members` table rather than a
/// second store, so nutrition and portion maths keep one source of truth.
class HouseholdMemberSetupScreen extends StatefulWidget {
  final ConsumptionRepository repository;
  final String currentLanguage;

  const HouseholdMemberSetupScreen({
    super.key,
    required this.repository,
    required this.currentLanguage,
  });

  @override
  State<HouseholdMemberSetupScreen> createState() =>
      _HouseholdMemberSetupScreenState();
}

class _HouseholdMemberSetupScreenState extends State<HouseholdMemberSetupScreen> {
  static const _roles = ['Adult', 'Child', 'Toddler', 'Elderly'];
  static const _allergies = [
    ('peanut', 'Peanut', 'भ-groundnut'),
    ('mustard', 'Mustard', 'सरसों'),
    ('dairy', 'Dairy', 'दूधजन्य'),
    ('gluten', 'Gluten', 'ग्लुटेन'),
    ('shellfish', 'Shellfish', 'साँड्रो / झिंगा'),
    ('egg', 'Egg', 'अण्डा'),
  ];

  final _nameController = TextEditingController();
  String _role = 'Adult';
  final Set<String> _selectedAllergies = {};
  bool _saving = false;

  bool get _isNe => widget.currentLanguage == 'ne';

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _saving = true);
    try {
      await widget.repository.addMember(
        name: name,
        role: _role,
        allergies: _selectedAllergies.toList(),
      );
      _nameController.clear();
      _selectedAllergies.clear();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SitiColors.warmWhite,
      appBar: AppBar(
        backgroundColor: SitiColors.warmWhite,
        elevation: 0,
        title: Text(
          _isNe ? 'घरका सदस्य' : 'Household members',
          style: NepaliTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w800,
            color: SitiColors.dark,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            TextField(
              key: const Key('member_name_field'),
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: _isNe ? 'नाम' : 'Name',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _isNe ? 'भूमिका' : 'Role',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _roles
                  .map(
                    (role) => ChoiceChip(
                      key: Key('member_role_$role'),
                      label: Text(role),
                      selected: _role == role,
                      selectedColor: SitiColors.terracotta.withValues(alpha: 0.2),
                      onSelected: (_) => setState(() => _role = role),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 20),
            Text(
              _isNe ? 'एलर्जी' : 'Allergies',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _allergies
                  .map(
                    (a) => FilterChip(
                      key: Key('member_allergy_${a.$1}'),
                      label: Text(_isNe ? a.$3 : a.$2),
                      selected: _selectedAllergies.contains(a.$1),
                      selectedColor: SitiColors.alert.withValues(alpha: 0.2),
                      onSelected: (selected) => setState(() {
                        if (selected) {
                          _selectedAllergies.add(a.$1);
                        } else {
                          _selectedAllergies.remove(a.$1);
                        }
                      }),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              key: const Key('add_member_button'),
              onPressed: _saving ? null : _add,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: Text(_isNe ? 'सदस्य थप्नुहोस्' : 'Add member'),
              style: ElevatedButton.styleFrom(
                backgroundColor: SitiColors.terracotta,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
/// Editor for cooking rhythm and fasting days.
///
/// A StatefulWidget rather than a `StatefulBuilder`: a builder closure re-runs on every
/// setState, so locally declared `rhythm`/`fasting` variables were re-initialised each
/// rebuild and the selection silently reverted.
class _CookingRhythmSheet extends StatefulWidget {
  final bool isNepali;
  final CookingRhythm initialRhythm;
  final List<String> initialFastingDays;

  const _CookingRhythmSheet({
    required this.isNepali,
    required this.initialRhythm,
    required this.initialFastingDays,
  });

  @override
  State<_CookingRhythmSheet> createState() => _CookingRhythmSheetState();
}

class _CookingRhythmSheetState extends State<_CookingRhythmSheet> {
  static const List<(CookingRhythm, String, String)> _rhythms = [
    (CookingRhythm.daily, 'हरेक दिन', 'Every day'),
    (CookingRhythm.mostDays, 'धेरैजसो दिन', 'Most days'),
    (CookingRhythm.occasionally, 'कहिलेकाहीँ मात्र', 'Only occasionally'),
    (CookingRhythm.festivalsOnly, 'पर्वहरूमा मात्र', 'Festivals only'),
  ];

  static const List<(String, String, String)> _fastings = [
    ('ekadashi', 'एकादशी', 'Ekadashi'),
    ('no_onion_garlic_day', 'प्याज-लसुन छुट्टै दिन', 'No onion/garlic days'),
    ('ramadan', 'रमजान', 'Ramadan'),
    ('shivaratri', 'शिवरात्रि', 'Shivaratri'),
  ];

  late CookingRhythm _rhythm = widget.initialRhythm;
  late final Set<String> _fasting = widget.initialFastingDays.toSet();

  @override
  Widget build(BuildContext context) {
    final isNe = widget.isNepali;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isNe ? 'भान्साको बानी' : 'Cooking rhythm',
              style: NepaliTypography.titleLarge.copyWith(
                fontWeight: FontWeight.w800,
                color: SitiColors.dark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isNe
                  ? 'कति दिनमा खाना पकाउनुहुन्छ? व्रतका दिनहरू छान्नुहोस्।'
                  : 'How often do you cook? Select any fasting days.',
              style: NepaliTypography.bodySmall.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  ..._rhythms.map(
                    (r) => ListTile(
                      key: Key('rhythm_option_${r.$1.name}'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        _rhythm == r.$1
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: _rhythm == r.$1
                            ? SitiColors.terracotta
                            : Colors.grey,
                      ),
                      title: Text(
                        isNe ? r.$2 : r.$3,
                        style: const TextStyle(fontSize: 15),
                      ),
                      onTap: () => setState(() => _rhythm = r.$1),
                    ),
                  ),
                  const Divider(height: 24),
                  Text(
                    isNe ? 'व्रतका दिनहरू' : 'Fasting days',
                    style: NepaliTypography.titleSmall.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ..._fastings.map(
                    (f) => CheckboxListTile(
                      key: Key('fasting_option_${f.$1}'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: _fasting.contains(f.$1),
                      activeColor: SitiColors.terracotta,
                      title: Text(
                        isNe ? f.$2 : f.$3,
                        style: const TextStyle(fontSize: 15),
                      ),
                      onChanged: (checked) => setState(() {
                        if (checked == true) {
                          _fasting.add(f.$1);
                        } else {
                          _fasting.remove(f.$1);
                        }
                      }),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.pop(
                context,
                (rhythm: _rhythm, fastingDays: _fasting.toList()),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: SitiColors.terracotta,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                isNe ? 'सेभ गर्नुहोस्' : 'Save',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
