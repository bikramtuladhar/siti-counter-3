import 'dart:math' as math;
import 'kitchen_engine.dart';
import 'nepali_calendar.dart';
import 'region_pack.dart';

/// Market stall types found in traditional Nepali wet markets (Haat Bazaar / Kalimati).
enum MarketStall {
  vegetables,
  fruit,
  meatFish,
  spices,
  grainsStaples;

  String get id {
    switch (this) {
      case MarketStall.vegetables:
        return 'vegetables';
      case MarketStall.fruit:
        return 'fruit';
      case MarketStall.meatFish:
        return 'meat_fish';
      case MarketStall.spices:
        return 'spices';
      case MarketStall.grainsStaples:
        return 'grains_staples';
    }
  }

  String get nameEn {
    switch (this) {
      case MarketStall.vegetables:
        return 'Vegetables';
      case MarketStall.fruit:
        return 'Fruit';
      case MarketStall.meatFish:
        return 'Meat/Fish';
      case MarketStall.spices:
        return 'Spices';
      case MarketStall.grainsStaples:
        return 'Grains/Staples';
    }
  }

  String get nameNe {
    switch (this) {
      case MarketStall.vegetables:
        return 'तरकारी गल्ली (Vegetables)';
      case MarketStall.fruit:
        return 'फलफूल (Fruit)';
      case MarketStall.meatFish:
        return 'मासु तथा माछा (Meat & Fish)';
      case MarketStall.spices:
        return 'मसला गल्ली (Spices)';
      case MarketStall.grainsStaples:
        return 'खाद्यान्न तथा दाल-चामल (Grains/Staples)';
    }
  }

  String get shortNameNe {
    switch (this) {
      case MarketStall.vegetables:
        return 'तरकारी';
      case MarketStall.fruit:
        return 'फलफूल';
      case MarketStall.meatFish:
        return 'मासु/माछा';
      case MarketStall.spices:
        return 'मसला';
      case MarketStall.grainsStaples:
        return 'खाद्यान्न';
    }
  }

  String get icon {
    switch (this) {
      case MarketStall.vegetables:
        return '🥕';
      case MarketStall.fruit:
        return '🍎';
      case MarketStall.meatFish:
        return '🍗';
      case MarketStall.spices:
        return '🌶️';
      case MarketStall.grainsStaples:
        return '🌾';
    }
  }

  int get sortOrder {
    switch (this) {
      case MarketStall.vegetables:
        return 0;
      case MarketStall.fruit:
        return 1;
      case MarketStall.meatFish:
        return 2;
      case MarketStall.spices:
        return 3;
      case MarketStall.grainsStaples:
        return 4;
    }
  }
}

/// Resolves an ingredient category to a market stall.
MarketStall resolveMarketStall(String? category) {
  if (category == null) return MarketStall.grainsStaples;
  switch (category.toLowerCase().trim()) {
    case 'vegetables':
    case 'greens':
    case 'fermented':
      return MarketStall.vegetables;
    case 'fruits':
    case 'fruit':
      return MarketStall.fruit;
    case 'meat':
    case 'fish':
      return MarketStall.meatFish;
    case 'spices':
    case 'aromatics':
    case 'seeds':
      return MarketStall.spices;
    case 'grains':
    case 'pulses':
    case 'flour':
    case 'oils':
    case 'dairy':
    case 'sweeteners':
    default:
      return MarketStall.grainsStaples;
  }
}

