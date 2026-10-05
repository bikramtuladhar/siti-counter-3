import 'package:flutter/material.dart';
import 'package:kitchen_engine/kitchen_engine.dart';
import '../theme/tokens.dart';
import '../theme/nepali_typography.dart';
import 'community_badge.dart';
import 'community_service.dart';

class MarketPriceReportSheet extends StatefulWidget {
  final CommunityService service;
  final String commodityId;
  final String commodityNameNe;
  final String commodityNameEn;
  final double? baselineAvgPrice;
  final String currentLanguage;

  const MarketPriceReportSheet({
    super.key,
    required this.service,
    required this.commodityId,
    required this.commodityNameNe,
    required this.commodityNameEn,
    this.baselineAvgPrice,
    this.currentLanguage = 'ne',
  });

  static Future<CommunityContribution?> show({
    required BuildContext context,
    required CommunityService service,
    required String commodityId,
    required String commodityNameNe,
    required String commodityNameEn,
    double? baselineAvgPrice,
    String currentLanguage = 'ne',
  }) {
    return showModalBottomSheet<CommunityContribution>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MarketPriceReportSheet(
        service: service,
        commodityId: commodityId,
        commodityNameNe: commodityNameNe,
        commodityNameEn: commodityNameEn,
        baselineAvgPrice: baselineAvgPrice,
        currentLanguage: currentLanguage,
      ),
    );
  }

  @override
  State<MarketPriceReportSheet> createState() => _MarketPriceReportSheetState();
}

class _MarketPriceReportSheetState extends State<MarketPriceReportSheet> {
  final _formKey = GlobalKey<FormState>();
  final _marketNameController = TextEditingController(text: 'असन हाट बजार');
  final _priceController = TextEditingController();
  final _districtController = TextEditingController(text: 'काठमाडौं');

  String _marketType = 'haat_bazaar';
  String _unit = 'kg';
  bool _isSubmitting = false;
  CommunityContribution? _result;

  bool get _isNepali => widget.currentLanguage == 'ne';

  @override
  void initState() {
    super.initState();
    if (widget.baselineAvgPrice != null) {
      _priceController.text = widget.baselineAvgPrice!.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _marketNameController.dispose();
    _priceController.dispose();
    _districtController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final price = double.tryParse(_priceController.text.trim()) ?? 0.0;
    if (price <= 0) return;

    setState(() => _isSubmitting = true);

    final payload = CommunityPriceReportPayload(
      commodityId: widget.commodityId,
      commodityNameNe: widget.commodityNameNe,
      commodityNameEn: widget.commodityNameEn,
      marketName: _marketNameController.text.trim(),
      marketType: _marketType,
      observedPrice: price,
      unit: _unit,
      district: _districtController.text.trim(),
      reporterHouseholdId: 'hh_user',
      reporterDisplayName: 'Haat Reporter',
    );

    final contribution = await widget.service.submitPriceReport(
      payload,
      baselineAvgPrice: widget.baselineAvgPrice,
    );

    setState(() {
      _result = contribution;
      _isSubmitting = false;
    });

    if (contribution.moderation.isSafe && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isNepali
              ? 'बजार मूल्य रिपोर्ट सफलतापूर्वक थपियो!'
              : 'Market price sighting submitted!'),
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
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.storefront, color: Colors.orange.shade800, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isNepali ? 'स्थानीय बजार मूल्य रिपोर्ट' : 'Report Market Price',
                          style: NepaliTypography.titleSmall.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '${widget.commodityNameNe} (${widget.commodityNameEn})',
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
                        _result!.moderation.isSafe ? Icons.check_circle : Icons.warning_amber_rounded,
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

              // Market Type Dropdown
              DropdownButtonFormField<String>(
                key: const Key('market_type_dropdown'),
                isExpanded: true,
                initialValue: _marketType,
                decoration: InputDecoration(
                  labelText: _isNepali ? 'बजारको प्रकार (Market Type)' : 'Market Type',
                  border: const OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'haat_bazaar', child: Text('हाट बजार (Haat Bazaar / Wet Market)')),
                  DropdownMenuItem(value: 'local_kirana', child: Text('स्थानीय किराना (Local Kirana)')),
                  DropdownMenuItem(value: 'supermarket', child: Text('सुपरमार्केट (Supermarket)')),
                  DropdownMenuItem(value: 'wholesale', child: Text('थोक बजार (Wholesale / Mandi)')),
                ],
                onChanged: (val) => setState(() => _marketType = val ?? 'haat_bazaar'),
              ),
              const SizedBox(height: 14),

              // Market Name
              TextFormField(
                key: const Key('market_name_input'),
                controller: _marketNameController,
                decoration: InputDecoration(
                  labelText: _isNepali ? 'बजार वा पसलको नाम*' : 'Market Name*',
                  hintText: 'उदा: असन तरकारी बजार, बानेश्वर, लगनखेल',
                  border: const OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return _isNepali ? 'बजारको नाम आवश्यक छ' : 'Market name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Price and Unit Row
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      key: const Key('observed_price_input'),
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: _isNepali ? 'देखेको मूल्य (रु)*' : 'Observed Price (NPR)*',
                        hintText: 'e.g. 50',
                        border: const OutlineInputBorder(),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return _isNepali ? 'मूल्य आवश्यक छ' : 'Price is required';
                        }
                        final num = double.tryParse(val.trim());
                        if (num == null || num <= 0) {
                          return _isNepali ? 'अमान्य मूल्य' : 'Invalid price';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      key: const Key('unit_dropdown'),
                      isExpanded: true,
                      initialValue: _unit,
                      decoration: InputDecoration(
                        labelText: _isNepali ? 'इकाई' : 'Unit',
                        border: const OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'kg', child: Text('kg (के.जी.)')),
                        DropdownMenuItem(value: 'dharni', child: Text('धार्नी (2.5kg)')),
                        DropdownMenuItem(value: 'pau', child: Text('पाउ (250g)')),
                        DropdownMenuItem(value: 'mutha', child: Text('मुठा (Bunch)')),
                        DropdownMenuItem(value: 'piece', child: Text('गोटा (Piece)')),
                      ],
                      onChanged: (val) => setState(() => _unit = val ?? 'kg'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // District
              TextFormField(
                key: const Key('district_input'),
                controller: _districtController,
                decoration: InputDecoration(
                  labelText: _isNepali ? 'जिल्ला / सहर' : 'District / City',
                  hintText: 'e.g. Kathmandu, Lalitpur, Pokhara',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),

              // Submit Button
              ElevatedButton(
                key: const Key('submit_price_report_btn'),
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
                        _isNepali ? 'मूल्य रिपोर्ट पेश गर्नुहोस् (Submit Price)' : 'Submit Price',
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
