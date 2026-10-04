library;

import 'package:flutter/material.dart';
import 'package:kitchen_engine/kitchen_engine.dart';
import '../data/region_pack_repository.dart';
import '../theme/nepali_typography.dart';
import '../theme/tokens.dart';

class RegionManagerScreen extends StatefulWidget {
  final RegionPackRepository? repository;
  final String currentLanguage;

  const RegionManagerScreen({
    super.key,
    this.repository,
    this.currentLanguage = 'ne',
  });

  @override
  State<RegionManagerScreen> createState() => _RegionManagerScreenState();
}

class _RegionManagerScreenState extends State<RegionManagerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late RegionPackRepository _repo;

  bool get _isNepali => widget.currentLanguage == 'ne';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _repo = widget.repository ?? RegionPackRepository();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SitiColors.warmWhite,
      appBar: AppBar(
        backgroundColor: SitiColors.warmWhite,
        elevation: 0,
        title: Text(
          _isNepali ? 'क्षेत्र व्यवस्थापन (Region Packs)' : 'Region Pack Manager',
          style: NepaliTypography.titleLarge.copyWith(
            fontWeight: FontWeight.w700,
            color: SitiColors.dark,
          ),
        ),
        actions: [
          IconButton(
            key: const Key('add_custom_region_appbar_btn'),
            icon: const Icon(Icons.add_location_alt_rounded, color: SitiColors.terracotta),
            tooltip: _isNepali ? 'नयाँ क्षेत्र थप्नुहोस्' : 'Add Custom Region',
            onPressed: _showCustomRegionDialog,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: SitiColors.terracotta,
          unselectedLabelColor: Colors.grey.shade600,
          indicatorColor: SitiColors.terracotta,
          tabs: [
            Tab(
              key: const Key('tab_active_diaspora'),
              text: _isNepali ? 'सक्रिय र डायस्पोरा' : 'Active & Diaspora',
            ),
            Tab(
              key: const Key('tab_catalog_store'),
              text: _isNepali ? 'क्षेत्र स्टोर' : 'Pack Store',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildActiveAndDiasporaTab(),
          _buildPackStoreTab(),
        ],
      ),
    );
  }

  // --- Tab 1: Active Residence & Diaspora Layering ---
  Widget _buildActiveAndDiasporaTab() {
    final contextData = _repo.context;
    final primary = contextData.primaryPack;
    final secondaries = contextData.secondaryPacks;
    final installedPacks = _repo.manager.installedPacks.values.toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Primary Residence Card
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isNepali ? 'मुख्य बसोबास क्षेत्र (Primary Residence)' : 'Primary Residence',
                      style: NepaliTypography.labelLarge.copyWith(
                        color: SitiColors.terracotta,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade300),
                      ),
                      child: Text(
                        _isNepali ? 'सक्रिय (Active)' : 'Active',
                        style: NepaliTypography.labelSmall.copyWith(
                          color: Colors.green.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  primary.manifest.name,
                  style: NepaliTypography.headlineMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: SitiColors.dark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${primary.manifest.country} • ${primary.manifest.elevationMeters}m Elevation',
                  style: NepaliTypography.bodyMedium.copyWith(color: Colors.grey.shade700),
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        _isNepali ? 'उचाइ' : 'Altitude',
                        '${contextData.effectiveElevationMeters} m',
                        Icons.terrain_rounded,
                      ),
                    ),
                    Expanded(
                      child: _buildMetricTile(
                        _isNepali ? 'उम्लने बिन्दु' : 'Boiling Point',
                        '${contextData.effectiveBoilingPointCelsius.toStringAsFixed(1)}°C',
                        Icons.thermostat_rounded,
                      ),
                    ),
                    Expanded(
                      child: _buildMetricTile(
                        _isNepali ? 'ऋतु/सिजन' : 'Season',
                        contextData.activeSeasonName,
                        Icons.eco_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  key: const Key('btn_switch_primary_region'),
                  icon: const Icon(Icons.swap_horiz_rounded),
                  label: Text(_isNepali ? 'मुख्य क्षेत्र परिवर्तन गर्नुहोस्' : 'Switch Primary Region'),
                  onPressed: () => _showSwitchPrimaryModal(installedPacks),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: SitiColors.terracotta,
                    side: const BorderSide(color: SitiColors.terracotta),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Diaspora Mode Section
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.flight_takeoff_rounded, color: SitiColors.terracotta),
                    const SizedBox(width: 8),
                    Text(
                      _isNepali ? 'डायस्पोरा मोड (Diaspora Mode)' : 'Diaspora Mode',
                      style: NepaliTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: SitiColors.dark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _isNepali
                      ? 'विदेशमा बस्नुहुन्छ? स्थानीय मौसमअनुसार आफ्नो मातृभूमिको स्वाद र चाडपर्वका परिकार सँगै पकाउनुहोस्।'
                      : 'Living abroad? Layer heritage home recipes and festivals into your local seasonal kitchen.',
                  style: NepaliTypography.bodyMedium.copyWith(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 14),
                Text(
                  _isNepali ? 'मातृभूमि/अन्य सक्रिय प्याकहरू:' : 'Layered Secondary Packs:',
                  style: NepaliTypography.labelLarge.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                if (secondaries.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Text(
                      _isNepali
                          ? 'कुनै दोस्रो प्याक थपिएको छैन। तलबाट थप्न सक्नुहुन्छ।'
                          : 'No secondary packs active. Add one from your installed packs below.',
                      style: NepaliTypography.bodyMedium.copyWith(color: Colors.grey.shade600),
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    children: secondaries.map((s) {
                      return Chip(
                        label: Text(s.manifest.name),
                        backgroundColor: SitiColors.terracotta.withValues(alpha: 0.1),
                        deleteIcon: const Icon(Icons.close, size: 18),
                        onDeleted: () {
                          setState(() {
                            _repo.removeSecondaryPack(s.manifest.id);
                          });
                        },
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  key: const Key('btn_add_diaspora_pack'),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(_isNepali ? 'दोस्रो प्याक जोड्नुहोस्' : 'Add Secondary Pack'),
                  onPressed: () => _showAddSecondaryModal(installedPacks),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Household Overrides Section
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.home_work_rounded, color: SitiColors.terracotta),
                    const SizedBox(width: 8),
                    Text(
                      _isNepali ? 'घरपरिवार अनुकूलन (Household Overrides)' : 'Household Overrides',
                      style: NepaliTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: SitiColors.dark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _isNepali
                      ? 'तपाईंको घरको वास्तविक उचाइ र बजारका एकाइहरू प्याक परिवर्तन नभई सुरक्षित रहन्छन्।'
                      : 'Custom altitude or preferred units apply without modifying underlying pack files.',
                  style: NepaliTypography.bodyMedium.copyWith(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.tune_rounded, color: SitiColors.terracotta),
                  title: Text(_isNepali ? 'उचाइ अनुकूलन (Altitude Override)' : 'Altitude Override'),
                  subtitle: Text(
                    _repo.householdOverride?.elevationMeters != null
                        ? '${_repo.householdOverride!.elevationMeters} m'
                        : (_isNepali ? 'पूर्वनिर्धारित (${primary.manifest.elevationMeters}m)' : 'Default (${primary.manifest.elevationMeters}m)'),
                  ),
                  trailing: IconButton(
                    key: const Key('btn_edit_altitude_override'),
                    icon: const Icon(Icons.edit_rounded),
                    onPressed: _showElevationOverrideDialog,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- Tab 2: Region Pack Store / Catalog ---
  Widget _buildPackStoreTab() {
    final catalog = _repo.catalog;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: catalog.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _isNepali ? 'उपलब्ध क्षेत्र प्याकहरू' : 'Available Region Packs',
                    style: NepaliTypography.titleLarge.copyWith(
                      fontWeight: FontWeight.w700,
                      color: SitiColors.dark,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  key: const Key('btn_add_custom_region_store'),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(_isNepali ? 'कस्टम क्षेत्र' : 'Custom'),
                  onPressed: _showCustomRegionDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SitiColors.terracotta,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        }

        final entry = catalog[index - 1];
        final isInstalled = entry.isInstalled;
        final isPrimary = _repo.activeConfig.primaryPackId == entry.id;

        return Card(
          key: Key('pack_card_${entry.id}'),
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _isNepali ? entry.nativeName : entry.name,
                                  style: NepaliTypography.titleMedium.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildStatusBadge(entry.status),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${entry.country} (${entry.countryCode}) • ${entry.elevationMeters}m • ${entry.seasonSystem}',
                            style: NepaliTypography.bodyMedium.copyWith(
                              color: Colors.grey.shade600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  entry.description,
                  style: NepaliTypography.bodyMedium.copyWith(color: Colors.grey.shade800),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  children: [
                    Chip(
                      label: Text('${entry.currencySymbol} ${entry.currencyCode}'),
                      visualDensity: VisualDensity.compact,
                    ),
                    Chip(
                      label: Text('${entry.recipeCount} recipes'),
                      visualDensity: VisualDensity.compact,
                    ),
                    Chip(
                      label: Text('${(entry.sizeBytes / 1024).round()} KB'),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (isInstalled && !entry.isBuiltIn && entry.status == 'custom')
                      TextButton.icon(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        label: Text(_isNepali ? 'हटाउनुहोस्' : 'Delete', style: const TextStyle(color: Colors.red)),
                        onPressed: () {
                          setState(() {
                            _repo.deleteCustomRegion(entry.id);
                          });
                        },
                      )
                    else if (isInstalled && !entry.isBuiltIn)
                      TextButton.icon(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                        label: Text(_isNepali ? 'अनइन्स्टल' : 'Uninstall', style: const TextStyle(color: Colors.red)),
                        onPressed: () {
                          setState(() {
                            _repo.uninstallPack(entry.id);
                          });
                        },
                      ),
                    const SizedBox(width: 8),
                    if (isInstalled)
                      ElevatedButton.icon(
                        key: Key('btn_installed_${entry.id}'),
                        icon: Icon(isPrimary ? Icons.check_circle : Icons.check, size: 18),
                        label: Text(isPrimary
                            ? (_isNepali ? 'सक्रिय मुख्य' : 'Active Primary')
                            : (_isNepali ? 'इन्स्टल भइसकेको' : 'Installed')),
                        onPressed: isPrimary
                            ? null
                            : () {
                                setState(() {
                                  _repo.setPrimaryPack(entry.id);
                                });
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isPrimary ? Colors.green : Colors.grey.shade700,
                          foregroundColor: Colors.white,
                        ),
                      )
                    else
                      ElevatedButton.icon(
                        key: Key('btn_install_${entry.id}'),
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: Text(_isNepali ? 'इन्स्टल गर्नुहोस्' : 'Install'),
                        onPressed: () async {
                          await _repo.installPack(entry.id);
                          setState(() {});
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(_isNepali
                                    ? '${entry.name} सफलतापूर्वक इन्स्टल भयो'
                                    : 'Successfully installed ${entry.name}'),
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: SitiColors.terracotta,
                          foregroundColor: Colors.white,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case 'verified':
        bg = Colors.green.shade50;
        fg = Colors.green.shade800;
        label = 'Verified';
        break;
      case 'community':
        bg = Colors.purple.shade50;
        fg = Colors.purple.shade800;
        label = 'Community';
        break;
      case 'custom':
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade800;
        label = 'Custom';
        break;
      default:
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade800;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: SitiColors.terracotta),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: NepaliTypography.labelSmall.copyWith(color: Colors.grey.shade600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: NepaliTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  // --- Modals & Dialogs ---

  void _showSwitchPrimaryModal(List<RegionPack> installedPacks) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isNepali ? 'मुख्य बसोबास क्षेत्र छान्नुहोस्' : 'Select Primary Residence',
                  style: NepaliTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...installedPacks.map((pack) {
                  final isCurrent = _repo.activeConfig.primaryPackId == pack.manifest.id;
                  return ListTile(
                    key: Key('option_primary_${pack.manifest.id}'),
                    leading: Icon(
                      isCurrent ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      color: isCurrent ? SitiColors.terracotta : Colors.grey,
                    ),
                    title: Text(pack.manifest.name),
                    subtitle: Text('${pack.manifest.country} • ${pack.manifest.elevationMeters}m'),
                    onTap: () {
                      setState(() {
                        _repo.setPrimaryPack(pack.manifest.id);
                      });
                      Navigator.pop(ctx);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddSecondaryModal(List<RegionPack> installedPacks) {
    final eligible = installedPacks.where((p) =>
        p.manifest.id != _repo.activeConfig.primaryPackId &&
        !_repo.activeConfig.secondaryPackIds.contains(p.manifest.id));

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isNepali ? 'दोस्रो प्याक थप्नुहोस् (मातृभूमि)' : 'Add Secondary / Heritage Pack',
                  style: NepaliTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (eligible.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      _isNepali
                          ? 'अन्य इन्स्टल गरिएका प्याक उपलब्ध छैनन्। पहिले स्टोरबाट इन्स्टल गर्नुहोस्।'
                          : 'No additional installed packs available. Install one from the Pack Store first.',
                      style: NepaliTypography.bodyMedium.copyWith(color: Colors.grey.shade600),
                    ),
                  )
                else
                  ...eligible.map((pack) {
                    return ListTile(
                      key: Key('option_secondary_${pack.manifest.id}'),
                      leading: const Icon(Icons.add_circle_outline, color: SitiColors.terracotta),
                      title: Text(pack.manifest.name),
                      subtitle: Text(pack.manifest.country),
                      onTap: () {
                        setState(() {
                          _repo.addSecondaryPack(pack.manifest.id);
                        });
                        Navigator.pop(ctx);
                      },
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showElevationOverrideDialog() {
    final controller = TextEditingController(
      text: _repo.householdOverride?.elevationMeters?.toString() ?? '',
    );

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(_isNepali ? 'उचाइ अनुकूलन' : 'Altitude Override'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _isNepali
                    ? 'तपाईंको घरको वास्तविक उचाइ मिटरमा प्रविष्ट गर्नुहोस्:'
                    : 'Enter your exact home altitude in meters:',
                style: NepaliTypography.bodyMedium,
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('input_altitude_override'),
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Elevation (meters)',
                  border: OutlineInputBorder(),
                  suffixText: 'm',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _repo.setHouseholdOverride(null);
                setState(() {});
                Navigator.pop(ctx);
              },
              child: Text(_isNepali ? 'पूर्वनिर्धारित' : 'Reset to Default'),
            ),
            ElevatedButton(
              key: const Key('btn_save_altitude_override'),
              onPressed: () {
                final val = int.tryParse(controller.text);
                if (val != null && val >= 0) {
                  final current = _repo.householdOverride ?? const HouseholdPackOverride();
                  _repo.setHouseholdOverride(current.copyWith(elevationMeters: val));
                  setState(() {});
                }
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: SitiColors.terracotta),
              child: Text(_isNepali ? 'बचत गर्नुहोस्' : 'Save'),
            ),
          ],
        );
      },
    );
  }

  void _showCustomRegionDialog() {
    final nameCtrl = TextEditingController();
    final countryCtrl = TextEditingController();
    final elevationCtrl = TextEditingController(text: '500');
    final unitsCtrl = TextEditingController(text: 'kg, g, bunch');
    String selectedSeasonSystem = 'four-seasons';
    String selectedClimateZone = 'temperate';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final parsedElevation = int.tryParse(elevationCtrl.text) ?? 0;
            final previewBoilingPoint =
                AltitudeCalculator.boilingPointCelsius(parsedElevation.toDouble());

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: Row(
                children: [
                  const Icon(Icons.add_location_alt, color: SitiColors.terracotta),
                  const SizedBox(width: 8),
                  Text(
                    _isNepali ? 'नयाँ क्षेत्र सिर्जना' : 'Author Custom Region',
                    style: NepaliTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      key: const Key('custom_region_name_field'),
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Region Name (e.g. Germany - Bavaria)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('custom_region_country_field'),
                      controller: countryCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Country (e.g. Germany)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('custom_region_elevation_field'),
                      controller: elevationCtrl,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Elevation / Altitude (meters)',
                        border: const OutlineInputBorder(),
                        helperText: 'Boiling Point Preview: ${previewBoilingPoint.toStringAsFixed(1)}°C',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: const Key('custom_region_season_dropdown'),
                      initialValue: selectedSeasonSystem,
                      decoration: const InputDecoration(
                        labelText: 'Season System',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'four-seasons', child: Text('4 Seasons (Northern)')),
                        DropdownMenuItem(value: 'four-seasons-southern', child: Text('4 Seasons (Southern)')),
                        DropdownMenuItem(value: 'six-ritus', child: Text('6 Ritus (South Asian)')),
                        DropdownMenuItem(value: 'wet-dry', child: Text('Wet / Dry (Tropical)')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedSeasonSystem = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: const Key('custom_region_climate_dropdown'),
                      initialValue: selectedClimateZone,
                      decoration: const InputDecoration(
                        labelText: 'Climate Zone',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'temperate', child: Text('Temperate')),
                        DropdownMenuItem(value: 'subtropical', child: Text('Subtropical')),
                        DropdownMenuItem(value: 'tropical', child: Text('Tropical')),
                        DropdownMenuItem(value: 'highland', child: Text('Highland / Mountain')),
                        DropdownMenuItem(value: 'arid', child: Text('Arid / Semi-arid')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedClimateZone = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('custom_region_units_field'),
                      controller: unitsCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Market Units (comma-separated)',
                        border: OutlineInputBorder(),
                        helperText: 'e.g. kg, g, cup, bunch',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(_isNepali ? 'रद्द गर्नुहोस्' : 'Cancel'),
                ),
                ElevatedButton(
                  key: const Key('btn_save_custom_region'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SitiColors.terracotta,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    final name = nameCtrl.text.trim();
                    final country = countryCtrl.text.trim();
                    final elev = int.tryParse(elevationCtrl.text) ?? 0;
                    final units = unitsCtrl.text
                        .split(',')
                        .map((u) => u.trim())
                        .where((u) => u.isNotEmpty)
                        .toList();

                    if (name.isEmpty || country.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please fill region name and country')),
                      );
                      return;
                    }

                    final id = 'custom-${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '-')}';

                    final customInput = CustomRegionInput(
                      id: id,
                      name: name,
                      nativeName: name,
                      country: country,
                      countryCode: country.length >= 2 ? country.substring(0, 2).toUpperCase() : 'XX',
                      elevationMeters: elev,
                      climateZone: selectedClimateZone,
                      seasonSystem: selectedSeasonSystem,
                      marketUnits: units.isNotEmpty ? units : ['kg', 'g'],
                    );

                    final pack = _repo.createCustomRegion(customInput);
                    _repo.setPrimaryPack(pack.manifest.id);
                    setState(() {});
                    Navigator.pop(ctx);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Custom region "$name" created and set as active!'),
                      ),
                    );
                  },
                  child: Text(_isNepali ? 'थप्नुहोस्' : 'Create Region'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