/// Formats purchasable quantities in vendor units (pau, kg, mana, bunches, piece, packet, l).
String formatVendorQuantity({
  required double totalGrams,
  required String standardUnit,
  required int marketPackageGrams,
  required int packagesToBuy,
  bool preferNepali = false,
}) {
  if (packagesToBuy <= 0) {
    return preferNepali
        ? '० ${NepaliCalendar.toDevanagariDigits(0)}'
        : '0 $standardUnit';
  }

  final unitLower = standardUnit.toLowerCase().trim();
  final intGrams = totalGrams.round();

  if (unitLower == 'pau') {
    if (intGrams >= 1000 && intGrams % 1000 == 0) {
      final kg = intGrams ~/ 1000;
      return preferNepali
          ? '${NepaliCalendar.toDevanagariDigits(kg)} के.जी. (${NepaliCalendar.toDevanagariDigits(packagesToBuy)} पाउ)'
          : '$kg kg ($packagesToBuy pau)';
    }
    return preferNepali
        ? '${NepaliCalendar.toDevanagariDigits(packagesToBuy)} पाउ (${NepaliCalendar.toDevanagariDigits(intGrams)} ग्राम)'
        : '$packagesToBuy pau ($intGrams g)';
  }

  if (unitLower == 'kg') {
    final kgVal = totalGrams / 1000.0;
    final isWhole = kgVal == kgVal.roundToDouble();
    final formattedKg = isWhole ? kgVal.round().toString() : kgVal.toStringAsFixed(1);
    return preferNepali
        ? '${NepaliCalendar.toDevanagariDigits(formattedKg)} के.जी.'
        : '$formattedKg kg';
  }

  if (unitLower == 'mana') {
    return preferNepali
        ? '${NepaliCalendar.toDevanagariDigits(packagesToBuy)} माना (${NepaliCalendar.toDevanagariDigits(intGrams)} ग्राम)'
        : '$packagesToBuy mana ($intGrams g)';
  }

  if (unitLower == 'bunch' || unitLower == 'muthi') {
    final unitEn = packagesToBuy == 1 ? 'bunch' : 'bunches';
    return preferNepali
        ? '${NepaliCalendar.toDevanagariDigits(packagesToBuy)} मुठा (${NepaliCalendar.toDevanagariDigits(intGrams)} ग्राम)'
        : '$packagesToBuy $unitEn ($intGrams g)';
  }

  if (unitLower == 'piece') {
    final unitEn = packagesToBuy == 1 ? 'piece' : 'pieces';
    return preferNepali
        ? '${NepaliCalendar.toDevanagariDigits(packagesToBuy)} वटा (${NepaliCalendar.toDevanagariDigits(intGrams)} ग्राम)'
        : '$packagesToBuy $unitEn ($intGrams g)';
  }

  if (unitLower == 'packet') {
    final unitEn = packagesToBuy == 1 ? 'packet' : 'packets';
    return preferNepali
        ? '${NepaliCalendar.toDevanagariDigits(packagesToBuy)} प्याकेट (${NepaliCalendar.toDevanagariDigits(intGrams)} ग्राम)'
        : '$packagesToBuy $unitEn ($intGrams g)';
  }

  if (unitLower == 'l') {
    return preferNepali
        ? '${NepaliCalendar.toDevanagariDigits(packagesToBuy)} लिटर'
        : '$packagesToBuy L';
  }

  // Fallback generic metric
  if (intGrams >= 1000) {
    final kgVal = totalGrams / 1000.0;
    final formattedKg = kgVal == kgVal.roundToDouble() ? kgVal.round().toString() : kgVal.toStringAsFixed(1);
    return preferNepali
        ? '${NepaliCalendar.toDevanagariDigits(formattedKg)} के.जी.'
        : '$formattedKg kg';
  }
  return preferNepali
      ? '${NepaliCalendar.toDevanagariDigits(intGrams)} ग्राम'
      : '$intGrams g';
}

/// A line item in the grocery list.
class GroceryItem {
  final String ingredientId;
  final String nameEn;
  final String nameNe;
  final String category;
  final MarketStall stall;
  final String standardUnit;
  final double totalRequiredGrams;
  final double pantryAvailableGrams;
  final double netNeededGrams;
  final int marketPackageGrams;
  final int packagesToBuy;
  final double totalPurchasedGrams;
  final double surplusGrams;
  final String vendorUnitLabelEn;
  final String vendorUnitLabelNe;
  final String? surplusSuggestionEn;
  final String? surplusSuggestionNe;
  final String availability;
  final int storageDays;
  final List<String> usedByRecipeIds;
  final List<String> usedByRecipeTitlesEn;
  final List<String> usedByRecipeTitlesNe;
  final bool isSufficientInPantry;

