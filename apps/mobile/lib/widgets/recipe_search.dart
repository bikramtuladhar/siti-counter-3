import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kitchen_engine/kitchen_engine.dart';

import '../theme/nepali_typography.dart';

/// Search over a region pack's recipes.
///
/// A region pack holds hundreds of recipes, so a plain scrolling list is unusable: picking
/// "Khichdi" from a list of several hundred means scrolling past everything. Matches on both
/// the English and Nepali title regardless of the active language, because a Nepali-speaking
/// cook often knows a dish by one name and sees it rendered in the other, and on the fields a
/// cook would actually recall: category, cuisine, tags and dietary suitability.
///
/// Kept as a pure function so the matching rules are testable without a widget tree.
class RecipeSearch {
  /// Filters [recipes] by [query], returning them in their original order.
  ///
  /// An empty or whitespace-only query returns everything, so the field can start empty
  /// without hiding the list.
  static List<RegionRecipe> filter(
    List<RegionRecipe> recipes,
    String query, {
    required bool preferNepali,
  }) {
    final needle = _normalise(query);
    if (needle.isEmpty) return recipes;

    return recipes.where((recipe) => matches(recipe, query, preferNepali: preferNepali)).toList();
  }

  /// Whether a single recipe matches [query].
  static bool matches(
    RegionRecipe recipe,
    String query, {
    required bool preferNepali,
  }) {
    final needle = _normalise(query);
    if (needle.isEmpty) return true;

    final haystacks = <String>[
      recipe.titleEn,
      recipe.titleNe,
      recipe.category,
      recipe.cuisine,
      recipe.difficulty,
      ...recipe.tags,
      ...recipe.dietary,
      ...recipe.seasonality,
      // Ingredient ids are what a pack carries; a cook searching "cauliflower" or
      // "आलु" matches on the id the pack uses for it.
      for (final ingredient in recipe.ingredients) ingredient.ingredientId,
      for (final ingredient in recipe.ingredients) ingredient.notes ?? '',
    ];

    // Every whitespace-separated term must match something, so "dal bhat" narrows rather
    // than widening.
    return needle
        .split(' ')
        .where((term) => term.isNotEmpty)
        .every((term) => haystacks.any((value) => _normalise(value).contains(term)));
  }

  /// Case- and accent-insensitive folding for Latin text.
  ///
  /// Devanagari is left intact: stripping its characters would reduce a Nepali query like
  /// `खिचडी` to an empty string, which matches everything. Only Latin combining marks are
  /// removed, so `cafe` still finds `café` while `दाल भात` still works.
  static String _normalise(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[\u0300-\u036f]'), '')
        .replaceAll(RegExp(r'\s+'), ' ');
  }
}

/// Debounced search field for recipe lists.
class RecipeSearchField extends StatefulWidget {
  final ValueChanged<String> onChanged;
  final bool preferNepali;

  /// How long to wait after a keystroke before reporting, in milliseconds.
  ///
  /// Filtering a few hundred recipes is cheap, but the list rebuilds on every change and
  /// debouncing keeps typing smooth on a low-end device.
  final int debounceMilliseconds;

  final String? hintText;

  const RecipeSearchField({
    super.key,
    required this.onChanged,
    this.preferNepali = true,
    this.debounceMilliseconds = 200,
    this.hintText,
  });

  @override
  State<RecipeSearchField> createState() => _RecipeSearchFieldState();
}

class _RecipeSearchFieldState extends State<RecipeSearchField> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(
      Duration(milliseconds: widget.debounceMilliseconds),
      () => widget.onChanged(value),
    );
    setState(() {});
  }

  void _clear() {
    _debounce?.cancel();
    _controller.clear();
    // Clearing is immediate rather than debounced: the user expects the full list back now.
    widget.onChanged('');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _controller.text.isNotEmpty;

    return TextField(
      key: const Key('recipe_search_field'),
      controller: _controller,
      onChanged: _onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        isDense: true,
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        hintText:
            widget.hintText ??
            (widget.preferNepali
                ? 'परिकार खोज्नुहोस् (खाना वा सामग्री)'
                : 'Search recipes or ingredients'),
        hintStyle: NepaliTypography.bodyMedium.copyWith(color: Colors.grey.shade500),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        suffixIcon: hasText
            ? IconButton(
                key: const Key('recipe_search_clear'),
                icon: const Icon(Icons.close_rounded, size: 18),
                tooltip: widget.preferNepali ? 'हटाउनुहोस्' : 'Clear',
                onPressed: _clear,
              )
            : null,
      ),
    );
  }
}

/// Empty state shown when a search matches nothing.
class RecipeSearchEmpty extends StatelessWidget {
  final String query;
  final bool preferNepali;
  final VoidCallback? onClear;

  const RecipeSearchEmpty({
    super.key,
    required this.query,
    required this.preferNepali,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Column(
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 40,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 12),
          Text(
            preferNepali
                ? '"$query" सँग मिल्ने परिकार भेटिएन'
                : 'No recipes match "$query"',
            textAlign: TextAlign.center,
            style: NepaliTypography.bodyMedium.copyWith(
              color: Colors.grey.shade700,
            ),
          ),
          if (onClear != null) ...[
            const SizedBox(height: 8),
            TextButton(
              key: const Key('recipe_search_empty_clear'),
              onPressed: onClear,
              child: Text(preferNepali ? 'सबै हटाउनुहोस्' : 'Clear search'),
            ),
          ],
        ],
      ),
    );
  }
}
