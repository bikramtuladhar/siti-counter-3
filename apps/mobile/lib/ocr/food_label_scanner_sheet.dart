import 'package:flutter/material.dart';
import 'package:kitchen_engine/kitchen_engine.dart';
import '../theme/nepali_typography.dart';
import '../theme/tokens.dart';
import 'ocr_scanner_service.dart';

/// Modal or screen scanning packaged food labels, highlighting allergens,
/// and displaying household safety verdicts (Section 22.1).
class FoodLabelScannerSheet extends StatefulWidget {
  final List<HouseholdMemberAllergyInput> householdMembers;
  final OcrScannerService scannerService;
  final String? initialLabelText;
  final bool isNepali;

  const FoodLabelScannerSheet({
    super.key,
    required this.householdMembers,
    this.scannerService = const OcrScannerService(),
    this.initialLabelText,
    this.isNepali = false,
  });

  @override
  State<FoodLabelScannerSheet> createState() => _FoodLabelScannerSheetState();
}

class _FoodLabelScannerSheetState extends State<FoodLabelScannerSheet> {
  late final TextEditingController _textController;
  LabelScanResult? _scanResult;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(
      text: widget.initialLabelText ??
          'Ingredients: Refined wheat flour, Sugar, Milk solids, Salt.\nContains Gluten and Milk.\nMay contain traces of Peanuts and Tree Nuts.',
    );
    _scanText(_textController.text);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _scanText(String text) {
    if (text.trim().isEmpty) return;
    _scanResult = widget.scannerService.scanFoodLabel(
      text,
      householdMembers: widget.householdMembers,
    );
  }

  void _scanCurrentText() {
    setState(() {
      _scanText(_textController.text);
    });
  }

  void _loadSample(String sampleType) {
    if (sampleType == 'allergen_heavy') {
      _textController.text =
          'Ingredients: Refined wheat flour (Maida 68%), Sugar, Edible Vegetable Oil, Milk solids (4%), Salt, Emulsifiers (Soy lecithin).\nAllergy Information: Contains Gluten, Milk and Soy.\nMay contain traces of Peanuts and Tree Nuts. Processed on shared equipment.';
    } else if (sampleType == 'safe') {
      _textController.text =
          'Ingredients: 100% Organic Rice, Salt, Water.\nFree from gluten, dairy, nuts, and soy.';
    } else if (sampleType == 'himalayan_buckwheat') {
      _textController.text =
          'सामग्रीहरू: अर्गानिक फापरको पीठो (Buckwheat flour), तोरीको तेल (Mustard oil), नुन।\nएलर्जी जानकारी: फापर र तोरी समावेश छ।';
    }
    _scanCurrentText();
  }

