import 'package:flutter/material.dart';
import 'package:kitchen_engine/nepali_calendar.dart';
import 'package:kitchen_engine/region_pack.dart';
import '../data/region_pack_repository.dart';
import '../groceries/grocery_list_screen.dart';
import '../theme/nepali_typography.dart';
import '../theme/tokens.dart';
import 'planner_models.dart';
import 'planner_repository.dart';

/// The Weekly Meal Planner screen with custom meal rhythms, drag & drop slotting,
/// seasonal badges, diet badges, leftover tracking, and local SQLite persistence.
class WeeklyPlannerScreen extends StatefulWidget {
  final WeeklyPlannerRepository repository;
  final String currentLanguage;
  final DateTime? initialWeekStart;
  final void Function(String recipeId)? onRecipeSelected;

  const WeeklyPlannerScreen({
    super.key,
    required this.repository,
    this.currentLanguage = 'ne',
    this.initialWeekStart,
    this.onRecipeSelected,
  });

  @override
  State<WeeklyPlannerScreen> createState() => _WeeklyPlannerScreenState();
}

class _WeeklyPlannerScreenState extends State<WeeklyPlannerScreen> {
  late DateTime _weekStart;
  List<MealRhythmSlot> _slots = [];
  List<PlannedMeal> _plannedMeals = [];
  List<LeftoverItem> _leftovers = [];
  bool _isLoading = true;

  bool get _isNepali => widget.currentLanguage == 'ne';

