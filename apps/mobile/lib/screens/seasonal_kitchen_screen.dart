library;

import 'package:flutter/material.dart';
import 'package:kitchen_engine/nepali_calendar.dart';
import 'package:kitchen_engine/region_pack.dart';
import '../data/region_pack_repository.dart';
import '../theme/nepali_typography.dart';
import '../theme/tokens.dart';
import '../widgets/recipe_search.dart';
import 'recipe_detail_screen.dart';
import 'region_manager_screen.dart';

class SeasonalKitchenScreen extends StatefulWidget {
  final RegionPack? initialPack;
  final String currentLanguage;
  final String initialRituId;
  final void Function(RegionRecipe recipe)? onRecipeSelected;
  final void Function(RegionIngredient ingredient)? onAddToGroceryList;

  const SeasonalKitchenScreen({
    super.key,
    this.initialPack,
    this.currentLanguage = 'ne',
    this.initialRituId = 'sharad',
    this.onRecipeSelected,
    this.onAddToGroceryList,
  });

  @override
  State<SeasonalKitchenScreen> createState() => _SeasonalKitchenScreenState();
}

class _SeasonalKitchenScreenState extends State<SeasonalKitchenScreen> {
  RegionPack? _regionPack;
  bool _isLoading = true;
  String? _errorMessage;

  late String _selectedRituId;
  String _selectedCategoryFilter = 'all'; // all, peak, in_season, vegetables, spices

  final Set<String> _addedToGroceryIds = {};

  /// Search query for the recipes shown for the selected ingredient.
  String _recipeQuery = '';

  bool get _isNepali => widget.currentLanguage == 'ne';

  @override
  void initState() {
    super.initState();
    _selectedRituId = widget.initialRituId;

    if (widget.initialPack != null) {
      _regionPack = widget.initialPack;
      _isLoading = false;
    } else {
      _loadPack();
    }
  }

