import 'package:flutter/material.dart';
import 'package:kitchen_engine/kitchen_engine.dart';
import '../theme/tokens.dart';
import '../theme/nepali_typography.dart';
import 'community_badge.dart';
import 'community_service.dart';

class IngredientAliasSheet extends StatefulWidget {
  final CommunityService service;
  final String canonicalIngredientId;
  final String ingredientNameNe;
  final String ingredientNameEn;
  final String currentLanguage;

  const IngredientAliasSheet({
    super.key,
    required this.service,
    required this.canonicalIngredientId,
    required this.ingredientNameNe,
    required this.ingredientNameEn,
    this.currentLanguage = 'ne',
  });

  static Future<CommunityContribution?> show({
    required BuildContext context,
    required CommunityService service,
    required String canonicalIngredientId,
    required String ingredientNameNe,
    required String ingredientNameEn,
    String currentLanguage = 'ne',
  }) {
    return showModalBottomSheet<CommunityContribution>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => IngredientAliasSheet(
        service: service,
        canonicalIngredientId: canonicalIngredientId,
        ingredientNameNe: ingredientNameNe,
        ingredientNameEn: ingredientNameEn,
        currentLanguage: currentLanguage,
      ),
    );
  }

  @override
  State<IngredientAliasSheet> createState() => _IngredientAliasSheetState();
}

class _IngredientAliasSheetState extends State<IngredientAliasSheet> {
  final _formKey = GlobalKey<FormState>();
  final _aliasNeController = TextEditingController();
  final _aliasEnController = TextEditingController();
  final _notesController = TextEditingController();

  String _dialectRegion = 'Newa / Kathmandu';
  bool _isSubmitting = false;
  CommunityContribution? _result;

  bool get _isNepali => widget.currentLanguage == 'ne';

  @override
  void dispose() {
    _aliasNeController.dispose();
    _aliasEnController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final payload = CommunityIngredientAliasPayload(
      canonicalIngredientId: widget.canonicalIngredientId,
      dialectRegion: _dialectRegion,
      aliasNe: _aliasNeController.text.trim(),
      aliasEn: _aliasEnController.text.trim().isNotEmpty
          ? _aliasEnController.text.trim()
          : _aliasNeController.text.trim(),
      notes: _notesController.text.trim().isNotEmpty
          ? _notesController.text.trim()
          : null,
      authorHouseholdId: 'hh_user',
      authorDisplayName: 'Community Member',
    );

    final contribution = await widget.service.submitIngredientAlias(payload);

    setState(() {
      _result = contribution;
      _isSubmitting = false;
    });

    if (contribution.moderation.isSafe && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isNepali
              ? 'स्थानीय नाम सफलतापूर्वक सुरक्षित भयो!'
              : 'Ingredient alias submitted successfully!'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.translate, color: Colors.teal.shade700, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isNepali ? 'स्थानीय / लवज नाम थप्नुहोस्' : 'Suggest Local Name',
                          style: NepaliTypography.titleSmall.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '${widget.ingredientNameNe} (${widget.ingredientNameEn})',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(_result),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (_result != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _result!.moderation.isSafe ? Colors.green.shade50 : Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _result!.moderation.isSafe ? Colors.green.shade200 : Colors.amber.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _result!.moderation.isSafe ? Icons.check_circle : Icons.info,
                        color: _result!.moderation.isSafe ? Colors.green.shade800 : Colors.amber.shade800,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _isNepali ? _result!.moderation.feedbackNe : _result!.moderation.feedbackEn,
                          style: TextStyle(
                            fontSize: 12,
                            color: _result!.moderation.isSafe ? Colors.green.shade900 : Colors.amber.shade900,
                          ),
                        ),
                      ),
                      CommunityBadge(badge: _result!.badge, isNepali: _isNepali),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Dialect Region Dropdown
              DropdownButtonFormField<String>(
                key: const Key('dialect_region_dropdown'),
                isExpanded: true,
                initialValue: _dialectRegion,
                decoration: InputDecoration(
                  labelText: _isNepali ? 'क्षेत्र वा समुदाय (Community / Region)' : 'Community / Region',
                  border: const OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'Newa / Kathmandu', child: Text('Newa / Kathmandu (काठमाडौं उपत्यका)')),
                  DropdownMenuItem(value: 'Thakali / Mustang', child: Text('Thakali / Mustang (मुस्ताङ)')),
                  DropdownMenuItem(value: 'Mithila / Janakpur', child: Text('Mithila / Terai (जनकपुर/तराई)')),
                  DropdownMenuItem(value: 'Kirat / Eastern Hills', child: Text('Kirat / Eastern Hills (पूर्वी पहाड)')),
                  DropdownMenuItem(value: 'Diaspora / Sydney', child: Text('Diaspora / Sydney (अस्ट्रेलिया)')),
                  DropdownMenuItem(value: 'Diaspora / London', child: Text('Diaspora / UK (बेलायत)')),
                  DropdownMenuItem(value: 'Diaspora / Dallas', child: Text('Diaspora / USA (अमेरिका)')),
                ],
                onChanged: (val) => setState(() => _dialectRegion = val ?? 'Newa / Kathmandu'),
              ),
              const SizedBox(height: 14),

              // Local Name Ne
              TextFormField(
                key: const Key('alias_name_ne_input'),
                controller: _aliasNeController,
                decoration: InputDecoration(
                  labelText: _isNepali ? 'स्थानीय लवज नाम (नेपाली/देवनागरी)*' : 'Local Alias (Devanagari)*',
                  hintText: 'उदा: काउली, सिस्नु, कुभिण्डो, छ्याङ',
                  border: const OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return _isNepali ? 'स्थानीय नाम आवश्यक छ' : 'Name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Local Name En (Romanized)
              TextFormField(
                key: const Key('alias_name_en_input'),
                controller: _aliasEnController,
                decoration: InputDecoration(
                  labelText: _isNepali ? 'रोमन लिपि (Romanized English)' : 'Romanized Alias',
                  hintText: 'e.g. Kauli, Chhuk, Sisnu',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),

              // Notes
              TextFormField(
                key: const Key('alias_notes_input'),
                controller: _notesController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: _isNepali ? 'उपयोग वा सन्दर्भ (Cultural context)' : 'Context / Usage',
                  hintText: 'उदा: नेवारी भोजमा यसलाई विशेष रूपमा बोलाइन्छ...',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),

              // Submit Button
              ElevatedButton(
                key: const Key('submit_alias_btn'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SitiColors.terracotta,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        _isNepali ? 'स्थानीय नाम थप्नुहोस् (Save Alias)' : 'Save Alias',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
