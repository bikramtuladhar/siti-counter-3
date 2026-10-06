import 'package:flutter/material.dart';
import 'package:kitchen_engine/kitchen_engine.dart';

import '../theme/nepali_typography.dart';
import '../theme/tokens.dart';

/// Meal-time tabs offered in the kitchen recommendations.
///
/// Distinct from the planner's slot ids: here the cook is choosing a time of day to be
/// inspired for, not filling a specific plan slot.
enum RecommendationTime {
  morning('breakfast', 'बिहानी', 'Morning'),
  midday('lunch', 'दिउँसो', 'Midday'),
  evening('evening-snack', 'बेलुका', 'Evening'),
  night('dinner', 'राति', 'Night');

  const RecommendationTime(this.slotId, this.labelNe, this.labelEn);

  /// The planner slot this time maps onto, which is what the engine filters by.
  final String slotId;
  final String labelNe;
  final String labelEn;
}

/// "What should I cook?" recommendations for the kitchen tab.
///
/// Only main courses are ever surfaced as a suggestion. Side dishes are shown as
/// accompaniments beneath the main they go with, because offering one on its own would be
/// suggesting achar for dinner. Which mains qualify depends on the time of day: a dal is a
/// genuine breakfast in Nepal, meat generally is not.
class KitchenRecommendationSection extends StatelessWidget {
  final RegionPack pack;
  final bool preferNepali;

  /// Ritu to prefer when filtering by seasonality. Taken from the screen's own selection
  /// rather than the pack, so recommendations follow the season the cook is browsing.
  final String rituId;

  /// Ingredient ids the household cannot eat. Filtered before anything is shown.
  final Set<String> excludedIngredientIds;

  final ValueChanged<RegionRecipe> onRecipeSelected;

  final int limit;

  const KitchenRecommendationSection({
    super.key,
    required this.pack,
    required this.preferNepali,
    required this.rituId,
    required this.onRecipeSelected,
    this.excludedIngredientIds = const {},
    this.limit = 5,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                size: 18,
                color: SitiColors.terracotta,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  preferNepali ? 'आज के पकाउने?' : 'What should I cook?',
                  style: NepaliTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w800,
                    color: SitiColors.dark,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: RecommendationTime.values.map((time) {
              final suggestions = _suggestionsFor(time);
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _TimeChip(
                  label: preferNepali ? time.labelNe : time.labelEn,
                  count: suggestions.length,
                  onTap: () => _openSheet(context, time, suggestions),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  List<MealSuggestion> _suggestionsFor(RecommendationTime time) {
    return MealSuggestionEngine.suggest(
      recipes: pack.recipes,
      slotId: time.slotId,
      seasonalityRituIds: {rituId},
      excludedIngredientIds: excludedIngredientIds,
      limit: limit,
    );
  }

  void _openSheet(
    BuildContext context,
    RecommendationTime time,
    List<MealSuggestion> suggestions,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _SuggestionsSheet(
        title: preferNepali ? time.labelNe : time.labelEn,
        preferNepali: preferNepali,
        suggestions: suggestions,
        onRecipeSelected: (recipe) {
          Navigator.pop(ctx);
          onRecipeSelected(recipe);
        },
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  final String label;
  final int count;
  final VoidCallback onTap;

  const _TimeChip({
    required this.label,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isEmpty = count == 0;

    return InkWell(
      key: Key('recommendation_chip_$label'),
      onTap: isEmpty ? null : onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isEmpty ? Colors.grey.shade100 : SitiColors.terracotta,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isEmpty ? Colors.grey.shade500 : Colors.white,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              key: Key('recommendation_count_$label'),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isEmpty
                    ? Colors.grey.shade300
                    : Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isEmpty ? Colors.grey.shade700 : Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionsSheet extends StatelessWidget {
  final String title;
  final bool preferNepali;
  final List<MealSuggestion> suggestions;
  final ValueChanged<RegionRecipe> onRecipeSelected;

  const _SuggestionsSheet({
    required this.title,
    required this.preferNepali,
    required this.suggestions,
    required this.onRecipeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
                title,
                style: NepaliTypography.titleLarge.copyWith(
                  fontWeight: FontWeight.w800,
                  color: SitiColors.dark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                preferNepali
                    ? 'मुख्य परिकार मात्र — साथमा खाने परिकारहरूसहित।'
                    : 'Main courses only, each with its accompaniments.',
                style: NepaliTypography.bodySmall.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: suggestions.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Text(
                          preferNepali
                              ? 'यो समयका लागि उपयुक्त मुख्य परिकार छैन।'
                              : 'No suitable main course for this time.',
                          textAlign: TextAlign.center,
                          style: NepaliTypography.bodyMedium.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: suggestions.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (ctx, index) {
                          final suggestion = suggestions[index];
                          return ListTile(
                            key: Key(
                              'suggestion_${suggestion.mainCourse.id}',
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 4),
                            title: Text(
                              preferNepali
                                  ? suggestion.mainCourse.titleNe
                                  : suggestion.mainCourse.titleEn,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  preferNepali
                                      ? suggestion.mainCourse.titleEn
                                      : suggestion.mainCourse.titleNe,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  preferNepali
                                      ? suggestion.reasonNe
                                      : suggestion.reasonEn,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: SitiColors.terracotta,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                                if (suggestion.sideDishes.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: [
                                        for (final side in suggestion.sideDishes)
                                          Chip(
                                            key: Key('side_dish_${side.id}'),
                                            label: Text(
                                              preferNepali
                                                  ? side.titleNe
                                                  : side.titleEn,
                                              style: const TextStyle(fontSize: 11),
                                            ),
                                            visualDensity: VisualDensity.compact,
                                            backgroundColor: Colors.grey.shade100,
                                          ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            trailing: const Icon(
                              Icons.chevron_right_rounded,
                              color: SitiColors.terracotta,
                            ),
                            onTap: () => onRecipeSelected(suggestion.mainCourse),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}