  const GroceryItem({
    required this.ingredientId,
    required this.nameEn,
    required this.nameNe,
    required this.category,
    required this.stall,
    required this.standardUnit,
    required this.totalRequiredGrams,
    required this.pantryAvailableGrams,
    required this.netNeededGrams,
    required this.marketPackageGrams,
    required this.packagesToBuy,
    required this.totalPurchasedGrams,
    required this.surplusGrams,
    required this.vendorUnitLabelEn,
    required this.vendorUnitLabelNe,
    this.surplusSuggestionEn,
    this.surplusSuggestionNe,
    this.availability = 'available',
    this.storageDays = 7,
    this.usedByRecipeIds = const [],
    this.usedByRecipeTitlesEn = const [],
    this.usedByRecipeTitlesNe = const [],
    required this.isSufficientInPantry,
  });

  Map<String, dynamic> toJson() => {
    'ingredientId': ingredientId,
    'nameEn': nameEn,
    'nameNe': nameNe,
    'category': category,
    'stall': stall.id,
    'standardUnit': standardUnit,
    'totalRequiredGrams': totalRequiredGrams,
    'pantryAvailableGrams': pantryAvailableGrams,
    'netNeededGrams': netNeededGrams,
    'marketPackageGrams': marketPackageGrams,
    'packagesToBuy': packagesToBuy,
    'totalPurchasedGrams': totalPurchasedGrams,
    'surplusGrams': surplusGrams,
    'vendorUnitLabelEn': vendorUnitLabelEn,
    'vendorUnitLabelNe': vendorUnitLabelNe,
    'surplusSuggestionEn': surplusSuggestionEn,
    'surplusSuggestionNe': surplusSuggestionNe,
    'availability': availability,
    'storageDays': storageDays,
    'usedByRecipeIds': usedByRecipeIds,
    'usedByRecipeTitlesEn': usedByRecipeTitlesEn,
    'usedByRecipeTitlesNe': usedByRecipeTitlesNe,
    'isSufficientInPantry': isSufficientInPantry,
  };
}

/// A market stall group holding its associated grocery items.
class GroceryStallGroup {
  final MarketStall stall;
  final String nameEn;
  final String nameNe;
  final String shortNameNe;
  final String icon;
  final List<GroceryItem> items;

  const GroceryStallGroup({
    required this.stall,
    required this.nameEn,
    required this.nameNe,
    required this.shortNameNe,
    required this.icon,
    required this.items,
  });

  int get itemsToBuyCount => items.where((i) => !i.isSufficientInPantry).length;
  int get pantryCoveredCount => items.where((i) => i.isSufficientInPantry).length;

  Map<String, dynamic> toJson() => {
    'stall': stall.id,
    'nameEn': nameEn,
    'nameNe': nameNe,
    'shortNameNe': shortNameNe,
    'icon': icon,
    'items': items.map((i) => i.toJson()).toList(),
  };
}

/// The complete generated grocery list with stall grouping and summary metrics.
class GroceryListResult {
  final List<GroceryItem> items;
  final List<GroceryStallGroup> stalls;
  final int totalItems;
  final int totalItemsToBuy;
  final int totalPantryCoveredItems;
  final double totalPurchasedGrams;
  final double totalSurplusGrams;

  const GroceryListResult({
    required this.items,
    required this.stalls,
    required this.totalItems,
    required this.totalItemsToBuy,
    required this.totalPantryCoveredItems,
    required this.totalPurchasedGrams,
    required this.totalSurplusGrams,
  });

  Map<String, dynamic> toJson() => {
    'totalItems': totalItems,
    'totalItemsToBuy': totalItemsToBuy,
    'totalPantryCoveredItems': totalPantryCoveredItems,
    'totalPurchasedGrams': totalPurchasedGrams,
    'totalSurplusGrams': totalSurplusGrams,
    'items': items.map((i) => i.toJson()).toList(),
    'stalls': stalls.map((s) => s.toJson()).toList(),
  };
}

