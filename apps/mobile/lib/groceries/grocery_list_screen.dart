import 'package:flutter/material.dart';
import 'package:kitchen_engine/kitchen_engine.dart';
import 'package:kitchen_engine/nepali_calendar.dart';
import 'package:kitchen_engine/region_pack.dart';
import '../commerce/market_price_service.dart';
import '../commerce/retailer_handoff_service.dart';
import '../commerce/retailer_handoff_sheet.dart';
import '../data/region_pack_repository.dart';
import '../planner/planner_repository.dart';
import 'market_mode_screen.dart';
import '../theme/nepali_typography.dart';
import '../theme/tokens.dart';
import '../widgets/load_failure_state.dart';

/// Screen displaying the automated grocery list generated from the weekly meal plan,
/// categorized into traditional Haat Bazaar / Kalimati market stalls (Vegetables, Fruit,
/// Meat/Fish, Spices, Grains/Staples), with quantities in vendor units (pau, kg, mana, bunches).
class GroceryListScreen extends StatefulWidget {
  final DateTime weekStart;
  final WeeklyPlannerRepository repository;
  final RegionPackRepository? regionPackRepository;
  final MarketPriceService? marketPriceService;
  final RetailerHandoffService? retailerHandoffService;
  final String currentLanguage;
  final void Function(GroceryListResult result)? onOpenMarketMode;

  const GroceryListScreen({
    super.key,
    required this.weekStart,
    required this.repository,
    this.regionPackRepository,
    this.marketPriceService,
    this.retailerHandoffService,
    this.currentLanguage = 'ne',
    this.onOpenMarketMode,
  });

  @override
  State<GroceryListScreen> createState() => _GroceryListScreenState();
}

class _GroceryListScreenState extends State<GroceryListScreen> {
  bool _isLoading = true;

  /// Set when the list could not be built. Previously the failure was swallowed and the user
  /// was shown an empty list, which is indistinguishable from "you planned nothing".
  String? _errorMessage;

  String _selectedStallId = 'all';
  late String _language;

  List<RegionRecipe> _recipes = [];
  List<RegionIngredient> _ingredients = [];
  Map<String, double> _pantry = {};
  GroceryListResult? _groceryResult;

  bool get _isNepali => _language == 'ne';

  @override
  void initState() {
    super.initState();
    _language = widget.currentLanguage;
    widget.retailerHandoffService?.addListener(_onRetailerServiceChanged);
    _loadData();
  }

  @override
  void dispose() {
    widget.retailerHandoffService?.removeListener(_onRetailerServiceChanged);
    super.dispose();
  }

  void _onRetailerServiceChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final packRepo = widget.regionPackRepository ?? RegionPackRepository();
      final pack = await packRepo.loadRegionPack();
      _recipes = pack.recipes;
      _ingredients = pack.ingredients;

      final plannedMeals = await widget.repository.getPlannedMealsForWeek(widget.weekStart);
      final pantryItems = await widget.repository.getPantryItems();
      _pantry = pantryItems;

      final mealInputs = plannedMeals.map((m) {
        return GroceryPlanMealInput(
          recipeId: m.recipeId,
          servings: m.servings,
          recipeTitleEn: m.recipeTitleEn,
          recipeTitleNe: m.recipeTitleNe,
          dateIso: m.dateIso,
          slotId: m.slotId,
        );
      }).toList();

      final marketPrices = widget.marketPriceService?.toEnginePricesMap();
      final result = generateGroceryListFromRegion(
        meals: mealInputs,
        recipes: _recipes,
        ingredients: _ingredients,
        pantryAvailableGrams: _pantry,
        marketPrices: marketPrices,
      );