  Future<void> _loadPack() async {
    try {
      final pack = await RegionPackRepository().loadRegionPack();
      if (mounted) {
        setState(() {
          _regionPack = pack;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _onAddIngredientToList(RegionIngredient ingredient) {
    setState(() {
      _addedToGroceryIds.add(ingredient.id);
    });

    if (widget.onAddToGroceryList != null) {
      widget.onAddToGroceryList!(ingredient);
    }

    final ingredientName = _isNepali ? ingredient.nameNe : ingredient.nameEn;
    final message = _isNepali
        ? 'थपियो: $ingredientName किराना सूचीमा'
        : 'Added $ingredientName to grocery list';

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: NepaliTypography.bodyMedium.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: SitiColors.dark,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: SnackBarAction(
          label: _isNepali ? 'हटाउनुहोस्' : 'Undo',
          textColor: Colors.amber,
          onPressed: () {
            setState(() {
              _addedToGroceryIds.remove(ingredient.id);
            });
          },
        ),
      ),
    );
  }

  void _showRecipesBottomSheet(RegionIngredient ingredient) {
    if (_regionPack == null) return;
    // Search narrows the recipes for this ingredient rather than replacing the whole
    // browsing surface, so the ingredient the cook chose stays visible above the results.
    final matchingRecipes = RecipeSearch.filter(
      _regionPack!.getRecipesForIngredient(ingredient.id),
      _recipeQuery,
      preferNepali: _isNepali,
    );
    final ingredientName = _isNepali ? ingredient.nameNe : ingredient.nameEn;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SitiColors.warmWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isNepali ? 'सम्बन्धित परिकारहरू' : 'Matching Recipes',
                              style: NepaliTypography.titleSmall.copyWith(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              ingredientName,
                              style: NepaliTypography.headlineMedium.copyWith(
                                color: SitiColors.dark,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: SitiColors.terracotta.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _isNepali
                              ? '${NepaliCalendar.toDevanagariDigits(matchingRecipes.length)} परिकार'
                              : '${matchingRecipes.length} recipes',
                          style: NepaliTypography.labelLarge.copyWith(
                            color: SitiColors.terracotta,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 16),
                RecipeSearchField(
                  preferNepali: _isNepali,
                  hintText: _isNepali
                      ? 'यस सामग्रीका परिकार खोज्नुहोस्'
                      : 'Search these recipes',
                  onChanged: (value) => setState(() => _recipeQuery = value),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: matchingRecipes.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.soup_kitchen_outlined,
                                    size: 48, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                Text(
                                  _isNepali
                                      ? (_recipeQuery.trim().isEmpty
                                            ? 'यस सामग्रीको लागि कुनै सिधा रेसिपी भेटिएन'
                                            : '"$_recipeQuery" सँग मिल्ने परिकार भेटिएन')
                                      : (_recipeQuery.trim().isEmpty
                                            ? 'No direct recipes found for this ingredient'
                                            : 'No recipes match "$_recipeQuery"'),
                                  textAlign: TextAlign.center,
                                  style: NepaliTypography.bodyMedium.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          itemCount: matchingRecipes.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final recipe = matchingRecipes[index];
                            final title = _isNepali ? recipe.titleNe : recipe.titleEn;
                            final subtitle = _isNepali ? recipe.titleEn : recipe.titleNe;

                            return Card(
                              elevation: 0,
                              color: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(color: Colors.grey.shade200),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                leading: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: SitiColors.terracotta.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.restaurant_rounded,
                                    color: SitiColors.terracotta,
                                  ),
                                ),
                                title: Text(
                                  title,
                                  style: NepaliTypography.titleMedium.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: SitiColors.dark,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 2),
                                    Text(
                                      subtitle,
                                      style: NepaliTypography.bodySmall.copyWith(
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Icon(Icons.timer_outlined,
                                            size: 14, color: Colors.grey.shade600),
                                        const SizedBox(width: 4),
                                        Text(
                                          _isNepali
                                              ? '${NepaliCalendar.toDevanagariDigits(recipe.cookTimeMinutes)} मिनेट'
                                              : '${recipe.cookTimeMinutes}m',
                                          style: NepaliTypography.labelSmall.copyWith(
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                        if (recipe.pressureCooker.enabled) ...[
                                          const SizedBox(width: 12),
                                          Icon(Icons.speed_rounded,
                                              size: 14, color: SitiColors.terracotta),
                                          const SizedBox(width: 4),
                                          Text(
                                            _isNepali
                                                ? '${NepaliCalendar.toDevanagariDigits(recipe.pressureCooker.recommendedWhistles)} सिट्ठी'
                                                : '${recipe.pressureCooker.recommendedWhistles} whistles',
                                            style: NepaliTypography.labelSmall.copyWith(
                                              color: SitiColors.terracotta,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: const Icon(Icons.arrow_forward_ios_rounded,
                                    size: 16, color: Colors.grey),
                                onTap: () {
                                  Navigator.pop(modalContext);
                                  if (widget.onRecipeSelected != null) {
                                    widget.onRecipeSelected!(recipe);
                                  } else {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute<void>(
                                        builder: (_) => RecipeDetailScreen(
                                          recipe: recipe,
                                          currentLanguage: widget.currentLanguage,
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showPreservationDetailDialog(PreservationSuggestion suggestion) {
    final title = _isNepali ? suggestion.titleNe : suggestion.titleEn;
    final description = _isNepali ? suggestion.descriptionNe : suggestion.descriptionEn;

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: SitiColors.warmWhite,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.wb_sunny_rounded, color: Colors.amber.shade900, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: NepaliTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: SitiColors.dark,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  description,
                  style: NepaliTypography.bodyMedium.copyWith(
                    color: SitiColors.dark,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isNepali ? 'विधि (Method):' : 'Method:',
                        style: NepaliTypography.labelLarge.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        suggestion.method,
                        style: NepaliTypography.bodySmall.copyWith(
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                _isNepali ? 'बन्द गर्नुहोस्' : 'Close',
                style: NepaliTypography.labelLarge.copyWith(color: SitiColors.terracotta),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: SitiColors.warmWhite,
        body: Center(
          child: CircularProgressIndicator(color: SitiColors.terracotta),
        ),
      );
    }

    if (_errorMessage != null || _regionPack == null) {
      return Scaffold(
        backgroundColor: SitiColors.warmWhite,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, size: 48, color: SitiColors.alert),
                const SizedBox(height: 16),
                Text(
                  _isNepali
                      ? 'सिजनल भान्सा लोड गर्न सकिएन'
                      : 'Could not load Seasonal Kitchen',
                  style: NepaliTypography.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage ?? '',
                  textAlign: TextAlign.center,
                  style: NepaliTypography.bodyMedium.copyWith(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                      _errorMessage = null;
                    });
                    _loadPack();
                  },
                  child: Text(_isNepali ? 'पुन: प्रयास' : 'Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final pack = _regionPack!;
    final ritu = pack.seasonality.ritus.cast<RituSeason?>().firstWhere(
          (r) => r?.id == _selectedRituId,
          orElse: () => pack.seasonality.ritus.first,
        )!;

    // Filter ingredients
    final filteredIngredients = pack.ingredients.where((ingredient) {
      final availability = pack.getIngredientAvailability(ingredient.id, _selectedRituId);
      switch (_selectedCategoryFilter) {
        case 'peak':
          return availability == AvailabilityLevel.peak;
        case 'in_season':
          return availability == AvailabilityLevel.peak ||
              availability == AvailabilityLevel.inSeason;
        case 'vegetables':
          return ingredient.category == 'vegetables';
        case 'spices':
          return ingredient.category == 'spices' || ingredient.category == 'herbs';
        case 'all':
        default:
          return true;
      }
    }).toList();

    // Sort to show peak & in_season first
    filteredIngredients.sort((a, b) {
      final aLevel = pack.getIngredientAvailability(a.id, _selectedRituId);
      final bLevel = pack.getIngredientAvailability(b.id, _selectedRituId);
      return aLevel.index.compareTo(bLevel.index);
    });

    return Scaffold(
      backgroundColor: SitiColors.warmWhite,
      appBar: AppBar(
        backgroundColor: SitiColors.warmWhite,
        elevation: 0,
        title: Text(
          _isNepali ? 'सिजनल भान्सा' : 'Seasonal Kitchen',
          style: NepaliTypography.titleLarge.copyWith(
            fontWeight: FontWeight.w700,
            color: SitiColors.dark,
          ),
        ),
        actions: [
          IconButton(
            key: const Key('seasonal_kitchen_region_manager_btn'),
            icon: const Icon(Icons.public_rounded, color: SitiColors.terracotta),
            tooltip: _isNepali ? 'क्षेत्र व्यवस्थापन' : 'Region Packs',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RegionManagerScreen(
                    currentLanguage: widget.currentLanguage,
                  ),
                ),
              );
              _loadPack();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header: Local season and region (Sharad ritu · October · Bagmati)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: _buildSeasonHeader(ritu, pack.manifest),
              ),
            ),

            // Ritu Picker Carousel
            SliverToBoxAdapter(
              child: SizedBox(
                height: 48,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  itemCount: pack.seasonality.ritus.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final item = pack.seasonality.ritus[index];
                    final isSelected = item.id == _selectedRituId;
                    return ChoiceChip(
                      selected: isSelected,
                      label: Text(
                        item.name,
                        style: NepaliTypography.labelLarge.copyWith(
                          color: isSelected ? Colors.white : SitiColors.dark,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      selectedColor: SitiColors.terracotta,
                      backgroundColor: Colors.white,
                      side: BorderSide(
                        color: isSelected ? SitiColors.terracotta : Colors.grey.shade300,
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedRituId = item.id;
                          });
                        }
                      },
                    );
                  },
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // Preservation Recommendations Banner (Achar, Gundruk, dried vegetables during peak harvest)
            if (pack.preservationSuggestions.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildPreservationSection(pack.preservationSuggestions),
                ),
              ),

            // Category Filter Chips
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 20, bottom: 12),
                child: SizedBox(
                  height: 40,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildFilterChip('all', _isNepali ? 'सबै' : 'All'),
                      const SizedBox(width: 8),
                      _buildFilterChip('peak', _isNepali ? 'उत्कृष्ट (Peak)' : 'Peak Only'),
                      const SizedBox(width: 8),
                      _buildFilterChip('in_season', _isNepali ? 'सिजनमा (In-Season)' : 'In Season'),
                      const SizedBox(width: 8),
                      _buildFilterChip('vegetables', _isNepali ? 'तरकारी' : 'Vegetables'),
                      const SizedBox(width: 8),
                      _buildFilterChip('spices', _isNepali ? 'मसला' : 'Spices & Herbs'),
                    ],
                  ),
                ),
              ),
            ),

            // Section title: Fresh Market Produce
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isNepali ? 'बजारमा ताजा पाइने सामग्री' : 'Fresh in Market Now',
                      style: NepaliTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: SitiColors.dark,
                      ),
                    ),
                    Text(
                      _isNepali
                          ? '${NepaliCalendar.toDevanagariDigits(filteredIngredients.length)} सामग्री'
                          : '${filteredIngredients.length} items',
                      style: NepaliTypography.bodySmall.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),

            // Ingredient Cards List
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final ingredient = filteredIngredients[index];
                    final availability =
                        pack.getIngredientAvailability(ingredient.id, _selectedRituId);
                    final matchingRecipeCount =
                        pack.getRecipesForIngredient(ingredient.id).length;
                    final isAddedToGrocery = _addedToGroceryIds.contains(ingredient.id);

                    return _buildIngredientCard(
                      ingredient: ingredient,
                      availability: availability,
                      recipeCount: matchingRecipeCount,
                      isAddedToGrocery: isAddedToGrocery,
                    );
                  },
                  childCount: filteredIngredients.length,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  Widget _buildSeasonHeader(RituSeason ritu, RegionPackManifest manifest) {
    // Format: Sharad ritu · October · Bagmati
    final monthsBs = ritu.monthsBS.join('-');
    final monthsEn = ritu.monthsGregorian.join('/');
    final regionName = _isNepali ? 'बागमती' : manifest.region;

    final headerSubtitle = _isNepali
        ? '${ritu.name} · $monthsBs · $regionName'
        : '${ritu.id.toUpperCase()} · $monthsEn · $regionName';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            SitiColors.terracotta,
            SitiColors.terracotta.withValues(alpha: 0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: SitiColors.terracotta.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.eco_rounded, size: 14, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      _isNepali ? 'वर्तमान मौसम' : 'Current Season',
                      style: NepaliTypography.labelSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  manifest.name,
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  style: NepaliTypography.labelSmall.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            headerSubtitle,
            style: NepaliTypography.headlineSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _isNepali
                ? 'स्थानीय बजारमा ताजा पाइने सामग्रीहरू र परिकारहरू:'
                : 'Ingredients freshest in your local market now & what to cook:',
            style: NepaliTypography.bodySmall.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          if (ritu.signatureProduce.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: ritu.signatureProduce.take(3).map((produce) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    produce,
                    style: NepaliTypography.labelSmall.copyWith(
                      color: Colors.white,
                      fontSize: 11,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreservationSection(List<PreservationSuggestion> suggestions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.wb_sunny_rounded, size: 18, color: Colors.amber),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _isNepali
                    ? 'परम्परागत संरक्षण र अचार सिफारिस'
                    : 'Seasonal Preservation & Fermentation',
                style: NepaliTypography.titleSmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: SitiColors.dark,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 130,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: suggestions.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = suggestions[index];
              final title = _isNepali ? item.titleNe : item.titleEn;
              final desc = _isNepali ? item.descriptionNe : item.descriptionEn;

              return InkWell(
                onTap: () => _showPreservationDetailDialog(item),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 250,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.inventory_2_outlined,
                              size: 16, color: Colors.amber.shade900),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: NepaliTypography.titleSmall.copyWith(
                                fontWeight: FontWeight.w700,
                                color: Colors.amber.shade900,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: Text(
                          desc,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: NepaliTypography.bodySmall.copyWith(
                            color: Colors.brown.shade800,
                            fontSize: 11,
                            height: 1.35,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isNepali ? 'विस्तारमा हेर्नुहोस् →' : 'Learn method →',
                        style: NepaliTypography.labelSmall.copyWith(
                          color: SitiColors.terracotta,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedCategoryFilter == key;
    return ChoiceChip(
      selected: isSelected,
      label: Text(
        label,
        style: NepaliTypography.labelSmall.copyWith(
          color: isSelected ? Colors.white : SitiColors.dark,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      selectedColor: SitiColors.dark,
      backgroundColor: Colors.white,
      side: BorderSide(
        color: isSelected ? SitiColors.dark : Colors.grey.shade300,
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedCategoryFilter = key;
          });
        }
      },
    );
  }

  Widget _buildIngredientCard({
    required RegionIngredient ingredient,
    required AvailabilityLevel availability,
    required int recipeCount,
    required bool isAddedToGrocery,
  }) {
    final title = _isNepali ? ingredient.nameNe : ingredient.nameEn;
    final subtitle = _isNepali ? ingredient.nameEn : ingredient.nameNe;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: availability == AvailabilityLevel.peak
              ? SitiColors.freshGreen.withValues(alpha: 0.3)
              : Colors.grey.shade200,
          width: availability == AvailabilityLevel.peak ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Visual Icon Avatar
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: _getCategoryColor(ingredient.category).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Icon(
                    _getCategoryIcon(ingredient.category),
                    color: _getCategoryColor(ingredient.category),
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Title, Subtitle, Recipe count
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: NepaliTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.w700,
                              color: SitiColors.dark,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildAvailabilityBadge(availability),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: NepaliTypography.bodySmall.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isNepali
                          ? '${NepaliCalendar.toDevanagariDigits(recipeCount)} परिकारमा प्रयोग'
                          : '$recipeCount recipes use this',
                      style: NepaliTypography.labelSmall.copyWith(
                        color: SitiColors.terracotta,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 8),

          // Actions: "See recipes" and "Add to list"
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showRecipesBottomSheet(ingredient),
                  icon: const Icon(Icons.menu_book_rounded, size: 16),
                  label: Text(
                    _isNepali ? 'रेसिपी हेर्नुहोस्' : 'See recipes',
                    style: NepaliTypography.labelMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: SitiColors.dark,
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _onAddIngredientToList(ingredient),
                  icon: Icon(
                    isAddedToGrocery ? Icons.check_rounded : Icons.add_shopping_cart_rounded,
                    size: 16,
                  ),
                  label: Text(
                    isAddedToGrocery
                        ? (_isNepali ? 'सूचीमा थपियो' : 'In List')
                        : (_isNepali ? 'सूचीमा थप्नुहोस्' : 'Add to list'),
                    style: NepaliTypography.labelMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isAddedToGrocery ? SitiColors.freshGreen : Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isAddedToGrocery ? Colors.green.shade50 : SitiColors.terracotta,
                    foregroundColor:
                        isAddedToGrocery ? SitiColors.freshGreen : Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: isAddedToGrocery
                          ? const BorderSide(color: SitiColors.freshGreen)
                          : BorderSide.none,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvailabilityBadge(AvailabilityLevel availability) {
    Color bg;
    Color fg;

    switch (availability) {
      case AvailabilityLevel.peak:
        bg = SitiColors.freshGreen.withValues(alpha: 0.15);
        fg = SitiColors.freshGreen;
        break;
      case AvailabilityLevel.inSeason:
        bg = Colors.green.shade50;
        fg = Colors.green.shade800;
        break;
      case AvailabilityLevel.available:
        bg = Colors.amber.shade50;
        fg = Colors.amber.shade900;
        break;
      case AvailabilityLevel.limited:
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade900;
        break;
      case AvailabilityLevel.outOfSeason:
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade600;
        break;
    }

    final label = _isNepali ? availability.labelNe : availability.labelEn;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: NepaliTypography.labelSmall.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'vegetables':
        return Icons.grass_rounded;
      case 'spices':
      case 'herbs':
        return Icons.flare_rounded;
      case 'legumes':
      case 'pulses':
        return Icons.grain_rounded;
      case 'dairy':
        return Icons.water_drop_rounded;
      case 'grains':
        return Icons.bakery_dining_rounded;
      default:
        return Icons.kitchen_rounded;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'vegetables':
        return SitiColors.freshGreen;
      case 'spices':
      case 'herbs':
        return SitiColors.terracotta;
      case 'legumes':
      case 'pulses':
        return Colors.brown;
      case 'dairy':
        return Colors.blue;
      default:
        return Colors.deepOrange;
    }
  }
}
