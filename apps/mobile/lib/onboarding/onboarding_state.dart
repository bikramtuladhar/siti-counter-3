class OnboardingPreferences {
  String regionPackId;
  String language;
  String stoveType;
  int adultsCount;
  int childrenCount;
  int eldersCount;
  List<String> dietaryRules;
  bool isGuest;

  OnboardingPreferences({
    this.regionPackId = 'nepal-bagmati',
    this.language = 'ne',
    this.stoveType = 'lpg_gas',
    this.adultsCount = 2,
    this.childrenCount = 1,
    this.eldersCount = 0,
    List<String>? dietaryRules,
    this.isGuest = true,
  }) : dietaryRules = dietaryRules ?? [];

  int get totalHouseholdSize => adultsCount + childrenCount + eldersCount;
}