/// Input model representing a planned meal for grocery list aggregation.
class GroceryPlanMealInput {
  final String recipeId;
  final int servings;
  final String? recipeTitleEn;
  final String? recipeTitleNe;
  final String? dateIso;
  final String? slotId;

  const GroceryPlanMealInput({
    required this.recipeId,
    required this.servings,
    this.recipeTitleEn,
    this.recipeTitleNe,
    this.dateIso,
    this.slotId,
  });
}

/// Generates a comprehensive grocery list from planned meals, subtracting pantry quantities,
/// converting required amounts to vendor market units, and grouping by wet market / Haat Bazaar stalls.
GroceryListResult generateGroceryList({
  required List<GroceryPlanMealInput> meals,
  required List<PlanRecipe> recipes,
  required List<PlanIngredient> ingredients,
  Map<String, double> pantryAvailableGrams = const {},
  RituName? rituId,
  Map<String, String> ingredientCategories = const {},
  Map<String, String> ingredientStandardUnits = const {},
}) {
  final recipeById = <String, PlanRecipe>{
    for (final r in recipes) r.id: r,
  };

  final ingredientById = <String, PlanIngredient>{
    for (final i in ingredients) i.id: i,
  };

  final requiredGrams = <String, double>{};
  final usedByRecipeIds = <String, Set<String>>{};
  final usedByTitlesEn = <String, Set<String>>{};
  final usedByTitlesNe = <String, Set<String>>{};

  for (final meal in meals) {
    final recipe = recipeById[meal.recipeId];
    if (recipe == null) continue;

    final servings = meal.servings > 0 ? meal.servings : recipe.servings;
    final scale = servings / recipe.servings.toDouble();

    for (final ing in recipe.ingredients) {
      final grams = ing.quantityGrams * scale;
      requiredGrams[ing.ingredientId] = (requiredGrams[ing.ingredientId] ?? 0.0) + grams;

      (usedByRecipeIds[ing.ingredientId] ??= <String>{}).add(recipe.id);

      final titleEn = meal.recipeTitleEn ?? recipe.titleEn;
      final titleNe = meal.recipeTitleNe ?? recipe.titleNe;
      (usedByTitlesEn[ing.ingredientId] ??= <String>{}).add(titleEn);
      (usedByTitlesNe[ing.ingredientId] ??= <String>{}).add(titleNe);
    }
  }

  final sortedIngredientIds = requiredGrams.keys.toList()..sort();
  final items = <GroceryItem>[];

  for (final ingId in sortedIngredientIds) {
    final totalReq = (requiredGrams[ingId]! * 10).round() / 10.0;
    final ingMeta = ingredientById[ingId];
    final pantryGrams = (pantryAvailableGrams[ingId] ?? 0.0).clamp(0.0, double.infinity);
    final netNeeded = math.max(0.0, totalReq - pantryGrams);

    final marketPkgGrams = (ingMeta != null && ingMeta.marketPackageGrams > 0)
        ? ingMeta.marketPackageGrams
        : 250;

    final packagesToBuy = netNeeded > 0 ? (netNeeded / marketPkgGrams).ceil() : 0;
    final totalPurchased = packagesToBuy * marketPkgGrams.toDouble();
    final surplus = math.max(0.0, pantryGrams + totalPurchased - totalReq);

    final category = ingredientCategories[ingId] ?? 'vegetables';
    final standardUnit = ingredientStandardUnits[ingId] ?? (marketPkgGrams >= 1000 ? 'kg' : 'pau');
    final stall = resolveMarketStall(category);

    final nameEn = ingMeta?.nameEn ?? ingId;
    final nameNe = ingMeta?.nameNe ?? ingId;

    final vendorEn = formatVendorQuantity(
      totalGrams: totalPurchased > 0 ? totalPurchased : totalReq,
      standardUnit: standardUnit,
      marketPackageGrams: marketPkgGrams,
      packagesToBuy: packagesToBuy > 0 ? packagesToBuy : 0,
      preferNepali: false,
    );

    final vendorNe = formatVendorQuantity(
      totalGrams: totalPurchased > 0 ? totalPurchased : totalReq,
      standardUnit: standardUnit,
      marketPackageGrams: marketPkgGrams,
      packagesToBuy: packagesToBuy > 0 ? packagesToBuy : 0,
      preferNepali: true,
    );

    final suggestion = MarketCalculator.getSurplusSuggestion(nameEn, surplus);

    final rituKey = rituId?.name ?? 'sharad';
    final availability = ingMeta?.availability[rituKey] ?? 'available';

    items.add(GroceryItem(
      ingredientId: ingId,
      nameEn: nameEn,
      nameNe: nameNe,
      category: category,
      stall: stall,
      standardUnit: standardUnit,
      totalRequiredGrams: totalReq,
      pantryAvailableGrams: (pantryGrams * 10).round() / 10.0,
      netNeededGrams: (netNeeded * 10).round() / 10.0,
      marketPackageGrams: marketPkgGrams,
      packagesToBuy: packagesToBuy,
      totalPurchasedGrams: (totalPurchased * 10).round() / 10.0,
      surplusGrams: (surplus * 10).round() / 10.0,
      vendorUnitLabelEn: vendorEn,
      vendorUnitLabelNe: vendorNe,
      surplusSuggestionEn: suggestion.en,
      surplusSuggestionNe: suggestion.ne,
      availability: availability,
      storageDays: ingMeta?.storageDays ?? 7,
      usedByRecipeIds: (usedByRecipeIds[ingId] ?? const <String>{}).toList()..sort(),
      usedByRecipeTitlesEn: (usedByTitlesEn[ingId] ?? const <String>{}).toList()..sort(),
      usedByRecipeTitlesNe: (usedByTitlesNe[ingId] ?? const <String>{}).toList()..sort(),
      isSufficientInPantry: netNeeded == 0.0,
    ));
  }

  // Group items by stall in standard Haat Bazaar walking order
  final stallsInOrder = [
    MarketStall.vegetables,
    MarketStall.fruit,
    MarketStall.meatFish,
    MarketStall.spices,
    MarketStall.grainsStaples,
  ];

  final stallGroups = <GroceryStallGroup>[];
  for (final stall in stallsInOrder) {
    final stallItems = items.where((i) => i.stall == stall).toList();
    if (stallItems.isNotEmpty) {
      // Sort items within stall: items to buy first, then sufficient in pantry
      stallItems.sort((a, b) {
        if (a.isSufficientInPantry != b.isSufficientInPantry) {
          return a.isSufficientInPantry ? 1 : -1;
        }
        return a.nameEn.compareTo(b.nameEn);
      });

      stallGroups.add(GroceryStallGroup(
        stall: stall,
        nameEn: stall.nameEn,
        nameNe: stall.nameNe,
        shortNameNe: stall.shortNameNe,
        icon: stall.icon,
        items: stallItems,
      ));
    }
  }

  final itemsToBuy = items.where((i) => !i.isSufficientInPantry).length;
  final pantryCovered = items.where((i) => i.isSufficientInPantry).length;
  final totalPurchasedSum = items.fold<double>(0.0, (sum, i) => sum + i.totalPurchasedGrams);
  final totalSurplusSum = items.fold<double>(0.0, (sum, i) => sum + i.surplusGrams);

  return GroceryListResult(
    items: items,
    stalls: stallGroups,
    totalItems: items.length,
    totalItemsToBuy: itemsToBuy,
    totalPantryCoveredItems: pantryCovered,
    totalPurchasedGrams: (totalPurchasedSum * 10).round() / 10.0,
    totalSurplusGrams: (totalSurplusSum * 10).round() / 10.0,
  );
}