  @override
  Widget build(BuildContext context) {
    final isNepali = widget.isNepali;

    return Container(
      decoration: const BoxDecoration(
        color: SitiColors.dark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(SitiSpacing.md),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header Title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    isNepali ? 'खाद्य लेबल र एलर्जी स्क्यानर' : 'Food Label & Allergen Scanner',
                    style: NepaliTypography.titleLarge.copyWith(color: Colors.white),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: SitiSpacing.sm),

            // Quick Samples
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: SitiColors.warning,
                      side: const BorderSide(color: SitiColors.warning),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onPressed: () => _loadSample('allergen_heavy'),
                    child: Text(
                      isNepali ? 'बिस्कुट (गहुँ/दूध/बदाम)' : 'Biscuits Label',
                      style: NepaliTypography.bodySmall.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: SitiColors.freshGreen,
                      side: const BorderSide(color: SitiColors.freshGreen),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onPressed: () => _loadSample('safe'),
                    child: Text(
                      isNepali ? 'सुरक्षित (चामल)' : 'Safe Rice Label',
                      style: NepaliTypography.bodySmall.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: SitiSpacing.md),

            // Label OCR Text Input
            Container(
              decoration: BoxDecoration(
                color: SitiColors.cardDark,
                borderRadius: SitiRadius.roundedMd,
                border: Border.all(color: Colors.white24),
              ),
              padding: const EdgeInsets.all(SitiSpacing.sm),
              child: TextField(
                controller: _textController,
                maxLines: 4,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: isNepali
                      ? 'प्याकेजिङ लेबलको पाठ टाइप वा स्क्यान गर्नुहोस्...'
                      : 'Scan or paste food packaging label text...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  border: InputBorder.none,
                ),
                onChanged: (_) => _scanCurrentText(),
              ),
            ),
            const SizedBox(height: SitiSpacing.md),

            // Safety Verdict Banner
            if (_scanResult != null) ...[
              _buildSafetyVerdictBanner(_scanResult!, isNepali),
              const SizedBox(height: SitiSpacing.md),

              // Highlighted Text View
              _buildHighlightedLabelView(_scanResult!, isNepali),
              const SizedBox(height: SitiSpacing.md),

              // Member Alerts
              if (_scanResult!.memberAlerts.isNotEmpty) ...[
                Text(
                  isNepali ? 'पारिवारिक सदस्यहरूको चेतावनी:' : 'Household Member Warnings:',
                  style: NepaliTypography.titleMedium.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 8),
                ..._scanResult!.memberAlerts.map(
                  (alert) => _buildMemberAlertCard(alert, isNepali),
                ),
                const SizedBox(height: SitiSpacing.md),
              ],

              // Detected Tags
              if (_scanResult!.detectedAllergens.isNotEmpty ||
                  _scanResult!.facilityWarnings.isNotEmpty) ...[
                Text(
                  isNepali ? 'पत्ता लागेका तत्त्वहरू:' : 'Detected Allergens:',
                  style: NepaliTypography.titleMedium.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ..._scanResult!.detectedAllergens.map(
                      (a) => Chip(
                        backgroundColor: SitiColors.alert.withAlpha(50),
                        side: const BorderSide(color: SitiColors.alert),
                        avatar: const Icon(Icons.error_outline, size: 16, color: SitiColors.alert),
                        label: Text(
                          'Contains ${a.replaceAll('_', ' ')}',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ),
                    ..._scanResult!.facilityWarnings.map(
                      (a) => Chip(
                        backgroundColor: SitiColors.warning.withAlpha(50),
                        side: const BorderSide(color: SitiColors.warning),
                        avatar: const Icon(Icons.warning_amber_rounded,
                            size: 16, color: SitiColors.warning),
                        label: Text(
                          'May contain ${a.replaceAll('_', ' ')}',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
            const SizedBox(height: SitiSpacing.lg),
          ],
        ),
      ),
    );
  }

  Widget _buildSafetyVerdictBanner(LabelScanResult result, bool isNepali) {
    if (!result.isSafeForHousehold) {
      return Container(
        key: const Key('verdict_danger_banner'),
        padding: const EdgeInsets.all(SitiSpacing.md),
        decoration: BoxDecoration(
          color: SitiColors.alert.withAlpha(50),
          borderRadius: SitiRadius.roundedMd,
          border: Border.all(color: SitiColors.alert, width: 2),
        ),
        child: Row(
          children: [
            const Icon(Icons.dangerous, color: SitiColors.alert, size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isNepali ? 'परिवारको लागि असुरक्षित!' : 'NOT SAFE FOR HOUSEHOLD!',
                    style: NepaliTypography.titleMedium.copyWith(
                      color: SitiColors.alert,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isNepali
                        ? 'परिवारका सदस्यहरूलाई कडा एलर्जी हुने तत्त्व पत्ता लाग्यो।'
                        : 'Contains allergens matching severe household member profiles.',
                    style: NepaliTypography.bodySmall.copyWith(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else if (result.facilityWarnings.isNotEmpty) {
      return Container(
        key: const Key('verdict_caution_banner'),
        padding: const EdgeInsets.all(SitiSpacing.md),
        decoration: BoxDecoration(
          color: SitiColors.warning.withAlpha(50),
          borderRadius: SitiRadius.roundedMd,
          border: Border.all(color: SitiColors.warning, width: 1.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: SitiColors.warning, size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isNepali ? 'सावधानी अपनाउनुहोस्' : 'PROCEED WITH CAUTION',
                    style: NepaliTypography.titleMedium.copyWith(
                      color: SitiColors.warning,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isNepali
                        ? 'यसमा सम्भावित क्रस-कन्ट्याक्ट वा अवशेष हुन सक्छ।'
                        : 'Possible trace / facility cross-contact detected.',
                    style: NepaliTypography.bodySmall.copyWith(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        key: const Key('verdict_safe_banner'),
        padding: const EdgeInsets.all(SitiSpacing.md),
        decoration: BoxDecoration(
          color: SitiColors.freshGreen.withAlpha(50),
          borderRadius: SitiRadius.roundedMd,
          border: Border.all(color: SitiColors.freshGreen, width: 1.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: SitiColors.freshGreen, size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isNepali ? 'परिवारको लागि सुरक्षित' : 'SAFE FOR ALL MEMBERS',
                    style: NepaliTypography.titleMedium.copyWith(
                      color: SitiColors.freshGreen,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isNepali
                        ? 'कुनै पनि पारिवारिक एलर्जीसँग मेल खाने तत्त्व भेटिएन।'
                        : 'No matching household allergen conflicts found.',
                    style: NepaliTypography.bodySmall.copyWith(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildHighlightedLabelView(LabelScanResult result, bool isNepali) {
    // Generate TextSpans highlighting detected allergens
    final spans = <TextSpan>[];
    final sortedHighlights = List<LabelHighlightSpan>.from(result.highlightSpans)
      ..sort((a, b) => a.start.compareTo(b.start));

    int currentIndex = 0;
    final text = result.rawText;

    for (final highlight in sortedHighlights) {
      if (highlight.start > currentIndex && highlight.start <= text.length) {
        spans.add(TextSpan(
          text: text.substring(currentIndex, highlight.start),
          style: const TextStyle(color: Colors.white70),
        ));
      }

      if (highlight.start >= currentIndex && highlight.end <= text.length) {
        final isDanger = highlight.warningType == AllergenWarningType.contains;
        spans.add(TextSpan(
          text: text.substring(highlight.start, highlight.end),
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            backgroundColor: isDanger ? SitiColors.alert : SitiColors.warning,
          ),
        ));
        currentIndex = highlight.end;
      }
    }

    if (currentIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(currentIndex),
        style: const TextStyle(color: Colors.white70),
      ));
    }

    return Container(
      padding: const EdgeInsets.all(SitiSpacing.md),
      decoration: BoxDecoration(
        color: SitiColors.cardDark,
        borderRadius: SitiRadius.roundedMd,
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.highlight, color: SitiColors.terracotta, size: 16),
              const SizedBox(width: 6),
              Text(
                isNepali ? 'हाइलाइट गरिएको विश्लेषण:' : 'Highlighted Label Analysis:',
                style: NepaliTypography.bodySmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 13, height: 1.5),
              children: spans,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberAlertCard(MemberAllergenAlert alert, bool isNepali) {
    final isDanger = alert.warningType == AllergenWarningType.contains;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(SitiSpacing.sm),
      decoration: BoxDecoration(
        color: SitiColors.cardDark,
        borderRadius: SitiRadius.roundedSm,
        border: Border.all(
          color: isDanger ? SitiColors.alert.withAlpha(120) : SitiColors.warning.withAlpha(120),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isDanger ? Icons.warning_rounded : Icons.info_outline,
            color: isDanger ? SitiColors.alert : SitiColors.warning,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      alert.memberName,
                      style: NepaliTypography.bodyMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDanger ? SitiColors.alert.withAlpha(60) : SitiColors.warning.withAlpha(60),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        alert.severity.name.toUpperCase(),
                        style: TextStyle(
                          color: isDanger ? SitiColors.alert : SitiColors.warning,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  isNepali ? alert.alertNe : alert.alertEn,
                  style: NepaliTypography.bodySmall.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
