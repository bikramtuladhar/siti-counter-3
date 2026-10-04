class OnboardingPreferences {
  String regionPackId;
  String language;
  String stoveType;
  int adultsCount;
  int childrenCount;
  int eldersCount;
  List<String> dietaryRules;
  bool isGuest;
  double elevationMeters;

  OnboardingPreferences({
    this.regionPackId = 'nepal-bagmati',
    this.language = 'ne',
    this.stoveType = 'lpg_gas',
    this.adultsCount = 2,
    this.childrenCount = 1,
    this.eldersCount = 0,
    List<String>? dietaryRules,
    this.isGuest = true,
    this.elevationMeters = 1400.0,
  }) : dietaryRules = dietaryRules ?? [];

  int get totalHouseholdSize => adultsCount + childrenCount + eldersCount;
}