  @override
  void initState() {
    super.initState();
    final now = widget.initialWeekStart ?? DateTime.now();
    // Start week on Sunday (weekday 7 in Dart DateTime)
    final daysToSubtract = now.weekday == 7 ? 0 : now.weekday;
    _weekStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: daysToSubtract));

    _loadPlannerData();
  }

  Future<void> _loadPlannerData() async {
    setState(() => _isLoading = true);
    final slots = await widget.repository.getActiveSlots();
    final meals = await widget.repository.getPlannedMealsForWeek(_weekStart);
    final leftovers = await widget.repository.getActiveLeftovers();

    if (mounted) {
      setState(() {
        _slots = slots;
        _plannedMeals = meals;
        _leftovers = leftovers;
        _isLoading = false;
      });
    }
  }

  void _nextWeek() {
    setState(() {
      _weekStart = _weekStart.add(const Duration(days: 7));
    });
    _loadPlannerData();
  }

  void _prevWeek() {
    setState(() {
      _weekStart = _weekStart.subtract(const Duration(days: 7));
    });
    _loadPlannerData();
  }

  void _openGroceryListScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => GroceryListScreen(
          weekStart: _weekStart,
          repository: widget.repository,
          currentLanguage: widget.currentLanguage,
        ),
      ),
    );
  }

  String _formatDateIso(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  PlannedMeal? _getMealFor(String dateIso, String slotId) {
    for (final meal in _plannedMeals) {
      if (meal.dateIso == dateIso && meal.slotId == slotId) {
        return meal;
      }
    }
    return null;
  }

  Future<void> _assignMealToSlot({
    required String dateIso,
    required String slotId,
    required RegionRecipe recipe,
    bool isLeftover = false,
  }) async {
    final plannedMeal = PlannedMeal(
      id: '${dateIso}_$slotId',
      dateIso: dateIso,
      slotId: slotId,
      recipeId: recipe.id,
      recipeTitleEn: recipe.titleEn,
      recipeTitleNe: recipe.titleNe,
      servings: 4,
      isLeftover: isLeftover,
      isSeasonal: recipe.seasonality.isNotEmpty,
      dietaryBadges: recipe.dietary,
    );

    await widget.repository.savePlannedMeal(plannedMeal);
    await _loadPlannerData();
  }

  Future<void> _removeMeal(String mealId) async {
    await widget.repository.deletePlannedMeal(mealId);
    await _loadPlannerData();
  }

  Future<void> _openRecipePickerModal({
    required String dateIso,
    required String slotId,
  }) async {
    final pack = RegionPackRepository().currentPack;
    final recipes = pack?.recipes ?? [];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.75,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _isNepali ? 'खाना छान्नुहोस् (Select Recipe)' : 'Select Recipe',
              style: NepaliTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w800,
                color: SitiColors.dark,
              ),
            ),
            const SizedBox(height: 12),

            // Leftover suggestion section if any leftovers exist
            if (_leftovers.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 16, color: Colors.orange.shade900),
                        const SizedBox(width: 6),
                        Text(
                          _isNepali ? 'फ्रिजमा बचेको खाना (Leftovers)' : 'Available Leftovers',
                          style: NepaliTypography.labelMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ..._leftovers.map((l) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(_isNepali ? l.titleNe : l.titleEn),
                          subtitle: Text(
                            _isNepali
                                ? 'बाँकी ${NepaliCalendar.toDevanagariDigits(l.servingsRemaining)} भाग | म्याद: ${l.useByDateIso}'
                                : '${l.servingsRemaining} servings left | Use by: ${l.useByDateIso}',
                            style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
                          ),
                          trailing: ElevatedButton(
                            onPressed: () async {
                              Navigator.pop(ctx);
                              final dummyRecipe = RegionRecipe(
                                id: l.recipeId,
                                titleEn: l.titleEn,
                                titleNe: l.titleNe,
                                category: 'leftover',
                                cuisine: 'nepali',
                                dietary: const [],
                                prepTimeMinutes: 0,
                                cookTimeMinutes: 5,
                                servings: l.servingsRemaining,
                                difficulty: 'easy',
                                pressureCooker: const RecipeWhistleProfile(
                                  enabled: false,
                                  recommendedWhistles: 0,
                                  altitudeWhistleOffsetKathmandu: 0,
                                  heatLevel: 'low',
                                  releaseType: 'quick',
                                ),
                                elevationBand: const RecipeElevationBand(
                                  testedElevationMeters: 1400,
                                  boilingPointCelsius: 95.3,
                                  waterMultiplier: 1.0,
                                ),
                                ingredients: const [],
                                steps: const [],
                                seasonality: const [],
                                tags: const ['leftover'],
                                rating: 5.0,
                                caloriesPerServing: 200,
                                costEstimateNpr: 0,
                              );
                              await _assignMealToSlot(
                                dateIso: dateIso,
                                slotId: slotId,
                                recipe: dummyRecipe,
                                isLeftover: true,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.shade800,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            ),
                            child: Text(_isNepali ? 'छान्नुहोस्' : 'Use'),
                          ),
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            Expanded(
              child: ListView.separated(
                itemCount: recipes.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (ctx, idx) {
                  final recipe = recipes[idx];
                  return ListTile(
                    key: Key('recipe_picker_item_${recipe.id}'),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: SitiColors.terracotta.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.soup_kitchen_rounded,
                          color: SitiColors.terracotta, size: 20),
                    ),
                    title: Text(
                      _isNepali ? recipe.titleNe : recipe.titleEn,
                      style: NepaliTypography.labelLarge.copyWith(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      _isNepali ? recipe.titleEn : recipe.titleNe,
                      style: NepaliTypography.bodySmall.copyWith(color: Colors.grey.shade600),
                    ),
                    trailing: const Icon(Icons.add_circle_outline_rounded,
                        color: SitiColors.terracotta),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _assignMealToSlot(
                        dateIso: dateIso,
                        slotId: slotId,
                        recipe: recipe,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SitiColors.warmWhite,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _isNepali ? 'हप्ताको भोजन योजना (Planner)' : 'Weekly Meal Planner',
          style: NepaliTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w800,
            color: SitiColors.dark,
          ),
        ),
        actions: [
          IconButton(
            key: const Key('open_grocery_list_btn'),
            icon: const Icon(Icons.shopping_basket_rounded, color: SitiColors.terracotta),
            tooltip: _isNepali ? 'किनमेल सूची (Grocery List)' : 'Weekly Grocery List',
            onPressed: _openGroceryListScreen,
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: SitiColors.dark),
            tooltip: _isNepali ? 'भोजन समय अनुकूलन (Rhythms)' : 'Configure Meal Rhythms',
            onPressed: _openRhythmConfigSheet,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Week navigator bar
                _buildWeekNavigator(),

                // 7-Day grid with slots
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: 7,
                    itemBuilder: (context, dayOffset) {
                      final currentDay = _weekStart.add(Duration(days: dayOffset));
                      return _buildDayCard(currentDay);
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildWeekNavigator() {
    final endOfWeek = _weekStart.add(const Duration(days: 6));
    final startStr = '${_weekStart.day} ${_getMonthName(_weekStart.month)}';
    final endStr = '${endOfWeek.day} ${_getMonthName(endOfWeek.month)}, ${endOfWeek.year}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            key: const Key('prev_week_button'),
            icon: const Icon(Icons.chevron_left_rounded, size: 28),
            onPressed: _prevWeek,
          ),
          Row(
            children: [
              const Icon(Icons.calendar_month_rounded, size: 18, color: SitiColors.terracotta),
              const SizedBox(width: 8),
              Text(
                '$startStr – $endStr',
                style: NepaliTypography.titleSmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: SitiColors.dark,
                ),
              ),
            ],
          ),
          IconButton(
            key: const Key('next_week_button'),
            icon: const Icon(Icons.chevron_right_rounded, size: 28),
            onPressed: _nextWeek,
          ),
        ],
      ),
    );
  }

  Widget _buildDayCard(DateTime day) {
    final dateIso = _formatDateIso(day);
    final isToday = _formatDateIso(DateTime.now()) == dateIso;
    final dayNameNe = _getDayNameNe(day.weekday);
    final dayNameEn = _getDayNameEn(day.weekday);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isToday ? SitiColors.terracotta : Colors.grey.shade200,
          width: isToday ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Day Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isToday
                  ? SitiColors.terracotta.withValues(alpha: 0.08)
                  : Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      _isNepali ? dayNameNe : dayNameEn,
                      style: NepaliTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isToday ? SitiColors.terracotta : SitiColors.dark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isNepali
                          ? NepaliCalendar.toDevanagariDigits(day.day)
                          : '${day.day}',
                      style: NepaliTypography.bodySmall.copyWith(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (isToday)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: SitiColors.terracotta,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _isNepali ? 'आज' : 'Today',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Meal rhythm slots for this day
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: _slots.map((slot) {
                final meal = _getMealFor(dateIso, slot.id);
                return _buildSlotRow(dateIso, slot, meal);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlotRow(String dateIso, MealRhythmSlot slot, PlannedMeal? meal) {
    return DragTarget<PlannedMeal>(
      onAcceptWithDetails: (details) async {
        final draggedMeal = details.data;
        if (draggedMeal.dateIso != dateIso || draggedMeal.slotId != slot.id) {
          await widget.repository.movePlannedMeal(
            mealId: draggedMeal.id,
            targetDateIso: dateIso,
            targetSlotId: slot.id,
          );
          await _loadPlannerData();
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isDropTarget = candidateData.isNotEmpty;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDropTarget ? Colors.amber.shade50 : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDropTarget ? Colors.amber.shade600 : Colors.grey.shade200,
              width: isDropTarget ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              // Slot Label & Time
              SizedBox(
                width: 100,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isNepali ? slot.nameNe : slot.nameEn,
                      style: NepaliTypography.labelSmall.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.brown.shade800,
                      ),
                    ),
                    Text(
                      slot.defaultTime,
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Meal Content or Empty Tap-to-add
              Expanded(
                child: meal != null
                    ? _buildSlottedMealCard(meal)
                    : InkWell(
                        key: Key('slot_add_${dateIso}_${slot.id}'),
                        onTap: () => _openRecipePickerModal(dateIso: dateIso, slotId: slot.id),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_rounded, size: 16, color: Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Text(
                                _isNepali ? 'खाना थप्नुहोस्' : 'Add Meal',
                                style: NepaliTypography.labelSmall.copyWith(
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSlottedMealCard(PlannedMeal meal) {
    return LongPressDraggable<PlannedMeal>(
      data: meal,
      feedback: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 220,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: SitiColors.terracotta, width: 2),
          ),
          child: Text(
            _isNepali ? meal.recipeTitleNe : meal.recipeTitleEn,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _buildMealTile(meal),
      ),
      child: _buildMealTile(meal),
    );
  }

  Widget _buildMealTile(PlannedMeal meal) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isNepali ? meal.recipeTitleNe : meal.recipeTitleEn,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: NepaliTypography.labelMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: SitiColors.dark,
                  ),
                ),
                const SizedBox(height: 2),

                // Badges: Seasonal, Diet, Leftover
                Wrap(
                  spacing: 4,
                  runSpacing: 2,
                  children: [
                    if (meal.isLeftover)
                      _buildMiniBadge(
                        label: _isNepali ? 'बचेको (Leftover)' : 'Leftover',
                        color: Colors.orange.shade700,
                        bg: Colors.orange.shade50,
                      ),
                    if (meal.isSeasonal)
                      _buildMiniBadge(
                        label: _isNepali ? 'ऋतु अनुसार' : 'Seasonal',
                        color: Colors.green.shade800,
                        bg: Colors.green.shade50,
                      ),
                    ...meal.dietaryBadges.take(2).map((d) => _buildMiniBadge(
                          label: d,
                          color: Colors.blue.shade800,
                          bg: Colors.blue.shade50,
                        )),
                  ],
                ),
              ],
            ),
          ),

          // Delete/remove button
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 16, color: Colors.grey),
            visualDensity: VisualDensity.compact,
            onPressed: () => _removeMeal(meal.id),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniBadge({
    required String label,
    required Color color,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  Future<void> _openRhythmConfigSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _isNepali ? 'भोजन समय अनुकूलन (Meal Rhythms)' : 'Household Meal Rhythms',
                style: NepaliTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w800,
                  color: SitiColors.dark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isNepali
                    ? 'तपाईंको घरको दिनचर्या अनुसार भोजनको समय तालिका मिलाउनुहोस्।'
                    : 'Customize meal rhythm slots for your household schedule.',
                style: NepaliTypography.bodySmall.copyWith(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              ..._slots.map((s) => ListTile(
                    dense: true,
                    title: Text(_isNepali ? s.nameNe : s.nameEn,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('समय: ${s.defaultTime}'),
                    leading: const Icon(Icons.schedule_rounded, color: SitiColors.terracotta),
                  )),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SitiColors.terracotta,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(_isNepali ? 'ठीक छ' : 'Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getDayNameNe(int weekday) {
    switch (weekday) {
      case 7:
        return 'आइतबार';
      case 1:
        return 'सोमबार';
      case 2:
        return 'मंगलबार';
      case 3:
        return 'बुधबार';
      case 4:
        return 'बिहीबार';
      case 5:
        return 'शुक्रबार';
      case 6:
        return 'शनिबार';
      default:
        return '';
    }
  }

  String _getDayNameEn(int weekday) {
    switch (weekday) {
      case 7:
        return 'Sunday';
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      default:
        return '';
    }
  }

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month - 1];
  }
}