      if (mounted) {
        setState(() {
          _groceryResult = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = _isNepali
              ? 'किनमेल सूची बनाउन सकिएन। कृपया पुनः प्रयास गर्नुहोस्।'
              : 'Could not build the grocery list. Please try again.';
        });
      }
    }
  }

  Future<void> _togglePantryStatus(GroceryItem item) async {
    final willHaveInPantry = !item.isSufficientInPantry;
    if (willHaveInPantry) {
      await widget.repository.setPantryItem(item.ingredientId, item.totalRequiredGrams);
      _pantry[item.ingredientId] = item.totalRequiredGrams;
    } else {
      await widget.repository.removePantryItem(item.ingredientId);
      _pantry.remove(item.ingredientId);
    }

    final plannedMeals = await widget.repository.getPlannedMealsForWeek(widget.weekStart);
    final mealInputs = plannedMeals.map((m) {
      return GroceryPlanMealInput(
        recipeId: m.recipeId,
        servings: m.servings,
        recipeTitleEn: m.recipeTitleEn,
        recipeTitleNe: m.recipeTitleNe,
        dateIso: m.dateIso,
        slotId: m.slotId,
      );
    }).toList();

    final marketPrices = widget.marketPriceService?.toEnginePricesMap();
    final updatedResult = generateGroceryListFromRegion(
      meals: mealInputs,
      recipes: _recipes,
      ingredients: _ingredients,
      pantryAvailableGrams: _pantry,
      marketPrices: marketPrices,
    );

    if (mounted) {
      setState(() {
        _groceryResult = updatedResult;
      });
    }
  }

  String _formatDateRange() {
    final endOfWeek = widget.weekStart.add(const Duration(days: 6));
    final startDay = _isNepali
        ? NepaliCalendar.toDevanagariDigits(widget.weekStart.day)
        : '${widget.weekStart.day}';
    final endDay = _isNepali
        ? NepaliCalendar.toDevanagariDigits(endOfWeek.day)
        : '${endOfWeek.day}';
    final year = _isNepali
        ? NepaliCalendar.toDevanagariDigits(widget.weekStart.year)
        : '${widget.weekStart.year}';

    return '$startDay – $endDay (${_isNepali ? "हप्ता" : "Week"}, $year)';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SitiColors.warmWhite,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: SitiColors.dark),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isNepali ? 'किनमेल सूची (हाट बजार)' : 'Weekly Grocery List',
              style: NepaliTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w800,
                color: SitiColors.dark,
              ),
            ),
            Text(
              _formatDateRange(),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          if (widget.retailerHandoffService?.partnerLinksEnabled ?? true) ...[
            IconButton(
              key: const Key('shop_online_btn'),
              tooltip: _isNepali ? 'अनलाइन अर्डर (Daraz, Bhatbhateni)' : 'Order Online',
              icon: const Icon(Icons.shopping_bag_outlined, color: SitiColors.terracotta),
              onPressed: () {
                final neededItems = _groceryResult?.items
                        .where((i) => !i.isSufficientInPantry)
                        .map((i) => _isNepali ? i.nameNe : i.nameEn)
                        .toList() ??
                    [];
                RetailerHandoffSheet.show(
                  context: context,
                  retailerService:
                      widget.retailerHandoffService ?? RetailerHandoffService(),
                  basketItemNames: neededItems,
                  currentLanguage: _language,
                );
              },
            ),
          ],
          TextButton(
            key: const Key('toggle_language_btn'),
            onPressed: () {
              setState(() {
                _language = _isNepali ? 'en' : 'ne';
              });
            },
            child: Text(
              _isNepali ? 'EN' : 'नेपाली',
              style: const TextStyle(
                color: SitiColors.terracotta,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : (_errorMessage != null)
              ? _buildErrorState()
              : (_groceryResult == null || _groceryResult!.items.isEmpty)
                  ? _buildEmptyState()
                  : Column(
                  children: [
                      _buildSummaryCard(_groceryResult!),
                      _buildStallFilterTabs(_groceryResult!),
                      Expanded(
                        child: _buildStallsList(_groceryResult!),
                      ),
                      _buildBottomActionBar(_groceryResult!),
                    ],
                  ),
    );
  }

  /// Shown when the list could not be built at all.
  Widget _buildErrorState() => LoadFailureState.bilingual(
    preferNepali: _isNepali,
    detailEn: 'The grocery list could not be built.',
    detailNe: 'किनमेल सूची बनाउन सकिएन।',
    onRetry: _loadData,
  );

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.shopping_basket_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              _isNepali ? 'यस हप्ताको कुनै भोजन योजना छैन' : 'No meals planned for this week',
              style: NepaliTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: Colors.brown.shade800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _isNepali
                  ? 'पहिले हप्ताको भोजन तालिकामा खाना थप्नुहोस्, त्यसपछि किनमेल सूची स्वतः तयार हुनेछ।'
                  : 'Add recipes to your weekly meal planner first. Your grocery list will be automatically generated with stall grouping.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(GroceryListResult result) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryMetric(
            keyName: 'metric_to_buy',
            label: _isNepali ? 'किन्नुपर्ने' : 'To Buy',
            value: _isNepali
                ? NepaliCalendar.toDevanagariDigits(result.totalItemsToBuy)
                : '${result.totalItemsToBuy}',
            color: SitiColors.terracotta,
            icon: Icons.shopping_bag_outlined,
          ),
          Container(width: 1, height: 36, color: Colors.grey.shade200),
          _buildSummaryMetric(
            keyName: 'metric_in_pantry',
            label: _isNepali ? 'घरमै छ' : 'In Pantry',
            value: _isNepali
                ? NepaliCalendar.toDevanagariDigits(result.totalPantryCoveredItems)
                : '${result.totalPantryCoveredItems}',
            color: Colors.green.shade700,
            icon: Icons.inventory_2_outlined,
          ),
          Container(width: 1, height: 36, color: Colors.grey.shade200),
          _buildSummaryMetric(
            keyName: 'metric_surplus',
            label: _isNepali ? 'बचत मात्रा' : 'Surplus',
            value: _isNepali
                ? '${NepaliCalendar.toDevanagariDigits(result.totalSurplusGrams.round())}g'
                : '${result.totalSurplusGrams.round()}g',
            color: Colors.amber.shade800,
            icon: Icons.eco_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryMetric({
    required String keyName,
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Column(
      key: Key(keyName),
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildStallFilterTabs(GroceryListResult result) {
    final stalls = result.stalls;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          _buildFilterChip(
            key: const Key('stall_filter_all'),
            label: _isNepali ? 'सबै' : 'All',
            icon: '🛍️',
            count: result.totalItems,
            isSelected: _selectedStallId == 'all',
            onTap: () => setState(() => _selectedStallId = 'all'),
          ),
          const SizedBox(width: 8),
          ...stalls.map((group) {
            final isSelected = _selectedStallId == group.stall.id;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildFilterChip(
                key: Key('stall_filter_${group.stall.id}'),
                label: _isNepali ? group.shortNameNe : group.nameEn,
                icon: group.icon,
                count: group.items.length,
                isSelected: isSelected,
                onTap: () => setState(() => _selectedStallId = group.stall.id),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required Key key,
    required String label,
    required String icon,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final countLabel = _isNepali ? NepaliCalendar.toDevanagariDigits(count) : '$count';

    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? SitiColors.terracotta : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? SitiColors.terracotta : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              '$label ($countLabel)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : SitiColors.dark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStallsList(GroceryListResult result) {
    final displayedGroups = _selectedStallId == 'all'
        ? result.stalls
        : result.stalls.where((g) => g.stall.id == _selectedStallId).toList();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: displayedGroups.length,
      itemBuilder: (context, index) {
        final group = displayedGroups[index];
        return _buildStallSection(group);
      },
    );
  }

  Widget _buildStallSection(GroceryStallGroup group) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Stall Header in Haat Bazaar style
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Text(group.icon, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isNepali ? group.nameNe : group.nameEn,
                    style: NepaliTypography.titleSmall.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Colors.brown.shade900,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: SitiColors.terracotta.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _isNepali
                        ? '${NepaliCalendar.toDevanagariDigits(group.itemsToBuyCount)} किन्न बाँकी'
                        : '${group.itemsToBuyCount} to buy',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: SitiColors.terracotta,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Items inside this stall
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: group.items.length,
            separatorBuilder: (context, _) => Divider(height: 1, color: Colors.grey.shade100),
            itemBuilder: (context, itemIdx) {
              final item = group.items[itemIdx];
              return _buildGroceryItemTile(item);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGroceryItemTile(GroceryItem item) {
    final isInPantry = item.isSufficientInPantry;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Checkbox / Pantry toggle
          Checkbox(
            key: Key('item_pantry_check_${item.ingredientId}'),
            value: isInPantry,
            activeColor: Colors.green.shade700,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            onChanged: (_) => _togglePantryStatus(item),
          ),
          const SizedBox(width: 4),

          // Item Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _isNepali ? item.nameNe : item.nameEn,
                        style: NepaliTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          decoration: isInPantry ? TextDecoration.lineThrough : null,
                          color: isInPantry ? Colors.grey.shade500 : SitiColors.dark,
                        ),
                      ),
                    ),
                    // Vendor Unit Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isInPantry ? Colors.grey.shade100 : Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isInPantry ? Colors.grey.shade300 : Colors.amber.shade400,
                        ),
                      ),
                      child: Text(
                        _isNepali ? item.vendorUnitLabelNe : item.vendorUnitLabelEn,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: isInPantry ? Colors.grey.shade600 : Colors.brown.shade900,
                        ),
                      ),
                    ),
                    if (widget.retailerHandoffService?.partnerLinksEnabled ?? true) ...[
                      const SizedBox(width: 6),
                      InkWell(
                        key: Key('item_retailer_btn_${item.ingredientId}'),
                        onTap: () {
                          RetailerHandoffSheet.show(
                            context: context,
                            retailerService: widget.retailerHandoffService ?? RetailerHandoffService(),
                            singleItemName: _isNepali ? item.nameNe : item.nameEn,
                            currentLanguage: _language,
                          );
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.shopping_cart_outlined, size: 12, color: SitiColors.terracotta),
                              const SizedBox(width: 2),
                              Text(
                                _isNepali ? 'अनलाइन' : 'Online',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: SitiColors.terracotta,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),

                // Weight breakdown (Req / Pantry / Net)
                Text(
                  _isNepali
                      ? 'आवश्यक: ${NepaliCalendar.toDevanagariDigits(item.totalRequiredGrams.round())}g • घरमा: ${NepaliCalendar.toDevanagariDigits(item.pantryAvailableGrams.round())}g • किन्नुपर्ने: ${NepaliCalendar.toDevanagariDigits(item.netNeededGrams.round())}g'
                      : 'Required: ${item.totalRequiredGrams.round()}g • Pantry: ${item.pantryAvailableGrams.round()}g • Net: ${item.netNeededGrams.round()}g',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),

                // Market price and budget hero indicator
                if (item.pricePerUnitNpr != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: item.isBudgetHero
                              ? Colors.green.shade50
                              : (item.priceTrend == 'rising'
                                  ? Colors.red.shade50
                                  : Colors.amber.shade50),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: item.isBudgetHero
                                ? Colors.green.shade300
                                : (item.priceTrend == 'rising'
                                    ? Colors.red.shade200
                                    : Colors.amber.shade300),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              item.priceTrend == 'falling'
                                  ? Icons.arrow_downward_rounded
                                  : (item.priceTrend == 'rising'
                                      ? Icons.arrow_upward_rounded
                                      : Icons.remove_rounded),
                              size: 11,
                              color: item.isBudgetHero
                                  ? SitiColors.freshGreen
                                  : (item.priceTrend == 'rising'
                                      ? SitiColors.alert
                                      : SitiColors.warning),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              _isNepali
                                  ? (item.isBudgetHero
                                      ? 'बजेट हिरो ⭐ (रु ${NepaliCalendar.toDevanagariDigits(item.pricePerUnitNpr!)}/केजी)'
                                      : (item.priceTrend == 'rising'
                                          ? 'बढ्दो दर (रु ${NepaliCalendar.toDevanagariDigits(item.pricePerUnitNpr!)}/केजी)'
                                          : 'स्थिर दर (रु ${NepaliCalendar.toDevanagariDigits(item.pricePerUnitNpr!)}/केजी)'))
                                  : (item.isBudgetHero
                                      ? 'Budget Hero ⭐ (NPR ${item.pricePerUnitNpr}/kg)'
                                      : '${item.priceTrend ?? "stable"} (NPR ${item.pricePerUnitNpr}/kg)'),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: item.isBudgetHero
                                    ? Colors.green.shade900
                                    : (item.priceTrend == 'rising'
                                        ? Colors.red.shade900
                                        : Colors.brown.shade800),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (item.estimatedPriceNpr != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          _isNepali
                              ? 'अनुमानित: रु ${NepaliCalendar.toDevanagariDigits(item.estimatedPriceNpr!)}'
                              : 'Est: NPR ${item.estimatedPriceNpr}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],

                // Surplus advice if applicable
                if (item.surplusGrams >= 100 && !isInPantry) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.tips_and_updates_outlined, size: 13, color: Colors.blue.shade700),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _isNepali
                                ? (item.surplusSuggestionNe ?? '${NepaliCalendar.toDevanagariDigits(item.surplusGrams.round())}g बचत')
                                : (item.surplusSuggestionEn ?? '${item.surplusGrams.round()}g surplus'),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Recipes using this item
                if (item.usedByRecipeTitlesEn.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    children: (_isNepali ? item.usedByRecipeTitlesNe : item.usedByRecipeTitlesEn).map((title) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          title,
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar(GroceryListResult result) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            key: const Key('open_market_mode_btn'),
            style: ElevatedButton.styleFrom(
              backgroundColor: SitiColors.terracotta,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            icon: const Icon(Icons.shopping_cart_checkout_rounded, size: 20),
            label: Text(
              _isNepali ? 'बजार मोडमा जानुहोस् (Market Mode)' : 'Open Market Mode',
              style: NepaliTypography.titleSmall.copyWith(
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            onPressed: () {
              if (widget.onOpenMarketMode != null) {
                widget.onOpenMarketMode!(result);
              } else {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => MarketModeScreen(
                      groceryResult: result,
                      repository: widget.repository,
                      currentLanguage: _language,
                      onFinishedShopping: _loadData,
                    ),
                  ),
                );
              }
            },
          ),
        ),
      ),
    );
  }
}
