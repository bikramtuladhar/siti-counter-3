import 'package:flutter/foundation.dart';
import 'package:kitchen_engine/kitchen_engine.dart';

/// Representation of a wholesale produce price observation from Kalimati or local markets
class MarketCommodity {
  final String id;
  final String commodityId;
  final String nameEn;
  final String nameNe;
  final String category;
  final String unit;
  final int minPrice;
  final int maxPrice;
  final int avgPrice;
  final String priceTrend; // 'rising', 'stable', 'falling'
  final String date;
  final String? nepaliDate;

  const MarketCommodity({
    required this.id,
    required this.commodityId,
    required this.nameEn,
    required this.nameNe,
    required this.category,
    required this.unit,
    required this.minPrice,
    required this.maxPrice,
    required this.avgPrice,
    this.priceTrend = 'stable',
    required this.date,
    this.nepaliDate,
  });

  bool get isBudgetHero => priceTrend == 'falling' || avgPrice < 50;

  factory MarketCommodity.fromJson(Map<String, dynamic> json) {
    return MarketCommodity(
      id: json['id'] as String? ?? 'com_${json['commodityId']}',
      commodityId: json['commodityId'] as String,
      nameEn: json['commodityNameEn'] as String? ?? json['nameEn'] as String? ?? '',
      nameNe: json['commodityNameNe'] as String? ?? json['nameNe'] as String? ?? '',
      category: json['category'] as String? ?? 'vegetables',
      unit: json['unit'] as String? ?? 'kg',
      minPrice: (json['minPrice'] as num).toInt(),
      maxPrice: (json['maxPrice'] as num).toInt(),
      avgPrice: (json['avgPrice'] as num).toInt(),
      priceTrend: json['priceTrend'] as String? ?? 'stable',
      date: json['date'] as String? ?? DateTime.now().toIso8601String().split('T')[0],
      nepaliDate: json['nepaliDate'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'commodityId': commodityId,
    'commodityNameEn': nameEn,
    'commodityNameNe': nameNe,
    'category': category,
    'unit': unit,
    'minPrice': minPrice,
    'maxPrice': maxPrice,
    'avgPrice': avgPrice,
    'priceTrend': priceTrend,
    'date': date,
    'nepaliDate': nepaliDate,
  };
}

/// Service managing daily Kalimati wholesale produce prices and crowdsourced price boards
class MarketPriceService extends ChangeNotifier {
  final List<MarketCommodity> _commodities = [];
  bool _isLoading = false;
  String _lastUpdated = '';

  MarketPriceService({List<MarketCommodity>? initialCommodities}) {
    if (initialCommodities != null && initialCommodities.isNotEmpty) {
      _commodities.addAll(initialCommodities);
      _lastUpdated = _commodities.first.date;
    } else {
      _loadDefaultSeedPrices();
    }
  }

  List<MarketCommodity> get commodities => List.unmodifiable(_commodities);
  bool get isLoading => _isLoading;
  String get lastUpdated => _lastUpdated;

  void _loadDefaultSeedPrices() {
    final today = DateTime.now().toIso8601String().split('T')[0];
    _lastUpdated = today;
    _commodities.clear();
    _commodities.addAll([
      MarketCommodity(
        id: 'kalimati_potato_red',
        commodityId: 'potato',
        nameEn: 'Potato Red',
        nameNe: 'आलु रातो',
        category: 'vegetables',
        unit: 'kg',
        minPrice: 55,
        maxPrice: 65,
        avgPrice: 60,
        priceTrend: 'stable',
        date: today,
        nepaliDate: '२०८३-०६-१८',
      ),
      MarketCommodity(
        id: 'kalimati_tomato_local',
        commodityId: 'tomato',
        nameEn: 'Tomato Local',
        nameNe: 'गोलभेडा सानो(लोकल)',
        category: 'vegetables',
        unit: 'kg',
        minPrice: 40,
        maxPrice: 50,
        avgPrice: 45,
        priceTrend: 'falling', // Budget hero!
        date: today,
        nepaliDate: '२०८३-०६-१८',
      ),
      MarketCommodity(
        id: 'kalimati_onion_dry',
        commodityId: 'onion',
        nameEn: 'Onion Dry',
        nameNe: 'प्याज सुकेको',
        category: 'vegetables',
        unit: 'kg',
        minPrice: 78,
        maxPrice: 88,
        avgPrice: 83,
        priceTrend: 'rising',
        date: today,
        nepaliDate: '२०८३-०६-१८',
      ),
      MarketCommodity(
        id: 'kalimati_cauliflower',
        commodityId: 'cauliflower',
        nameEn: 'Cauliflower Local',
        nameNe: 'काउली स्थानीय',
        category: 'vegetables',
        unit: 'kg',
        minPrice: 45,
        maxPrice: 55,
        avgPrice: 50,
        priceTrend: 'falling', // Budget hero!
        date: today,
        nepaliDate: '२०८३-०६-१८',
      ),
      MarketCommodity(
        id: 'kalimati_cabbage',
        commodityId: 'cabbage',
        nameEn: 'Cabbage Local',
        nameNe: 'बन्दा(लोकल)',
        category: 'vegetables',
        unit: 'kg',
        minPrice: 35,
        maxPrice: 45,
        avgPrice: 40,
        priceTrend: 'stable',
        date: today,
        nepaliDate: '२०८३-०६-१८',
      ),
      MarketCommodity(
        id: 'kalimati_spinach',
        commodityId: 'spinach',
        nameEn: 'Spinach Greens',
        nameNe: 'पालुङ्गो साग',
        category: 'greens',
        unit: 'kg',
        minPrice: 80,
        maxPrice: 100,
        avgPrice: 90,
        priceTrend: 'stable',
        date: today,
        nepaliDate: '२०८३-०६-१८',
      ),
      MarketCommodity(
        id: 'kalimati_mustard_greens',
        commodityId: 'mustard_greens',
        nameEn: 'Mustard Greens',
        nameNe: 'रायो साग',
        category: 'greens',
        unit: 'kg',
        minPrice: 45,
        maxPrice: 55,
        avgPrice: 50,
        priceTrend: 'falling',
        date: today,
        nepaliDate: '२०८३-०६-१८',
      ),
      MarketCommodity(
        id: 'kalimati_ginger',
        commodityId: 'ginger',
        nameEn: 'Ginger',
        nameNe: 'अदुवा',
        category: 'spices',
        unit: 'kg',
        minPrice: 160,
        maxPrice: 190,
        avgPrice: 175,
        priceTrend: 'stable',
        date: today,
        nepaliDate: '२०८३-०६-१८',
      ),
      MarketCommodity(
        id: 'kalimati_garlic',
        commodityId: 'garlic',
        nameEn: 'Garlic Dry',
        nameNe: 'लसुन सुकेको',
        category: 'spices',
        unit: 'kg',
        minPrice: 240,
        maxPrice: 270,
        avgPrice: 255,
        priceTrend: 'rising',
        date: today,
        nepaliDate: '२०८३-०६-१८',
      ),
      MarketCommodity(
        id: 'kalimati_cilantro',
        commodityId: 'cilantro',
        nameEn: 'Coriander Green',
        nameNe: 'धनिया हरियो',
        category: 'greens',
        unit: 'kg',
        minPrice: 100,
        maxPrice: 130,
        avgPrice: 115,
        priceTrend: 'stable',
        date: today,
        nepaliDate: '२०८३-०६-१८',
      ),
    ]);
  }

  /// Filters commodities by category and/or query string
  List<MarketCommodity> filterCommodities({String? category, String? search}) {
    var result = List<MarketCommodity>.from(_commodities);
    if (category != null && category.isNotEmpty && category != 'all') {
      result = result.where((c) => c.category == category.toLowerCase()).toList();
    }
    if (search != null && search.trim().isNotEmpty) {
      final q = search.trim().toLowerCase();
      result = result.where((c) {
        return c.nameEn.toLowerCase().contains(q) ||
            c.nameNe.contains(q) ||
            c.commodityId.contains(q);
      }).toList();
    }
    return result;
  }

  /// Returns list of budget hero commodities (falling prices or low price)
  List<MarketCommodity> getBudgetHeroes() {
    return _commodities.where((c) => c.isBudgetHero).toList();
  }

  /// Converts prices to engine mapping for grocery list calculations
  Map<String, CommodityMarketPriceInfo> toEnginePricesMap() {
    return {
      for (final c in _commodities)
        c.commodityId: CommodityMarketPriceInfo(
          avgPrice: c.avgPrice,
          priceTrend: c.priceTrend,
        ),
    };
  }

  /// Records crowdsourced price observation from local haat bazaar or store
  void recordCrowdsourcedPrice({
    required String marketName,
    required String commodityId,
    required int observedPrice,
    String unit = 'kg',
  }) {
    // Updates internal observation and notifies listeners
    final idx = _commodities.indexWhere((c) => c.commodityId == commodityId);
    if (idx != -1) {
      final existing = _commodities[idx];
      final newTrend = observedPrice < existing.avgPrice
          ? 'falling'
          : observedPrice > existing.avgPrice
              ? 'rising'
              : 'stable';
      _commodities[idx] = MarketCommodity(
        id: existing.id,
        commodityId: existing.commodityId,
        nameEn: existing.nameEn,
        nameNe: existing.nameNe,
        category: existing.category,
        unit: existing.unit,
        minPrice: observedPrice < existing.minPrice ? observedPrice : existing.minPrice,
        maxPrice: observedPrice > existing.maxPrice ? observedPrice : existing.maxPrice,
        avgPrice: ((existing.avgPrice + observedPrice) / 2).round(),
        priceTrend: newTrend,
        date: existing.date,
        nepaliDate: existing.nepaliDate,
      );
      notifyListeners();
    }
  }
}
