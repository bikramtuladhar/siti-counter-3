/// Converts a recipe ingredient's quantity and unit into grams.
///
/// Region packs store a quantity and a unit separately. The grocery and auto-plan engines
/// need a single mass in grams to add up quantities across recipes, scale by servings and
/// compare against a pantry.
///
/// Previously the raw `quantity` was passed through as grams and the `unit` was ignored, so a
/// recipe written as `1 kg` of rice asked the shopper for one gram. Every current pack happens
/// to declare grams, which is why it went unnoticed, but the field is part of the public pack
/// format and any pack or user-authored recipe using another unit was silently wrong.
///
/// Liquids are converted at their water density, which is the usual convention for recipe
/// quantities. An unrecognised unit is assumed to already be grams, matching the packs in this
/// repository; [isKnownUnit] reports when that assumption has been made.
library;

const Map<String, double> _unitToGrams = {
  'g': 1,
  'gram': 1,
  'grams': 1,
  'gm': 1,
  'kg': 1000,
  'kilo': 1000,
  'kilogram': 1000,
  'kilograms': 1000,
  'mg': 0.001,
  'ml': 1,
  'millilitre': 1,
  'milliliter': 1,
  'l': 1000,
  'litre': 1000,
  'liter': 1000,
  'oz': 28.3495,
  'ounce': 28.3495,
  'lb': 453.592,
  'pound': 453.592,
  // A US cup of liquid or flour, the usual recipe convention.
  'cup': 240,
  'cups': 240,
  'tbsp': 15,
  'tablespoon': 15,
  'tsp': 5,
  'teaspoon': 5,
  // Nepali market and kitchen units.
  'tola': 11.66,
  'pau': 1, // Smallest unit for loose goods, treated as one gram.
  'bhat': 300, // A serving bowl of rice.
  'thali': 400, // A full plate of food.
  'katori': 150, // A small serving bowl of curry.
  'piece': 100, // One piece, on the assumption of a medium vegetable.
  'pcs': 100,
};

/// Whether [unit] appears in the conversion table.
///
/// Callers that need to warn about an unconverted unit can use this rather than assuming the
/// conversion happened.
bool isKnownUnit(String unit) =>
    _unitToGrams.containsKey(unit.trim().toLowerCase());

/// Converts [quantity] expressed in [unit] into grams.
///
/// An empty or unrecognised unit is treated as grams, which is what the region packs in this
/// repository declare.
double quantityToGrams(double quantity, String unit) {
  final factor = _unitToGrams[unit.trim().toLowerCase()] ?? 1;
  return quantity * factor;
}