/// Overload helper to generate grocery list directly from RegionPack recipes and ingredients.
GroceryListResult generateGroceryListFromRegion({
  required List<GroceryPlanMealInput> meals,
  required List<RegionRecipe> recipes,
  required List<RegionIngredient> ingredients,
  Map<String, double> pantryAvailableGrams = const {},
  RituName? rituId,
}) {
  final planRecipes = recipes.map((r) {
    return PlanRecipe(
      id: r.id,
      titleEn: r.titleEn,
      titleNe: r.titleNe,
      category: r.category,
      dietary: r.dietary,
      prepTimeMinutes: r.prepTimeMinutes,
      cookTimeMinutes: r.cookTimeMinutes,
      servings: r.servings,
      costEstimateNpr: r.costEstimateNpr,
      proteinGramsPerServing: r.proteinGramsPerServing,
      ingredients: r.ingredients.map((ri) {
        return PlanRecipeIngredient(
          ingredientId: ri.ingredientId,
          quantityGrams: ri.quantity,
        );
      }).toList(),
      tags: r.tags,
    );
  }).toList();

  final planIngredients = ingredients.map((i) => PlanIngredient.fromRegion(i)).toList();
  final categories = <String, String>{
    for (final i in ingredients) i.id: i.category,
  };
  final standardUnits = <String, String>{
    for (final i in ingredients) i.id: i.standardUnit,
  };

  return generateGroceryList(
    meals: meals,
    recipes: planRecipes,
    ingredients: planIngredients,
    pantryAvailableGrams: pantryAvailableGrams,
    rituId: rituId,
    ingredientCategories: categories,
    ingredientStandardUnits: standardUnits,
  );
}

