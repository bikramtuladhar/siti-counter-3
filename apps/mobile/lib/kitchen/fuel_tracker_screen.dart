import 'package:flutter/material.dart';
import 'package:kitchen_engine/kitchen_engine.dart';
import '../theme/tokens.dart';
import '../theme/nepali_typography.dart';

/// Screen for tracking LPG gas cylinder depletion and activating power-cut mode
class FuelTrackerScreen extends StatefulWidget {
  final LpgCylinderState initialCylinder;
  final List<CookingFuelSession> recentSessions;
  final List<PowerCutRecipeItem>? customRecipes;
  final String currentLanguage;
  final void Function(LpgCylinderState updatedCylinder)? onCylinderUpdated;

  const FuelTrackerScreen({
    super.key,
    required this.initialCylinder,
    this.recentSessions = const [],
    this.customRecipes,
    this.currentLanguage = 'ne',
    this.onCylinderUpdated,
  });

  @override
  State<FuelTrackerScreen> createState() => _FuelTrackerScreenState();
}

class _FuelTrackerScreenState extends State<FuelTrackerScreen> {
  late LpgCylinderState _cylinder;
  bool _isPowerCutActive = false;
  String _powerCutFilter = 'all'; // 'all', 'no_cook', 'gas_saver'

  bool get _isNepali => widget.currentLanguage == 'ne';

