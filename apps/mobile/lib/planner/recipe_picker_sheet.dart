import 'package:flutter/material.dart';
import 'package:kitchen_engine/kitchen_engine.dart';
import 'package:kitchen_engine/nepali_calendar.dart';
import 'package:kitchen_engine/region_pack.dart';

import '../planner/planner_models.dart';
import '../theme/nepali_typography.dart';
import '../theme/tokens.dart';
import '../widgets/recipe_search.dart';

/// Searchable recipe picker for a meal slot.
///
/// Extracted from the planner screen because it was an inline 75%-height sheet with its own
/// list, leftover suggestions and actions: holding the query in a [StatefulWidget] keeps
/// typing from rebuilding the planner underneath, and makes the search independently
/// testable.
class RecipePickerSheet extends StatefulWidget {
  final List<RegionRecipe> recipes;
  final List<LeftoverItem> leftovers;
  final bool preferNepali;

  /// Called with the chosen recipe. The sheet closes itself first.
  final ValueChanged<RegionRecipe> onSelectRecipe;

  /// Called with a leftover the user chose to use up instead of cooking.
  final ValueChanged<LeftoverItem> onUseLeftover;

  const RecipePickerSheet({
    super.key,
    required this.recipes,
    required this.leftovers,
    required this.preferNepali,
    required this.onSelectRecipe,
    required this.onUseLeftover,
  });

  /// Wraps a leftover as a recipe so the planner's assignment path stays single-shaped.
  static RegionRecipe leftoverAsRecipe(LeftoverItem leftover) {
    return RegionRecipe(
      id: leftover.recipeId,
      titleEn: leftover.titleEn,
      titleNe: leftover.titleNe,
      category: 'leftover',
      cuisine: 'nepali',
      dietary: const [],
      prepTimeMinutes: 0,
      cookTimeMinutes: 5,
      servings: leftover.servingsRemaining,
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
  }

  @override
  State<RecipePickerSheet> createState() => _RecipePickerSheetState();
}

class _RecipePickerSheetState extends State<RecipePickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _isNe => widget.preferNepali;

  List<RegionRecipe> get _filtered =>
      RecipeSearch.filter(widget.recipes, _query, preferNepali: _isNe);

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final isSearching = _query.trim().isNotEmpty;

    // Material rather than a decorated Container: a ListTile paints its ink on the nearest
    // Material ancestor, so a coloured DecoratedBox in between makes taps invisible and
    // trips a debug assertion.
    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
                _isNe ? 'खाना छान्नुहोस् (Select Recipe)' : 'Select Recipe',
                style: NepaliTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w800,
                  color: SitiColors.dark,
                ),
              ),
              const SizedBox(height: 12),

              RecipeSearchField(
                preferNepali: _isNe,
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 8),

              if (widget.leftovers.isNotEmpty) ...[
                Container(
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  // Same reason as the sheet surface: the leftover tiles need a Material to
                  // paint their ink on.
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(13),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 16,
                                color: Colors.orange.shade900,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _isNe
                                    ? 'फ्रिजमा बचेको खाना (Leftovers)'
                                    : 'Available Leftovers',
                                style: NepaliTypography.labelMedium.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.orange.shade900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...widget.leftovers.map(
                            (leftover) => ListTile(
                              key: Key('leftover_option_${leftover.id}'),
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                _isNe ? leftover.titleNe : leftover.titleEn,
                              ),
                              subtitle: Text(
                                _isNe
                                    ? 'बाँकी ${NepaliCalendar.toDevanagariDigits(leftover.servingsRemaining)} भाग | म्याद: ${leftover.useByDateIso}'
                                    : '${leftover.servingsRemaining} servings left | Use by: ${leftover.useByDateIso}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange.shade800,
                                ),
                              ),
                              trailing: ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  widget.onUseLeftover(leftover);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange.shade800,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                ),
                                child: Text(_isNe ? 'छान्नुहोस्' : 'Use'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              if (isSearching)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    _isNe
                        ? '${filtered.length} / ${widget.recipes.length} परिकार'
                        : '${filtered.length} of ${widget.recipes.length} recipes',
                    style: NepaliTypography.bodySmall.copyWith(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

              Expanded(
                child: filtered.isEmpty
                    ? RecipeSearchEmpty(
                        key: const Key('recipe_picker_empty'),
                        query: _query,
                        preferNepali: _isNe,
                        onClear: _clearSearch,
                      )
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (ctx, idx) {
                          final recipe = filtered[idx];
                          return ListTile(
                            key: Key('recipe_picker_item_${recipe.id}'),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: SitiColors.terracotta.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.soup_kitchen_rounded,
                                color: SitiColors.terracotta,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              _isNe ? recipe.titleNe : recipe.titleEn,
                              style: NepaliTypography.labelLarge.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              _isNe ? recipe.titleEn : recipe.titleNe,
                              style: NepaliTypography.bodySmall.copyWith(
                                color: Colors.grey.shade600,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.add_circle_outline_rounded,
                              color: SitiColors.terracotta,
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              widget.onSelectRecipe(recipe);
                            },
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
