import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kitchen_engine/kitchen_engine.dart';
import 'package:kitchen_engine/nepali_calendar.dart';
import '../planner/planner_repository.dart';
import '../theme/nepali_typography.dart';
import '../theme/tokens.dart';

/// Minimalist, high-contrast, one-handed Market Mode shopping checklist screen.
/// Designed for high-glare outdoor wet markets (Haat Bazaar / Kalimati).
/// Checking items off automatically updates the household SQLite pantry inventory.
/// Includes one-tap text generator exporting clean lists for WhatsApp, Viber, or SMS.
class MarketModeScreen extends StatefulWidget {
  final GroceryListResult groceryResult;
  final WeeklyPlannerRepository repository;
  final String currentLanguage;
  final VoidCallback? onFinishedShopping;

  const MarketModeScreen({
    super.key,
    required this.groceryResult,
    required this.repository,
    this.currentLanguage = 'ne',
    this.onFinishedShopping,
  });

  @override
  State<MarketModeScreen> createState() => _MarketModeScreenState();
}

class _MarketModeScreenState extends State<MarketModeScreen> {
  late String _language;
  late Set<String> _checkedIngredientIds;
  String _selectedStallId = 'all';

  bool get _isNepali => _language == 'ne';

  @override
  void initState() {
    super.initState();
    _language = widget.currentLanguage;
    // Pre-populate checked set with items already in pantry
    _checkedIngredientIds = widget.groceryResult.items
        .where((item) => item.isSufficientInPantry)
        .map((item) => item.ingredientId)
        .toSet();
  }

  Future<void> _toggleCheck(GroceryItem item) async {
    final isChecked = _checkedIngredientIds.contains(item.ingredientId);
    setState(() {
      if (isChecked) {
        _checkedIngredientIds.remove(item.ingredientId);
      } else {
        _checkedIngredientIds.add(item.ingredientId);
      }
    });

    // Provide tactile feedback if available
    HapticFeedback.lightImpact();

    if (!isChecked) {
      // Checked off -> automatically add to pantry inventory
      final grams = item.totalPurchasedGrams > 0 ? item.totalPurchasedGrams : item.totalRequiredGrams;
      await widget.repository.setPantryItem(item.ingredientId, grams);
    } else {
      // Unchecked -> remove from pantry
      await widget.repository.removePantryItem(item.ingredientId);
    }
  }

