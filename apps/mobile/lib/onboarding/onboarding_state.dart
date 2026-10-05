class OnboardingPreferences {
  String regionPackId;
  String language;
  List<String> stoveTypes;
  int adultsCount;
  int childrenCount;
  int eldersCount;
  List<String> dietaryRules;
  bool isGuest;
  double elevationMeters;

  OnboardingPreferences({
    this.regionPackId = 'nepal-bagmati',
    this.language = 'ne',
    List<String>? stoveTypes,
    this.adultsCount = 2,
    this.childrenCount = 1,
    this.eldersCount = 0,
    List<String>? dietaryRules,
    this.isGuest = true,
    this.elevationMeters = 1400.0,
  }) : stoveTypes = stoveTypes ?? ['lpg_gas'],
       dietaryRules = dietaryRules ?? [];

  int get totalHouseholdSize => adultsCount + childrenCount + eldersCount;

  bool get isNepali => language == 'ne';

  /// The stove the whistle model calibrates against.
  ///
  /// Most kitchens cook on more than one (a gas hob plus a firewood chulha on the terrace,
  /// say), so this picks the first selected stove rather than pretending there is only one.
  /// Falls back to LPG, the most common Nepali default, when nothing is selected.
  String get primaryStoveType => stoveTypes.isNotEmpty ? stoveTypes.first : 'lpg_gas';

  void toggleStoveType(String id) {
    if (stoveTypes.contains(id)) {
      stoveTypes.remove(id);
    } else {
      stoveTypes.add(id);
    }
  }
}