  final List<PowerCutRecipeItem> _defaultRecipes = const [
    PowerCutRecipeItem(
      id: 'pc-1',
      nameEn: 'Chiura Dahi with Mashed Banana',
      nameNe: 'चिउरा दही र केरा',
      powerProfile: RecipePowerProfile.noCook,
      cookTimeMinutes: 5,
      isGasSaver: true,
    ),
    PowerCutRecipeItem(
      id: 'pc-2',
      nameEn: 'Bhatmas Sadeko (Spiced Soya Snack)',
      nameNe: 'भटमास साँधेको',
      powerProfile: RecipePowerProfile.noCook,
      cookTimeMinutes: 8,
      isGasSaver: true,
    ),
    PowerCutRecipeItem(
      id: 'pc-3',
      nameEn: 'Quick Pressure Cooker Khichdi',
      nameNe: 'प्रेसर कुकर खिचडी',
      powerProfile: RecipePowerProfile.gasPressureCooker,
      cookTimeMinutes: 18,
      whistles: 2,
      isGasSaver: true,
    ),
    PowerCutRecipeItem(
      id: 'pc-4',
      nameEn: 'Everyday Yellow Dal & Rice',
      nameNe: 'दाल र भात (ग्यास चुल्हो)',
      powerProfile: RecipePowerProfile.gasPressureCooker,
      cookTimeMinutes: 22,
      whistles: 3,
      isGasSaver: false,
    ),
    PowerCutRecipeItem(
      id: 'pc-5',
      nameEn: 'Electric Induction Cream Soup',
      nameNe: 'इन्डक्सन क्रिम सुप',
      powerProfile: RecipePowerProfile.electricAppliance,
      cookTimeMinutes: 30,
      isGasSaver: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _cylinder = widget.initialCylinder;
  }

  void _openCalibrateDialog() {
    final weightCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          _isNepali ? 'स्केलबाट तौल प्रविष्ट गर्नुहोस्' : 'Calibrate from Scale',
          style: NepaliTypography.titleSmall.copyWith(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isNepali
                  ? 'बाथरूम वा लगेज स्केलमा सिलिन्डर जोख्नुहोस् र कुल तौल (Gross Weight) यहाँ लेख्नुहोस्:'
                  : 'Weigh the cylinder on a bathroom scale and enter the gross weight:',
              style: NepaliTypography.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: weightCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: _isNepali ? 'कुल तौल (के.जी.)' : 'Gross Weight (kg)',
                hintText: 'e.g. 21.5',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isNepali
                  ? 'खाली सिलिन्डरको तौल (Tare): ${_cylinder.tareWeightKg} के.जी.'
                  : 'Empty Cylinder Tare: ${_cylinder.tareWeightKg} kg',
              style: NepaliTypography.labelSmall.copyWith(color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_isNepali ? 'रद्द' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(weightCtrl.text.trim());
              if (val != null && val > _cylinder.tareWeightKg) {
                setState(() {
                  _cylinder = _cylinder.calibrateFromGrossWeight(val);
                });
                widget.onCylinderUpdated?.call(_cylinder);
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: SitiColors.terracotta,
              foregroundColor: Colors.white,
            ),
            child: Text(_isNepali ? 'अद्यावधिक गर्नुहोस्' : 'Calibrate'),
          ),
        ],
      ),
    );
  }

  void _resetToNewCylinder() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_isNepali ? 'नयाँ सिलिन्डर जोड्नुभयो?' : 'New Cylinder Installed?'),
        content: Text(
          _isNepali
              ? 'यसले ग्यासको परिमाण पूर्ण १४.२ के.जी. मा रिसेट गर्नेछ।'
              : 'This will reset remaining gas to a fresh full 14.2 kg cylinder.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_isNepali ? 'रद्द' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _cylinder = LpgCylinderState.newCylinder(
                  brand: _cylinder.brand,
                  tareWeightKg: _cylinder.tareWeightKg,
                );
              });
              widget.onCylinderUpdated?.call(_cylinder);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: SitiColors.freshGreen),
            child: Text(_isNepali ? 'हो, रिसेट गर्नुहोस्' : 'Confirm New'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final forecast = FuelEngine.predictDepletion(
      cylinder: _cylinder,
      recentSessions: widget.recentSessions,
    );

    final allRecipes = widget.customRecipes ?? _defaultRecipes;
    final powerCutFiltered = FuelEngine.filterForPowerCut(
      recipes: allRecipes,
      gasSaverOnly: _powerCutFilter == 'gas_saver',
      noCookOnly: _powerCutFilter == 'no_cook',
    );

    return Scaffold(
      backgroundColor: SitiColors.warmWhite,
      appBar: AppBar(
        title: Text(
          _isNepali ? 'ग्यास र इन्धन व्यवस्थापन' : 'LPG Fuel & Outage Resiliency',
          style: NepaliTypography.titleMedium.copyWith(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Refill Alert Banner (if order needed)
            if (forecast.isRefillNeeded) ...[
              _buildRefillAlertBanner(forecast),
              const SizedBox(height: 16),
            ],

            // 2. LPG Cylinder Visualizer Card
            _buildCylinderCard(forecast),
            const SizedBox(height: 20),

            // 3. Power-Cut Mode Toggle Card
            _buildPowerCutToggleCard(),
            const SizedBox(height: 16),

            // 4. Power-cut recipe list (when active or previewed)
            if (_isPowerCutActive) ...[
              _buildPowerCutSection(powerCutFiltered),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRefillAlertBanner(LpgDepletionForecast forecast) {
    Color bannerBg;
    Color borderC;
    Color textC;

    if (forecast.urgency == RefillUrgency.empty || forecast.urgency == RefillUrgency.critical) {
      bannerBg = Colors.red.shade50;
      borderC = Colors.red.shade400;
      textC = Colors.red.shade900;
    } else {
      bannerBg = Colors.amber.shade50;
      borderC = Colors.amber.shade400;
      textC = Colors.brown.shade900;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bannerBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderC, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                forecast.urgency == RefillUrgency.critical || forecast.urgency == RefillUrgency.empty
                    ? Icons.warning_rounded
                    : Icons.notifications_active_rounded,
                color: textC,
                size: 26,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _isNepali ? 'सिलिन्डर रिफिल सूचना' : 'LPG Refill Alert',
                  style: NepaliTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.w800,
                    color: textC,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _isNepali ? forecast.refillAlertMessageNe : forecast.refillAlertMessageEn,
            style: NepaliTypography.bodySmall.copyWith(color: textC, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(_isNepali ? 'डिलर सम्पर्क डायल गरिँदै...' : 'Opening dealer dialer...'),
                      backgroundColor: SitiColors.terracotta,
                    ),
                  );
                },
                icon: const Icon(Icons.call_rounded, size: 18),
                label: Text(_isNepali ? 'डिलरलाई फोन गर्नुहोस्' : 'Call Gas Dealer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SitiColors.terracotta,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _openSafetyChecklist,
                icon: const Icon(Icons.verified_user_rounded, size: 18),
                label: Text(_isNepali ? 'सुरक्षा जाँच सूची' : 'Safety Check'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: textC,
                  side: BorderSide(color: borderC),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openSafetyChecklist() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isNepali ? 'एलपिजी ग्यास सुरक्षा जाँच' : 'LPG Safety Checklist',
              style: NepaliTypography.titleMedium.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            _buildSafetyTip(
              _isNepali ? '१. सिलिन्डरको सिल अक्षुण्ण रहेको जाँच गर्नुहोस्।' : '1. Check that the plastic safety seal is intact.',
            ),
            _buildSafetyTip(
              _isNepali ? '२. लिकेज जाँच्न सधैं साबुन-पानी प्रयोग गर्नुहोस् (सलाई कहिल्यै नबाल्नुहोस्)।' : '2. Always use soap water to check for valve leaks. Never use a matchstick!',
            ),
            _buildSafetyTip(
              _isNepali ? '३. सिलिन्डर सधैं ठाडो (उभिएको) स्थितिमा राख्नुहोस्।' : '3. Always keep cylinder in upright vertical position.',
            ),
            _buildSafetyTip(
              _isNepali ? '४. ग्यासको गन्ध आउनासाथ झ्याल-ढोका खोल्नुहोस् र बिजुलीका स्विच नछुनुहोस्।' : '4. In case of gas smell, open windows immediately. Do not flip electrical switches.',
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(backgroundColor: SitiColors.terracotta),
              child: Text(_isNepali ? 'बुझें' : 'Got it'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSafetyTip(String tip) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_rounded, color: Colors.green, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(tip, style: NepaliTypography.bodySmall)),
        ],
      ),
    );
  }

  Widget _buildCylinderCard(LpgDepletionForecast forecast) {
    Color gaugeColor;
    if (forecast.remainingPercentage > 30) {
      gaugeColor = Colors.green;
    } else if (forecast.remainingPercentage > 15) {
      gaugeColor = Colors.amber.shade700;
    } else {
      gaugeColor = Colors.red;
    }

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Brand & Type Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: SitiColors.terracotta.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.local_fire_department_rounded, color: SitiColors.terracotta, size: 24),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _cylinder.brand,
                          style: NepaliTypography.titleSmall.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          _cylinder.type.label,
                          style: NepaliTypography.labelSmall.copyWith(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: gaugeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: gaugeColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    _isNepali
                        ? '~${forecast.estimatedDaysRemaining.toStringAsFixed(0)} दिन बाँकी'
                        : '~${forecast.estimatedDaysRemaining.toStringAsFixed(0)} Days Left',
                    style: TextStyle(
                      color: gaugeColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Progress bar and remaining values
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      _cylinder.remainingGasKg.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: SitiColors.dark,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '/ ${_cylinder.initialNetGasKg.toStringAsFixed(1)} kg',
                      style: NepaliTypography.bodyMedium.copyWith(color: Colors.grey.shade600),
                    ),
                  ],
                ),
                Text(
                  '${_cylinder.percentageRemaining.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: gaugeColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (_cylinder.percentageRemaining / 100.0).clamp(0.0, 1.0),
                minHeight: 12,
                backgroundColor: Colors.grey.shade100,
                color: gaugeColor,
              ),
            ),
            const SizedBox(height: 16),

            // Burn-rate metadata
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(
                        _isNepali ? 'दैनिक औसत' : 'Daily Burn',
                        style: NepaliTypography.labelSmall.copyWith(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '~${forecast.averageDailyBurnGrams.toStringAsFixed(0)}g / day',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ],
                  ),
                  Container(height: 24, width: 1, color: Colors.grey.shade300),
                  Column(
                    children: [
                      Text(
                        _isNepali ? 'खाली सिलिन्डर (Tare)' : 'Empty Tare',
                        style: NepaliTypography.labelSmall.copyWith(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_cylinder.tareWeightKg.toStringAsFixed(1)} kg',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Calibration & Reset Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _openCalibrateDialog,
                    icon: const Icon(Icons.scale_rounded, size: 16),
                    label: Text(_isNepali ? 'तौल मिलाउनुहोस्' : 'Calibrate Scale'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: SitiColors.terracotta,
                      side: BorderSide(color: SitiColors.terracotta),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _resetToNewCylinder,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: Text(_isNepali ? 'नयाँ सिलिन्डर' : 'New Cylinder'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: SitiColors.freshGreen,
                      side: BorderSide(color: SitiColors.freshGreen),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPowerCutToggleCard() {
    return Card(
      elevation: 0,
      color: _isPowerCutActive ? Colors.amber.shade50 : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: _isPowerCutActive ? Colors.amber.shade400 : Colors.grey.shade200,
          width: _isPowerCutActive ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _isPowerCutActive ? Colors.amber.shade200 : Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.bolt_rounded,
                    color: _isPowerCutActive ? Colors.brown.shade900 : Colors.grey.shade700,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isNepali ? 'पावर-कट मोड (Power-Cut Mode)' : 'Power-Cut Mode',
                        style: NepaliTypography.titleSmall.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        _isNepali
                            ? 'लोडसेडिङ हुँदा: ग्यास र नो-कुक परिकार मात्र'
                            : 'During outages: Filter gas-only & no-cook meals',
                        style: NepaliTypography.bodySmall.copyWith(color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _isPowerCutActive,
                  onChanged: (val) {
                    setState(() => _isPowerCutActive = val);
                  },
                  activeColor: Colors.amber.shade900,
                  activeTrackColor: Colors.amber.shade300,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPowerCutSection(List<PowerCutRecipeItem> recipes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ChoiceChip(
                label: Text(_isNepali ? 'सबै उपयुक्त (${recipes.length})' : 'All Compatible (${recipes.length})'),
                selected: _powerCutFilter == 'all',
                onSelected: (s) => setState(() => _powerCutFilter = 'all'),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text(_isNepali ? 'नो-कुक (आगो नचाहिने)' : 'No-Cook (No Heat)'),
                selected: _powerCutFilter == 'no_cook',
                onSelected: (s) => setState(() => _powerCutFilter = 'no_cook'),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text(_isNepali ? 'ग्यास बचत (Gas Saver)' : 'Gas Saver (<=20m)'),
                selected: _powerCutFilter == 'gas_saver',
                onSelected: (s) => setState(() => _powerCutFilter = 'gas_saver'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Recipe items
        ...recipes.map((r) => _buildPowerCutRecipeCard(r)),
      ],
    );
  }

  Widget _buildPowerCutRecipeCard(PowerCutRecipeItem item) {
    String profileLabel;
    Color profileColor;
    IconData profileIcon;

    switch (item.powerProfile) {
      case RecipePowerProfile.noCook:
        profileLabel = _isNepali ? 'नो-कुक' : 'No Cook';
        profileColor = Colors.teal;
        profileIcon = Icons.eco_rounded;
        break;
      case RecipePowerProfile.gasPressureCooker:
        profileLabel = _isNepali ? 'कुकर (${item.whistles} सिट्ठी)' : 'Cooker (${item.whistles} whistles)';
        profileColor = Colors.orange.shade800;
        profileIcon = Icons.timer_outlined;
        break;
      case RecipePowerProfile.gasStoveTop:
        profileLabel = _isNepali ? 'ग्यास चुल्हो' : 'Gas Stove';
        profileColor = Colors.deepOrange;
        profileIcon = Icons.local_fire_department_outlined;
        break;
      case RecipePowerProfile.electricAppliance:
        profileLabel = 'Electric';
        profileColor = Colors.grey;
        profileIcon = Icons.electric_bolt_rounded;
        break;
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: profileColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(profileIcon, color: profileColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isNepali ? item.nameNe : item.nameEn,
                    style: NepaliTypography.titleSmall.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: profileColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          profileLabel,
                          style: TextStyle(color: profileColor, fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '⏱ ~${item.cookTimeMinutes} m',
                        style: NepaliTypography.labelSmall.copyWith(color: Colors.grey.shade600),
                      ),
                      if (item.isGasSaver) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.green.shade300),
                          ),
                          child: Text(
                            _isNepali ? 'ग्यास बचत' : 'Gas Saver',
                            style: TextStyle(color: Colors.green.shade800, fontSize: 10, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.play_circle_fill_rounded, color: SitiColors.terracotta, size: 32),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      _isNepali
                          ? '${item.nameNe} पकाउन सुरु गरियो!'
                          : 'Starting cooking session for ${item.nameEn}!',
                    ),
                    backgroundColor: SitiColors.terracotta,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
