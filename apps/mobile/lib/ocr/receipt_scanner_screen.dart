import 'package:flutter/material.dart';
import 'package:kitchen_engine/kitchen_engine.dart';
import '../planner/planner_repository.dart';
import '../theme/nepali_typography.dart';
import '../theme/tokens.dart';
import 'ocr_scanner_service.dart';

/// Screen allowing users to scan supermarket and Haat Bazaar grocery receipts on-device
/// to automatically populate and sync pantry stock quantities and spend logs.
class ReceiptScannerScreen extends StatefulWidget {
  final WeeklyPlannerRepository plannerRepository;
  final OcrScannerService scannerService;
  final String? initialReceiptText;
  final bool isNepali;
  final VoidCallback? onPantrySynced;

  const ReceiptScannerScreen({
    super.key,
    required this.plannerRepository,
    this.scannerService = const OcrScannerService(),
    this.initialReceiptText,
    this.isNepali = false,
    this.onPantrySynced,
  });

  @override
  State<ReceiptScannerScreen> createState() => _ReceiptScannerScreenState();
}

class _ReceiptScannerScreenState extends State<ReceiptScannerScreen> {
  late final TextEditingController _textController;
  ParsedReceipt? _parsedReceipt;
  final Set<int> _selectedIndices = {};
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialReceiptText ?? '');
    if (_textController.text.isNotEmpty) {
      _parseText(_textController.text);
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _parseText(String text) {
    if (text.trim().isEmpty) return;
    final parsed = widget.scannerService.parseReceipt(text);
    _parsedReceipt = parsed;
    _selectedIndices.clear();
    for (int i = 0; i < parsed.items.length; i++) {
      if (parsed.items[i].matchedIngredientId != null) {
        _selectedIndices.add(i);
      }
    }
  }

  void _parseCurrentText() {
    setState(() {
      _parseText(_textController.text);
    });
  }

  Future<void> _syncToPantry() async {
    if (_parsedReceipt == null || _selectedIndices.isEmpty) return;

    setState(() => _isProcessing = true);

    final selectedItems = _selectedIndices
        .map((i) => _parsedReceipt!.items[i])
        .toList();

    final count = await widget.scannerService.syncItemsToPantry(
      widget.plannerRepository,
      selectedItems,
    );

    setState(() => _isProcessing = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isNepali
              ? '$count सामग्रीहरू भण्डारमा सुरक्षित गरियो'
              : 'Synced $count items to pantry inventory',
            style: NepaliTypography.bodyMedium.copyWith(color: Colors.white),
          ),
          backgroundColor: SitiColors.freshGreen,
        ),
      );
      widget.onPantrySynced?.call();
    }
  }

  void _loadSampleReceipt(String type) {
    if (type == 'bhatbhateni') {
      _textController.text = '''
BHATBHATENI SUPERMARKET
KOTESHWOR, KATHMANDU
PAN NO: 300054321
DATE: 2026-03-24
--------------------------------
POTATO RED 1.5 KG      Rs 97.50
BBSM MUSTARD OIL 1L    Rs 320.00
TOMATO LOCAL 500G      Rs 45.00
CAULIFLOWER 1 PC       Rs 80.00
--------------------------------
TOTAL:                 Rs 542.50
CASH:                  Rs 600.00
CHANGE:                Rs 57.50
THANK YOU VISIT AGAIN
''';
    } else if (type == 'haatbazaar') {
      _textController.text = '''
कृषि बजार / हाट बजार रसिद
मिति: 2026/04/10
आलु १ धार्नी @ रु १२५      रु 125.00
गोलभेडा २ पाउ            रु 40.00
प्याज १ के.जी.            रु 75.00
--------------------------------
जम्मा रकम:               रु 240.00
''';
    }
    _parseCurrentText();
  }

  @override
  Widget build(BuildContext context) {
    final isNepali = widget.isNepali;

    return Scaffold(
      backgroundColor: SitiColors.dark,
      appBar: AppBar(
        backgroundColor: SitiColors.cardDark,
        elevation: 0,
        title: Text(
          isNepali ? 'रसिद स्क्यानर र भण्डार' : 'Receipt OCR & Pantry Sync',
          style: NepaliTypography.titleLarge.copyWith(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: isNepali ? 'पुन: स्क्यान' : 'Reparse Text',
            onPressed: _parseCurrentText,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(SitiSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sample receipt quick buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: SitiColors.terracotta,
                      side: const BorderSide(color: SitiColors.terracotta),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(Icons.receipt_long, size: 18),
                    label: Text(
                      isNepali ? 'भातभटेनी रसिद' : 'Bhatbhateni',
                      style: NepaliTypography.bodySmall.copyWith(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => _loadSampleReceipt('bhatbhateni'),
                  ),
                ),
                const SizedBox(width: SitiSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: SitiColors.freshGreen,
                      side: const BorderSide(color: SitiColors.freshGreen),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(Icons.storefront, size: 18),
                    label: Text(
                      isNepali ? 'हाट बजार / किराना' : 'Haat Bazaar',
                      style: NepaliTypography.bodySmall.copyWith(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => _loadSampleReceipt('haatbazaar'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: SitiSpacing.md),

            // OCR text input box
            Container(
              decoration: BoxDecoration(
                color: SitiColors.cardDark,
                borderRadius: SitiRadius.roundedMd,
                border: Border.all(color: Colors.white24),
              ),
              padding: const EdgeInsets.all(SitiSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isNepali ? 'अन-डिभाइस स्क्यान गरिएको रसिद पाठ:' : 'On-Device Scanned Receipt Text:',
                    style: NepaliTypography.bodySmall.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _textController,
                    maxLines: 4,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
                    decoration: InputDecoration(
                      hintText: isNepali
                          ? 'रसिदको पाठ यहाँ टाइप गर्नुहोस् वा स्क्यान गर्नुहोस्...'
                          : 'Paste or scan receipt text lines here...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      border: InputBorder.none,
                    ),
                    onChanged: (_) => _parseCurrentText(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: SitiSpacing.md),

            // Parsed Receipt Summary Card
            if (_parsedReceipt != null) ...[
              Container(
                padding: const EdgeInsets.all(SitiSpacing.md),
                decoration: BoxDecoration(
                  color: SitiColors.cardDark,
                  borderRadius: SitiRadius.roundedMd,
                  border: Border.all(color: SitiColors.terracotta.withAlpha(128)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _parsedReceipt!.merchantName ?? (isNepali ? 'स्थानिय पसल' : 'Local Merchant'),
                            style: NepaliTypography.titleMedium.copyWith(
                              color: SitiColors.terracotta,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (_parsedReceipt!.receiptDate != null)
                          Text(
                            _parsedReceipt!.receiptDate!,
                            style: NepaliTypography.bodySmall.copyWith(color: Colors.white60),
                          ),
                      ],
                    ),
                    const Divider(color: Colors.white24, height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isNepali
                              ? 'पत्ता लागेका सामग्रीहरू: ${_parsedReceipt!.items.length}'
                              : 'Detected items: ${_parsedReceipt!.items.length}',
                          style: NepaliTypography.bodyMedium.copyWith(color: Colors.white),
                        ),
                        if (_parsedReceipt!.totalAmount != null)
                          Text(
                            '${_parsedReceipt!.currency} ${_parsedReceipt!.totalAmount!.toStringAsFixed(2)}',
                            style: NepaliTypography.titleMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: SitiSpacing.md),

              // Items Checklist Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isNepali ? 'भण्डारमा थप्न छनोट गर्नुहोस्:' : 'Select items to add to pantry:',
                    style: NepaliTypography.bodyMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        if (_selectedIndices.length == _parsedReceipt!.items.length) {
                          _selectedIndices.clear();
                        } else {
                          _selectedIndices.addAll(
                            List.generate(_parsedReceipt!.items.length, (i) => i),
                          );
                        }
                      });
                    },
                    child: Text(
                      _selectedIndices.length == _parsedReceipt!.items.length
                          ? (isNepali ? 'सबै हटाउनुहोस्' : 'Deselect all')
                          : (isNepali ? 'सबै छान्नुहोस्' : 'Select all'),
                      style: TextStyle(color: SitiColors.terracotta, fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Items ListView
              ..._parsedReceipt!.items.asMap().entries.map((entry) {
                final idx = entry.key;
                final item = entry.value;
                final isSelected = _selectedIndices.contains(idx);
                final hasMatched = item.matchedIngredientId != null;

                return Padding(
                  padding: const EdgeInsets.only(bottom: SitiSpacing.sm),
                  child: Material(
                    color: isSelected ? SitiColors.cardDark : SitiColors.dark,
                    shape: RoundedRectangleBorder(
                      borderRadius: SitiRadius.roundedSm,
                      side: BorderSide(
                        color: isSelected ? SitiColors.freshGreen.withAlpha(150) : Colors.white12,
                      ),
                    ),
                    child: CheckboxListTile(
                    value: isSelected,
                    activeColor: SitiColors.freshGreen,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedIndices.add(idx);
                        } else {
                          _selectedIndices.remove(idx);
                        }
                      });
                    },
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            style: NepaliTypography.bodyMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (item.price != null)
                          Text(
                            'Rs ${item.price!.toStringAsFixed(2)}',
                            style: NepaliTypography.bodySmall.copyWith(color: Colors.white70),
                          ),
                      ],
                    ),
                    subtitle: Row(
                      children: [
                        if (hasMatched)
                          Container(
                            margin: const EdgeInsets.only(top: 4, right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: SitiColors.terracotta.withAlpha(50),
                              borderRadius: SitiRadius.roundedSm,
                              border: Border.all(color: SitiColors.terracotta.withAlpha(120)),
                            ),
                            child: Text(
                              item.matchedIngredientId!,
                              style: const TextStyle(
                                color: SitiColors.terracotta,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        if (item.quantityGrams != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '${item.quantityGrams!.toStringAsFixed(0)} g (${item.unit ?? 'g'})',
                              style: NepaliTypography.bodySmall.copyWith(color: Colors.white60),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
              const SizedBox(height: SitiSpacing.md),

              // Sync to Pantry Button
              ElevatedButton.icon(
                key: const Key('add_to_pantry_btn'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SitiColors.freshGreen,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: SitiRadius.roundedMd),
                ),
                icon: _isProcessing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.inventory_2, color: Colors.white),
                label: Text(
                  isNepali
                      ? 'भण्डारमा थप्नुहोस् (${_selectedIndices.length})'
                      : 'Add to Pantry Inventory (${_selectedIndices.length})',
                  style: NepaliTypography.titleMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: (_isProcessing || _selectedIndices.isEmpty) ? null : _syncToPantry,
              ),
              const SizedBox(height: SitiSpacing.xl),
            ],
          ],
        ),
      ),
    );
  }
}
