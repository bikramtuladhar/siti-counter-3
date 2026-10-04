import 'package:flutter/material.dart';
import 'package:kitchen_engine/nepali_calendar.dart';
import '../theme/nepali_typography.dart';
import '../theme/tokens.dart';
import 'market_price_service.dart';

/// Screen displaying the Kalimati Wholesale Market Price Board and Crowdsourced Local Market Rates.
/// Highlights "Budget Hero" seasonal produce with falling prices.
class MarketPriceBoardScreen extends StatefulWidget {
  final MarketPriceService marketPriceService;
  final String currentLanguage;
  final void Function(MarketCommodity commodity)? onSelectCommodity;

  const MarketPriceBoardScreen({
    super.key,
    required this.marketPriceService,
    this.currentLanguage = 'ne',
    this.onSelectCommodity,
  });

  @override
  State<MarketPriceBoardScreen> createState() => _MarketPriceBoardScreenState();
}

class _MarketPriceBoardScreenState extends State<MarketPriceBoardScreen> {
  late String _selectedCategory;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  bool get _isNepali => widget.currentLanguage == 'ne';
  MarketPriceService get _service => widget.marketPriceService;

  @override
  void initState() {
    super.initState();
    _selectedCategory = 'all';
    _service.addListener(_onServiceChanged);
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  void _openCrowdsourceDialog([MarketCommodity? preselected]) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CrowdsourcePriceSheet(
        marketPriceService: _service,
        preselected: preselected,
        isNepali: _isNepali,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _service.filterCommodities(
      category: _selectedCategory,
      search: _searchQuery,
    );
    final budgetHeroes = _service.getBudgetHeroes();

    return Scaffold(
      backgroundColor: SitiColors.warmWhite,
      appBar: AppBar(
        title: Text(
          _isNepali ? 'कालिमाटी दैनिक बजार भाउ' : 'Kalimati Market Price Board',
          style: NepaliTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w800,
            color: SitiColors.dark,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          IconButton(
            key: const Key('report_price_appbar_btn'),
            icon: const Icon(Icons.add_location_alt_outlined, color: SitiColors.terracotta),
            tooltip: _isNepali ? 'स्थानीय भाउ रिपोर्ट गर्नुहोस्' : 'Report local price',
            onPressed: () => _openCrowdsourceDialog(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('report_price_fab'),
        backgroundColor: SitiColors.terracotta,
        icon: const Icon(Icons.add_shopping_cart, color: Colors.white),
        label: Text(
          _isNepali ? 'भाउ रिपोर्ट' : 'Report Rate',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        onPressed: () => _openCrowdsourceDialog(),
      ),
      body: CustomScrollView(
        slivers: [
          // Sub-header with date & info
          SliverToBoxAdapter(
            child: _buildHeaderBanner(),
          ),

          // Budget Hero horizontal slider
          if (budgetHeroes.isNotEmpty && _searchQuery.isEmpty && _selectedCategory == 'all') ...[
            SliverToBoxAdapter(
              child: _buildBudgetHeroSection(budgetHeroes),
            ),
          ],

          // Search and Category Filter chips
          SliverToBoxAdapter(
            child: _buildSearchAndFilters(),
          ),

          // Commodity list
          if (filtered.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        _isNepali
                            ? 'कुनै तरकारी वा सामग्री भेटिएन'
                            : 'No commodities found matching criteria',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = filtered[index];
                    return _buildCommodityCard(item);
                  },
                  childCount: filtered.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeaderBanner() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: SitiColors.terracotta.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.storefront_rounded, color: SitiColors.terracotta, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isNepali
                      ? 'कालिमाटी फलफूल तथा तरकारी विकास समिति'
                      : 'KFVMDB Daily Wholesale Rate Board',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  _isNepali
                      ? 'मिति: २०८३-०६-१८ • दैनिक थोक दर'
                      : 'Date: ${_service.lastUpdated} • Daily Wholesale',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: SitiColors.freshGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_rounded, color: SitiColors.freshGreen, size: 14),
                const SizedBox(width: 4),
                Text(
                  _isNepali ? 'प्रमाणित' : 'Verified',
                  style: const TextStyle(
                    color: SitiColors.freshGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetHeroSection(List<MarketCommodity> heroes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Icon(Icons.stars_rounded, color: Colors.amber, size: 20),
              const SizedBox(width: 6),
              Text(
                _isNepali ? 'बजेट हिरो (सस्तो र घट्दो भाउ)' : 'Budget Heroes (Falling Prices)',
                style: NepaliTypography.titleSmall.copyWith(
                  fontWeight: FontWeight.w800,
                  color: SitiColors.dark,
                ),
              ),
              const Spacer(),
              Text(
                _isNepali ? '${NepaliCalendar.toDevanagariDigits(heroes.length)} वस्तु' : '${heroes.length} items',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 130,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            itemCount: heroes.length,
            itemBuilder: (context, index) {
              final hero = heroes[index];
              return _buildHeroCard(hero);
            },
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildHeroCard(MarketCommodity hero) {
    return InkWell(
      key: Key('budget_hero_${hero.commodityId}'),
      onTap: () => widget.onSelectCommodity?.call(hero),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 145,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _isNepali ? hero.nameNe : hero.nameEn,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.green.shade700,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_downward_rounded, color: Colors.white, size: 12),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _isNepali ? hero.nameEn : hero.nameNe,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
            ),
            const Spacer(),
            Text(
              _isNepali
                  ? 'औसत: रु ${NepaliCalendar.toDevanagariDigits(hero.avgPrice)} / केजी'
                  : 'Avg: NPR ${hero.avgPrice} / kg',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: Colors.green.shade900,
              ),
            ),
            Text(
              _isNepali ? 'किन्न उपयुक्त 🟢' : 'Great Buy 🟢',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    final categories = [
      {'id': 'all', 'labelNe': 'सबै', 'labelEn': 'All', 'icon': '🧺'},
      {'id': 'vegetables', 'labelNe': 'तरकारी', 'labelEn': 'Vegetables', 'icon': '🥔'},
      {'id': 'greens', 'labelNe': 'सागपात', 'labelEn': 'Greens', 'icon': '🥬'},
      {'id': 'spices', 'labelNe': 'मसला', 'labelEn': 'Spices', 'icon': '🧄'},
      {'id': 'fruits', 'labelNe': 'फलफूल', 'labelEn': 'Fruits', 'icon': '🍎'},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // Search TextField
          TextField(
            key: const Key('market_search_input'),
            controller: _searchController,
            decoration: InputDecoration(
              hintText: _isNepali
                  ? 'तरकारीको नाम खोज्नुहोस् (उदा. आलु, काउली)...'
                  : 'Search commodity (e.g. potato, cauliflower)...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
          const SizedBox(height: 10),

          // Categories horizontal scroll
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: categories.map((cat) {
                final isSelected = _selectedCategory == cat['id'];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    key: Key('cat_chip_${cat['id']}'),
                    selected: isSelected,
                    showCheckmark: false,
                    avatar: Text(cat['icon'] as String),
                    label: Text(
                      _isNepali ? cat['labelNe'] as String : cat['labelEn'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.white : SitiColors.dark,
                      ),
                    ),
                    selectedColor: SitiColors.terracotta,
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected ? SitiColors.terracotta : Colors.grey.shade300,
                      ),
                    ),
                    onSelected: (_) => setState(() => _selectedCategory = cat['id'] as String),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommodityCard(MarketCommodity item) {
    Color trendColor;
    IconData trendIcon;
    String trendTextNe;
    String trendTextEn;

    switch (item.priceTrend) {
      case 'falling':
        trendColor = SitiColors.freshGreen;
        trendIcon = Icons.arrow_downward_rounded;
        trendTextNe = 'घट्दो';
        trendTextEn = 'Falling';
        break;
      case 'rising':
        trendColor = SitiColors.alert;
        trendIcon = Icons.arrow_upward_rounded;
        trendTextNe = 'बढ्दो';
        trendTextEn = 'Rising';
        break;
      default:
        trendColor = SitiColors.warning;
        trendIcon = Icons.remove_rounded;
        trendTextNe = 'स्थिर';
        trendTextEn = 'Stable';
    }

    return Container(
      key: Key('commodity_card_${item.commodityId}'),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: item.isBudgetHero ? Colors.green.shade300 : Colors.grey.shade200,
          width: item.isBudgetHero ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          onTap: () => widget.onSelectCommodity?.call(item),
        title: Row(
          children: [
            Expanded(
              child: Text(
                _isNepali ? item.nameNe : item.nameEn,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ),
            if (item.isBudgetHero)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _isNepali ? 'बजेट हिरो ⭐' : 'Budget Hero ⭐',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade900,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              _isNepali ? item.nameEn : item.nameNe,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                // Price Range
                Text(
                  _isNepali
                      ? 'थोक: रु ${NepaliCalendar.toDevanagariDigits(item.minPrice)} - ${NepaliCalendar.toDevanagariDigits(item.maxPrice)} / केजी'
                      : 'Wholesale: NPR ${item.minPrice} - ${item.maxPrice} / kg',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                ),
                const SizedBox(width: 8),
                // Trend badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: trendColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(trendIcon, size: 12, color: trendColor),
                      const SizedBox(width: 2),
                      Text(
                        _isNepali ? trendTextNe : trendTextEn,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: trendColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _isNepali
                  ? 'रु ${NepaliCalendar.toDevanagariDigits(item.avgPrice)}'
                  : 'NPR ${item.avgPrice}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: item.isBudgetHero ? Colors.green.shade800 : SitiColors.dark,
              ),
            ),
            Text(
              _isNepali ? 'औसत दर / केजी' : 'Avg / kg',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    ),
  );
  }
}

/// Modal sheet allowing household shoppers to report real-world prices from their local Haat Bazaar
class _CrowdsourcePriceSheet extends StatefulWidget {
  final MarketPriceService marketPriceService;
  final MarketCommodity? preselected;
  final bool isNepali;

  const _CrowdsourcePriceSheet({
    required this.marketPriceService,
    this.preselected,
    required this.isNepali,
  });

  @override
  State<_CrowdsourcePriceSheet> createState() => _CrowdsourcePriceSheetState();
}

class _CrowdsourcePriceSheetState extends State<_CrowdsourcePriceSheet> {
  late String _selectedCommodityId;
  final TextEditingController _marketController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  final List<String> _commonMarkets = [
    'कालिमाटी तरकारी बजार (Kalimati)',
    'बल्खु तरकारी बजार (Balkhu)',
    'लगनखेल हाटबजार (Lagankhel)',
    'आसन तरकारी बजार (Asan)',
    'स्थानीय किराना / पसल (Local Kirana)',
  ];

  @override
  void initState() {
    super.initState();
    final commodities = widget.marketPriceService.commodities;
    _selectedCommodityId = widget.preselected?.commodityId ??
        (commodities.isNotEmpty ? commodities.first.commodityId : 'potato');
    _marketController.text = _commonMarkets.first;
  }

  @override
  void dispose() {
    _marketController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _submit() {
    final priceStr = _priceController.text.trim();
    final price = int.tryParse(priceStr);
    if (price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isNepali
                ? 'कृपया मान्य मूल्य प्रविष्ट गर्नुहोस्'
                : 'Please enter a valid price',
          ),
          backgroundColor: SitiColors.alert,
        ),
      );
      return;
    }

    widget.marketPriceService.recordCrowdsourcedPrice(
      marketName: _marketController.text.trim(),
      commodityId: _selectedCommodityId,
      observedPrice: price,
    );

    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.isNepali
              ? 'बजार भाउ सफलतापूर्वक रिपोर्ट भयो। धन्यवाद!'
              : 'Market rate successfully recorded. Thank you!',
        ),
        backgroundColor: SitiColors.freshGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final commodities = widget.marketPriceService.commodities;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.rate_review_rounded, color: SitiColors.terracotta),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.isNepali ? 'स्थानीय बजार भाउ रिपोर्ट' : 'Report Local Market Price',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Select Commodity
          DropdownButtonFormField<String>(
            key: const Key('crowdsource_commodity_dropdown'),
            value: _selectedCommodityId,
            decoration: InputDecoration(
              labelText: widget.isNepali ? 'तरकारी / सामग्री' : 'Commodity',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: commodities.map((c) {
              return DropdownMenuItem<String>(
                value: c.commodityId,
                child: Text(widget.isNepali ? '${c.nameNe} (${c.nameEn})' : '${c.nameEn} (${c.nameNe})'),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedCommodityId = val);
            },
          ),
          const SizedBox(height: 12),

          // Market Name
          TextFormField(
            key: const Key('crowdsource_market_input'),
            controller: _marketController,
            decoration: InputDecoration(
              labelText: widget.isNepali ? 'बजार / पसलको नाम' : 'Market / Store Name',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),

          // Observed Price per kg
          TextFormField(
            key: const Key('crowdsource_price_input'),
            controller: _priceController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: widget.isNepali ? 'देखेको दर (रु प्रति केजी)' : 'Observed Rate (NPR per kg)',
              prefixText: 'रु ',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 20),

          // Submit Button
          ElevatedButton(
            key: const Key('crowdsource_submit_btn'),
            style: ElevatedButton.styleFrom(
              backgroundColor: SitiColors.terracotta,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _submit,
            child: Text(
              widget.isNepali ? 'भाउ दर्ता गर्नुहोस्' : 'Submit Market Rate',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}
