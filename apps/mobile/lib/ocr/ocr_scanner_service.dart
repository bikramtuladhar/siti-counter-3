import 'package:kitchen_engine/kitchen_engine.dart';
import '../planner/planner_repository.dart';

/// Service providing on-device OCR receipt parsing, pantry auto-fill, and food label allergen checking.
class OcrScannerService {
  const OcrScannerService();

  /// Parses raw text extracted from grocery receipts on-device.
  ParsedReceipt parseReceipt(String rawOcrText) {
    return OcrReceiptParser.parseReceipt(rawOcrText);
  }

  /// Scans packaged food ingredients and allergy statements, cross-checking with household members.
  LabelScanResult scanFoodLabel(
    String rawOcrText, {
    List<HouseholdMemberAllergyInput> householdMembers = const [],
  }) {
    return FoodLabelScanner.scanLabel(
      rawOcrText,
      householdMembers: householdMembers,
    );
  }

  /// Synchronizes scanned receipt items directly into the offline SQLite pantry repository.
  Future<int> syncItemsToPantry(
    WeeklyPlannerRepository repository,
    List<ParsedReceiptItem> items,
  ) async {
    int updatedCount = 0;
    final currentPantry = await repository.getPantryItems();

    for (final item in items) {
      if (item.matchedIngredientId != null &&
          item.quantityGrams != null &&
          item.quantityGrams! > 0) {
        final existingGrams = currentPantry[item.matchedIngredientId!] ?? 0.0;
        final newGrams = existingGrams + item.quantityGrams!;

        await repository.setPantryItem(
          item.matchedIngredientId!,
          newGrams,
          unit: item.unit ?? 'g',
        );
        updatedCount++;
      }
    }

    return updatedCount;
  }
}