/// Exports a cleanly formatted plain-text representation of the grocery list,
/// suitable for one-tap sharing via WhatsApp, Viber, or SMS in Nepali or English.
String exportGroceryListText(
  GroceryListResult result, {
  bool preferNepali = true,
  bool includePantryCovered = false,
  String? headerTitle,
}) {
  final buffer = StringBuffer();
  final title = headerTitle ??
      (preferNepali
          ? '🛒 सिटि काउन्टर - हप्ताको किनमेल सूची'
          : '🛒 Siti Counter - Weekly Grocery List');

  buffer.writeln(title);
  buffer.writeln('=============================');
  buffer.writeln();

  for (final stallGroup in result.stalls) {
    final itemsToInclude = includePantryCovered
        ? stallGroup.items
        : stallGroup.items.where((i) => !i.isSufficientInPantry).toList();

    if (itemsToInclude.isEmpty) continue;

    final stallTitle = preferNepali ? stallGroup.nameNe : stallGroup.nameEn;
    buffer.writeln('${stallGroup.icon} $stallTitle:');

    for (final item in itemsToInclude) {
      final checkMark = item.isSufficientInPantry ? '[✓]' : '[ ]';
      final name = preferNepali
          ? (item.nameNe != item.nameEn ? '${item.nameNe} (${item.nameEn})' : item.nameNe)
          : item.nameEn;
      final vendorQuantity = preferNepali ? item.vendorUnitLabelNe : item.vendorUnitLabelEn;
      buffer.writeln('  $checkMark $name - $vendorQuantity');
    }
    buffer.writeln();
  }

  buffer.writeln('-----------------------------');
  if (preferNepali) {
    buffer.writeln(
      'कुल सामग्री: ${NepaliCalendar.toDevanagariDigits(result.totalItemsToBuy)} किन्नुपर्ने | ${NepaliCalendar.toDevanagariDigits(result.totalPantryCoveredItems)} घरमै भएको',
    );
    buffer.writeln('सिटि काउन्टर ३.० बाट तयार पारिएको (Siti Counter)');
  } else {
    buffer.writeln(
      'Total: ${result.totalItemsToBuy} to buy | ${result.totalPantryCoveredItems} in pantry',
    );
    buffer.writeln('Generated by Siti Counter 3.0');
  }

  return buffer.toString().trimRight();
}