  void _openShareExportDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return _ShareListExportSheet(
          groceryResult: widget.groceryResult,
          initialLanguage: _language,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalCount = widget.groceryResult.totalItems;
    final checkedCount = _checkedIngredientIds.length;
    final progress = totalCount > 0 ? checkedCount / totalCount : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFF121212), // Deep pure dark for high contrast
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        leading: IconButton(
          key: const Key('market_mode_back_btn'),
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 28),
          onPressed: () {
            if (widget.onFinishedShopping != null) {
              widget.onFinishedShopping!();
            }
            Navigator.of(context).maybePop();
          },
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber.shade400,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'MARKET',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _isNepali ? 'बजार मोड (चेकलिस्ट)' : 'Market Mode Checklist',
                style: NepaliTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            key: const Key('share_list_btn'),
            icon: const Icon(Icons.share_rounded, color: Colors.white, size: 24),
            tooltip: _isNepali ? 'सूची सेयर गर्नुहोस् (Share)' : 'Share Grocery List',
            onPressed: _openShareExportDialog,
          ),
          TextButton(
            key: const Key('market_mode_lang_toggle'),
            onPressed: () {
              setState(() {
                _language = _isNepali ? 'en' : 'ne';
              });
            },
            child: Text(
              _isNepali ? 'EN' : 'नेपाली',
              style: TextStyle(
                color: Colors.amber.shade400,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // High-contrast Progress Header
          _buildProgressBanner(progress, checkedCount, totalCount),

          // Stall Filter Chips
          _buildStallChips(),

          // High-contrast Checklist Items
          Expanded(
            child: _buildChecklist(),
          ),

          // Quick Done Bar
          _buildBottomDoneBar(checkedCount, totalCount),
        ],
      ),
    );
  }

  Widget _buildProgressBanner(double progress, int checkedCount, int totalCount) {
    final checkedLabel = _isNepali ? NepaliCalendar.toDevanagariDigits(checkedCount) : '$checkedCount';
    final totalLabel = _isNepali ? NepaliCalendar.toDevanagariDigits(totalCount) : '$totalCount';
    final percent = (progress * 100).round();
    final percentLabel = _isNepali ? NepaliCalendar.toDevanagariDigits(percent) : '$percent';

    return Container(
      color: const Color(0xFF1E1E1E),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isNepali
                    ? '$checkedLabel / $totalLabel सामग्री किनियो'
                    : '$checkedLabel of $totalLabel items checked',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              Text(
                '$percentLabel%',
                style: TextStyle(
                  color: Colors.amber.shade400,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(
                progress == 1.0 ? Colors.green.shade400 : Colors.amber.shade400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStallChips() {
    final stalls = widget.groceryResult.stalls;

    return Container(
      color: const Color(0xFF121212),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildHighContrastChip(
              key: const Key('market_filter_all'),
              label: _isNepali ? 'सबै' : 'All',
              icon: '🛍️',
              isSelected: _selectedStallId == 'all',
              onTap: () => setState(() => _selectedStallId = 'all'),
            ),
            const SizedBox(width: 8),
            ...stalls.map((group) {
              final isSelected = _selectedStallId == group.stall.id;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _buildHighContrastChip(
                  key: Key('market_filter_${group.stall.id}'),
                  label: _isNepali ? group.shortNameNe : group.nameEn,
                  icon: group.icon,
                  isSelected: isSelected,
                  onTap: () => setState(() => _selectedStallId = group.stall.id),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildHighContrastChip({
    required Key key,
    required String label,
    required String icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.amber.shade400 : const Color(0xFF242424),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.amber.shade400 : Colors.white24,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                color: isSelected ? Colors.black : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChecklist() {
    final displayedGroups = _selectedStallId == 'all'
        ? widget.groceryResult.stalls
        : widget.groceryResult.stalls.where((g) => g.stall.id == _selectedStallId).toList();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: displayedGroups.length,
      itemBuilder: (context, index) {
        final group = displayedGroups[index];
        return _buildHighContrastStallSection(group);
      },
    );
  }

  Widget _buildHighContrastStallSection(GroceryStallGroup group) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Stall Header
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
          child: Row(
            children: [
              Text(group.icon, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Text(
                _isNepali ? group.nameNe : group.nameEn,
                style: NepaliTypography.titleSmall.copyWith(
                  fontWeight: FontWeight.w900,
                  color: Colors.amber.shade300,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),

        // List of big-target items
        ...group.items.map((item) => _buildBigTapItemCard(item)),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildBigTapItemCard(GroceryItem item) {
    final isChecked = _checkedIngredientIds.contains(item.ingredientId);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isChecked ? const Color(0xFF1A1A1A) : const Color(0xFF262626),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isChecked ? Colors.green.shade900 : Colors.white12,
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key('market_item_${item.ingredientId}'),
          onTap: () => _toggleCheck(item),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Big Check Target (at least 48x48 touch target)
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isChecked ? Colors.green.shade600 : Colors.black38,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isChecked ? Colors.green.shade400 : Colors.white38,
                      width: 2,
                    ),
                  ),
                  child: isChecked
                      ? const Icon(Icons.check_rounded, color: Colors.white, size: 26)
                      : null,
                ),
                const SizedBox(width: 14),

                // Item Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isNepali ? item.nameNe : item.nameEn,
                        style: NepaliTypography.bodyLarge.copyWith(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          decoration: isChecked ? TextDecoration.lineThrough : null,
                          color: isChecked ? Colors.white38 : Colors.white,
                        ),
                      ),
                      if (item.nameNe != item.nameEn) ...[
                        const SizedBox(height: 2),
                        Text(
                          _isNepali ? item.nameEn : item.nameNe,
                          style: TextStyle(
                            fontSize: 12,
                            color: isChecked ? Colors.white24 : Colors.white60,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // Vendor Unit Badge (Prominent High Contrast)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isChecked ? Colors.white10 : Colors.amber.shade400,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _isNepali ? item.vendorUnitLabelNe : item.vendorUnitLabelEn,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: isChecked ? Colors.white38 : Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomDoneBar(int checkedCount, int totalCount) {
    return Container(
      color: const Color(0xFF1E1E1E),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            key: const Key('market_mode_finish_btn'),
            style: ElevatedButton.styleFrom(
              backgroundColor: checkedCount == totalCount
                  ? Colors.green.shade600
                  : SitiColors.terracotta,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            icon: const Icon(Icons.check_circle_outline_rounded, size: 22),
            label: Text(
              _isNepali ? 'किनमेल सम्पन्न गर्नुहोस्' : 'Finish Shopping',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            onPressed: () {
              if (widget.onFinishedShopping != null) {
                widget.onFinishedShopping!();
              }
              Navigator.of(context).maybePop();
            },
          ),
        ),
      ),
    );
  }
}

/// Modal bottom sheet for one-tap text sharing of the grocery list to WhatsApp, Viber, or SMS.
class _ShareListExportSheet extends StatefulWidget {
  final GroceryListResult groceryResult;
  final String initialLanguage;

  const _ShareListExportSheet({
    required this.groceryResult,
    required this.initialLanguage,
  });

  @override
  State<_ShareListExportSheet> createState() => _ShareListExportSheetState();
}

class _ShareListExportSheetState extends State<_ShareListExportSheet> {
  late String _language;
  bool _includePantryCovered = false;

  bool get _isNepali => _language == 'ne';

  @override
  void initState() {
    super.initState();
    _language = widget.initialLanguage;
  }

  String _generateText() {
    return exportGroceryListText(
      widget.groceryResult,
      preferNepali: _isNepali,
      includePantryCovered: _includePantryCovered,
    );
  }

  Future<void> _copyToClipboard() async {
    final text = _generateText();
    try {
      await Clipboard.setData(ClipboardData(text: text));
    } catch (_) {
      // Ignored for environments without system clipboard service
    }

    if (mounted) {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _isNepali
                ? 'किनमेल सूची कपी भयो! WhatsApp वा Viber मा पठाउन तयार छ।'
                : 'Grocery list copied! Ready to paste into WhatsApp, Viber, or SMS.',
          ),
          backgroundColor: Colors.green.shade800,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final exportedText = _generateText();

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isNepali ? 'किनमेल सूची सेयर (Share List)' : 'Share Grocery List',
                style: NepaliTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white60),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Options: Language and Pantry Inclusions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Language toggle pills
              Row(
                children: [
                  ChoiceChip(
                    key: const Key('export_lang_ne'),
                    label: const Text('नेपाली'),
                    selected: _isNepali,
                    selectedColor: Colors.amber.shade400,
                    labelStyle: TextStyle(
                      color: _isNepali ? Colors.black : Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    backgroundColor: const Color(0xFF2A2A2A),
                    onSelected: (_) => setState(() => _language = 'ne'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    key: const Key('export_lang_en'),
                    label: const Text('English'),
                    selected: !_isNepali,
                    selectedColor: Colors.amber.shade400,
                    labelStyle: TextStyle(
                      color: !_isNepali ? Colors.black : Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    backgroundColor: const Color(0xFF2A2A2A),
                    onSelected: (_) => setState(() => _language = 'en'),
                  ),
                ],
              ),

              // Include pantry toggle
              FilterChip(
                key: const Key('export_include_pantry_chip'),
                label: Text(
                  _isNepali ? 'घरमै भएको पनि' : 'Include pantry',
                  style: TextStyle(
                    fontSize: 12,
                    color: _includePantryCovered ? Colors.black : Colors.white70,
                  ),
                ),
                selected: _includePantryCovered,
                selectedColor: Colors.amber.shade400,
                backgroundColor: const Color(0xFF2A2A2A),
                onSelected: (val) => setState(() => _includePantryCovered = val),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Text Preview Container
          Container(
            height: 220,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF141414),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                exportedText,
                key: const Key('export_preview_text'),
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'monospace',
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Primary One-Tap Copy Button
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              key: const Key('copy_grocery_list_btn'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.copy_rounded, size: 20),
              label: Text(
                _isNepali ? 'प्रतिलिपि गर्नुहोस् (Copy to WhatsApp / SMS)' : 'Copy for WhatsApp / SMS',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              onPressed: _copyToClipboard,
            ),
          ),
        ],
      ),
    );
  }
}
