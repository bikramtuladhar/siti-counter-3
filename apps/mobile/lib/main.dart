import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kitchen_engine/kitchen_engine.dart';
import 'package:kitchen_engine/nepali_calendar.dart';
import 'consumption/consumption_dashboard_screen.dart';
import 'consumption/consumption_repository.dart';
import 'consumption/post_meal_usual_dialog.dart';
import 'onboarding/onboarding_coordinator.dart';
import 'onboarding/onboarding_state.dart';
import 'planner/planner_repository.dart';
import 'planner/weekly_planner_screen.dart';
import 'screens/active_cooking_session_screen.dart';
import 'screens/seasonal_kitchen_screen.dart';
import 'ai/ai_assistant_screen.dart';
import 'ai/ai_assistant_service.dart';
import 'displays/companion_widget_service.dart';
import 'displays/home_screen_widget_previews.dart';
import 'displays/watch_companion_preview_sheet.dart';
import 'displays/display_feed_cache.dart';
import 'sync/api_session.dart';
import 'sync/app_sync_coordinator.dart';
import 'sync/sync_engine.dart';
import 'settings/household_profile_publisher.dart';
import 'settings/household_profile_screen.dart';
import 'settings/social_auth_service.dart';
import 'settings/settings_service.dart';
import 'settings/setup_progress.dart';
import 'sync/sync_repository.dart';
import 'theme/tokens.dart';
import 'theme/nepali_typography.dart';
import 'theme/scroll_behavior.dart';
import 'widgets/six_ritus_indicator.dart';

void main() {
  runApp(const SitiCounterApp());
}

class SitiCounterApp extends StatefulWidget {
  const SitiCounterApp({super.key});

  @override
  State<SitiCounterApp> createState() => _SitiCounterAppState();
}

class _SitiCounterAppState extends State<SitiCounterApp> {
  OnboardingPreferences? _userPreferences;
  SettingsService? _settings;

  /// Social sign-in, built lazily once the sync database (and therefore the guest
  /// household id) is available. Null while that is still loading, which hides the entry
  /// point rather than failing when tapped.
  SocialSignInService? _socialSignInService;

  /// Loads the stored household profile on launch.
  ///
  /// Onboarding used to be the only source of these answers and it lived in a field, so
  /// every relaunch started from scratch. Now a returning user goes straight to the kitchen
  /// and picks up the extended setup checklist.
  @override
  void initState() {
    super.initState();
    unawaited(_restore());
  }

  Future<void> _restore() async {
    try {
      final settings = await SettingsService.openOnDisk();
      final signIn = await _buildSignInService();

      if (!await settings.isOnboardingComplete) {
        if (mounted) setState(() => _socialSignInService = signIn);
        return;
      }

      final preferences = await settings.loadPreferences();
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _socialSignInService = signIn;
        _userPreferences = preferences;
      });
    } catch (_) {
      // Settings unavailable: fall back to running onboarding again.
    }
  }

  /// Builds the sign-in service over the sync database.
  ///
  /// Returns a service with no providers configured unless the platform SDKs are linked,
  /// so the UI reports social sign-in as unavailable rather than presenting buttons that
  /// cannot work. Wiring `google_sign_in` / `sign_in_with_apple` /
  /// `flutter_facebook_auth` is the remaining step; each registers itself here.
  Future<SocialSignInService> _buildSignInService() async {
    try {
      final repository = await SyncRepository.openOnDisk();
      final identity = SyncIdentityReader(repository);

      return SocialSignInService(
        apiBaseUrl: defaultApiBaseUrl(),
        deviceId: () async => await identity.deviceId,
        guestHouseholdId: () async => await identity.guestHouseholdId,
      );
    } catch (_) {
      return SocialSignInService(apiBaseUrl: defaultApiBaseUrl());
    }
  }

  /// Re-points the app at the signed-in account's household.
  ///
  /// The API already merged the guest household into the account, so the caches stay
  /// valid; only the marker for "this is a guest install" changes.
  Future<void> _onSignedIn(SocialSignInResult result) async {
    try {
      final settings = _settings ?? await SettingsService.openOnDisk();
      await settings.setOnboardingComplete(true);

      if (!mounted) return;
      setState(() {
        if (_userPreferences != null) {
          _userPreferences!.isGuest = false;
        }
      });
    } catch (_) {
      // Sign-in already succeeded server-side; a local flag failure is not worth blocking.
    }
  }

  Future<void> _persistOnboarding(OnboardingPreferences prefs) async {
    try {
      final settings = _settings ?? await SettingsService.openOnDisk();
      await settings.saveOnboardingPreferences(prefs);
      if (mounted) {
        setState(() => _settings = settings);
      }
    } catch (_) {
      // Storage unavailable: the app runs from memory and re-asks next launch.
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Siti Counter 3.0',
      debugShowCheckedModeBanner: false,
      // Removes the elastic overscroll stretch/glow; see NoElasticScrollBehavior.
      scrollBehavior: const NoElasticScrollBehavior(),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: SitiColors.terracotta,
          primary: SitiColors.terracotta,
          surface: SitiColors.warmWhite,
        ),
        textTheme: NepaliTypography.createTextTheme(SitiColors.dark),
      ),
      home: _userPreferences == null
          ? OnboardingCoordinator(
              onComplete: (prefs) {
                // Enter the kitchen first, then persist. Persisting must never be able to
                // strand someone on the last onboarding screen: if storage is unavailable
                // the app still works, it just re-asks next launch.
                if (mounted) {
                  setState(() {
                    _userPreferences = prefs;
                  });
                }
                unawaited(_persistOnboarding(prefs));
              },
              signInService: _socialSignInService,
              onSignedIn: (result) => unawaited(_onSignedIn(result)),
            )
          : KitchenHomeScreen(
              settings: _settings,
              preferences: _userPreferences!,
              onResetOnboarding: () {
                setState(() {
                  _userPreferences = null;
                });
              },
            ),
    );
  }
}

class KitchenHomeScreen extends StatefulWidget {
  final OnboardingPreferences preferences;
  final VoidCallback onResetOnboarding;
  final WeeklyPlannerRepository? plannerRepository;
  final ConsumptionRepository? consumptionRepository;

  /// Stored household profile, used by the progressive setup checklist.
  final SettingsService? settings;

  /// Server-connected state (delta sync + glanceable display feed). Injected in tests;
  /// when null the screen bootstraps its own against the local sync database.
  final AppSyncCoordinator? syncCoordinator;

  /// Supplies the bearer token for household-scoped API calls.
  final AccessTokenProvider? accessTokenProvider;

  /// API origin. Overridable so a debug build can point at a local worker.
  final String apiBaseUrl;

  const KitchenHomeScreen({
    super.key,
    required this.preferences,
    required this.onResetOnboarding,
    this.plannerRepository,
    this.consumptionRepository,
    this.settings,
    this.syncCoordinator,
    this.accessTokenProvider,
    this.apiBaseUrl = kDefaultApiBaseUrl,
  });

  /// The API origin actually used at runtime.
  ///
  /// Resolves to the build-time override when set, otherwise per platform so the Android
  /// emulator reaches the host worker at 10.0.2.2 rather than its own loopback.
  String resolveApiBaseUrl(String configured) =>
      configured == kDefaultApiBaseUrl ? defaultApiBaseUrl() : configured;

  @override
  State<KitchenHomeScreen> createState() => _KitchenHomeScreenState();
}

class _KitchenHomeScreenState extends State<KitchenHomeScreen> {
  int _currentTabIndex = 0;
  int _whistleCount = 0;
  bool _isListening = false;
  WeeklyPlannerRepository? _plannerRepo;
  ConsumptionRepository? _consumptionRepo;

  AppSyncCoordinator? _syncCoordinator;
  bool _ownsSyncCoordinator = false;

  /// Standalone display service so the Widgets & Watch sheet is usable immediately,
  /// before (or without) a successful sync bootstrap. Replaced by the coordinator's
  /// service once it is ready.
  late CompanionWidgetService _displayService;
  bool _ownsPlaceholderDisplayService = false;

  bool get _isNepali => widget.preferences.language == 'ne';

  /// API origin in use, resolving the per-platform default when none was configured.
  String get _apiBaseUrl =>
      widget.resolveApiBaseUrl(widget.apiBaseUrl);

  @override
  void initState() {
    super.initState();
    _plannerRepo = widget.plannerRepository;
    _consumptionRepo = widget.consumptionRepository;

    // Placeholder so the Widgets & Watch sheet works before sync finishes bootstrapping.
    if (widget.syncCoordinator == null) {
      _displayService = CompanionWidgetService(apiBaseUrl: _apiBaseUrl);
      _ownsPlaceholderDisplayService = true;
    }

    _syncCoordinator = widget.syncCoordinator;
    if (_syncCoordinator != null) {
      _displayService = _syncCoordinator!.displayService;
      unawaited(_syncCoordinator!.start());
    } else {
      unawaited(_bootstrapSyncCoordinator());
    }
  }

  /// Builds the coordinator against the local sync database and starts cache-first sync.
  ///
  /// Failures are swallowed: the app must start and work offline with whatever the local
  /// planner and consumption databases already hold.
  Future<void> _bootstrapSyncCoordinator() async {
    try {
      final repository = await SyncRepository.openOnDisk();

      // Authenticate first: the sync and feed endpoints authorize from the bearer token,
      // and the household the token is scoped to is the one we must sync against.
      final session = ApiSession(repository: repository, apiBaseUrl: _apiBaseUrl);
      if (widget.accessTokenProvider == null) {
        await session.restore();
      }

      final householdId =
          session.householdId ?? await _fallbackHouseholdId(repository);
      final tokenProvider =
          widget.accessTokenProvider ?? session.accessTokenProvider;

      final coordinator = AppSyncCoordinator(
        repository: repository,
        syncEngine: SyncEngine(
          repository: repository,
          householdId: householdId,
          apiBaseUrl: _apiBaseUrl,
          accessTokenProvider: tokenProvider,
        ),
        displayService: CompanionWidgetService(
          cache: SqliteDisplayFeedCache(
            repository: repository,
            householdId: householdId,
          ),
          apiBaseUrl: _apiBaseUrl,
        )..accessTokenProvider = tokenProvider,
        accessTokenProvider: tokenProvider,
      );

      if (!mounted) {
        coordinator.dispose();
        return;
      }
      _ownsPlaceholderDisplayService = false;
      _displayService = coordinator.displayService;
      setState(() {
        _syncCoordinator = coordinator;
        _ownsSyncCoordinator = true;
      });
      await coordinator.start();
    } catch (_) {
      // Storage unavailable: the app continues without server sync.
    }
  }

  /// Last-resort household id when auth could not run (offline first launch).
  ///
  /// A stable id is generated once and persisted, so repeat launches reuse the same cache.
  /// It will not match a server-side household, so syncing stays a no-op until auth succeeds.
  Future<String> _fallbackHouseholdId(SyncRepository repository) async {
    const stateKey = 'local_household_id';
    final stored = await repository.getSyncState(stateKey);
    if (stored != null && stored.isNotEmpty) return stored;

    final generated =
        'hh_local_${UuidV7.generate().replaceAll('-', '').substring(0, 16)}';
    await repository.setSyncState(stateKey, generated);
    return generated;
  }

  @override
  void dispose() {
    if (_ownsSyncCoordinator) {
      _syncCoordinator?.dispose();
    }
    if (_ownsPlaceholderDisplayService) {
      _displayService.dispose();
    }
    super.dispose();
  }

  void _openHouseholdSetup() {
    final settings = widget.settings;
    if (settings == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HouseholdProfileScreen(
          settings: settings,
          consumptionRepository: _consumptionRepo,
          onChanged: () => setState(() {}),
        ),
      ),
    );
  }

  /// Compact entry point to the extended household setup.
  ///
  /// Hidden entirely once everything is configured, so a finished household never sees it
  /// again. Completion is read from real data by the profile screen, not tracked here.
  Widget _buildSetupChecklist() {
    final settings = widget.settings;
    if (settings == null) return const SizedBox.shrink();

    return FutureBuilder<SetupProgress>(
      future: _loadSetupProgress(),
      builder: (context, snapshot) {
        final progress = snapshot.data;
        if (progress == null || progress.isComplete) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Material(
            color: SitiColors.terracotta.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              key: const Key('setup_checklist_card'),
              onTap: _openHouseholdSetup,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.checklist_rtl_rounded,
                          color: SitiColors.terracotta,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _isNepali
                                ? 'भान्सा सेटअप पूरा गर्नुहोस्'
                                : 'Finish setting up your kitchen',
                            style: NepaliTypography.titleSmall.copyWith(
                              fontWeight: FontWeight.w700,
                              color: SitiColors.dark,
                            ),
                          ),
                        ),
                        Text(
                          '${progress.completed}/${progress.total}',
                          style: NepaliTypography.labelLarge.copyWith(
                            color: SitiColors.terracotta,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress.fraction,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          SitiColors.terracotta,
                        ),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isNepali
                          ? '${progress.remainingIds.length} काम बाँकी छन् — खाना खान पहिले पनि सकिन्छ।'
                          : '${progress.remainingIds.length} left. You can cook first and finish these later.',
                      style: NepaliTypography.bodySmall.copyWith(
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Reads the observable household facts and derives the setup checklist.
  ///
  /// Delegates to the shared derivation so the home card and the profile screen can never
  /// disagree about what is still outstanding.
  Future<SetupProgress> _loadSetupProgress() async {
    final consumption = _consumptionRepo;

    return loadSetupProgress(
      settings: widget.settings!,
      memberCount: () async =>
          consumption == null ? 0 : (await consumption.getMembers()).length,
      calibratedVesselCount: () async =>
          consumption == null ? 0 : await consumption.countCalibratedVessels(),
    );
  }

  void _openCompanionDisplays() {
    final service = _syncCoordinator?.displayService ?? _displayService;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        builder: (context, controller) => ListView(
          controller: controller,
          children: [
            HomeScreenWidgetPreviews(
              todaysMeals: service.todaysMealsWidget,
              activeSiti: service.activeSitiWidget,
              groceryChecklist: service.groceryChecklistWidget,
            ),
            const Divider(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                _isNepali ? 'स्मार्टवॉच सहायक' : 'Watch Companion',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: SitiColors.terracotta,
                    ),
              ),
            ),
            const SizedBox(height: 12),
            WatchCompanionPreviewSheet(service: service),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  /// Opens the local planner database lazily, the first time the Planner tab is shown.
  Future<void> _ensurePlannerRepo() async {
    if (_plannerRepo != null) return;
    try {
      final repo = await WeeklyPlannerRepository.openOnDisk();
      if (mounted) {
        setState(() {
          _plannerRepo = repo;
        });
      }
    } catch (_) {
      // Storage unavailable: planner tab keeps showing its loading state.
    }
  }

  /// Opens the local consumption database lazily.
  Future<ConsumptionRepository?> _ensureConsumptionRepo() async {
    if (_consumptionRepo != null) return _consumptionRepo!;
    try {
      final repo = await ConsumptionRepository.openOnDisk();
      if (mounted) {
        setState(() {
          _consumptionRepo = repo;
        });
      }
      return repo;
    } catch (_) {
      return null;
    }
  }

  Future<void> _showPostMealPrompt() async {
    final repo = await _ensureConsumptionRepo();
    if (repo == null) return;
    final members = await repo.getMembers();
    final vesselProfile = await repo.getVesselProfile();
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => PostMealUsualDialog(
        recipeId: 'dal-bhat',
        recipeTitle: _isNepali ? 'दाल-भात' : 'Dal Bhat',
        mealSlot: 'evening-dal-bhat',
        currentLanguage: widget.preferences.language,
        repository: repo,
        members: members,
        vesselProfile: vesselProfile,
      ),
    );
  }

  void _incrementWhistle() {
    setState(() {
      _whistleCount++;
    });
  }

  void _decrementWhistle() {
    if (_whistleCount > 0) {
      setState(() {
        _whistleCount--;
      });
    }
  }

  void _resetWhistle() {
    setState(() {
      _whistleCount = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_currentTabIndex == 1) {
      return Scaffold(
        body: _plannerRepo != null
            ? WeeklyPlannerScreen(
                repository: _plannerRepo!,
                currentLanguage: widget.preferences.language,
              )
            : const Center(child: CircularProgressIndicator()),
        bottomNavigationBar: _buildBottomNav(),
      );
    }

    if (_currentTabIndex == 2) {
      return Scaffold(
        body: SeasonalKitchenScreen(
          currentLanguage: widget.preferences.language,
        ),
        bottomNavigationBar: _buildBottomNav(),
      );
    }

    // Current date in BS (approx 2081 Ashwin 15)
    const todayBs = BsDate(year: 2081, month: 7, day: 15);

    return Scaffold(
      backgroundColor: SitiColors.warmWhite,
      appBar: AppBar(
        backgroundColor: SitiColors.warmWhite,
        elevation: 0,
        title: Text(
          'Siti Counter 3.0',
          // The action row is fixed-width, so the title has to yield rather than overflow
          // on a narrow screen.
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          style: NepaliTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
            color: SitiColors.dark,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            key: const Key('consumption_dashboard_button'),
            icon: const Icon(Icons.pie_chart_outline_rounded, color: SitiColors.dark),
            tooltip: _isNepali ? 'पोषण र खपत' : 'Consumption Dashboard',
            onPressed: () async {
              final repo = await _ensureConsumptionRepo();
              if (repo == null) return;
              if (context.mounted) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ConsumptionDashboardScreen(
                      currentLanguage: widget.preferences.language,
                      repository: repo,
                    ),
                  ),
                );
              }
            },
          ),
          IconButton(
            key: const Key('ai_assistant_button'),
            icon: const Icon(Icons.auto_awesome_rounded, color: SitiColors.terracotta),
            tooltip: _isNepali ? 'एआई भान्सा सहयोगी' : 'AI Kitchen Assistant',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => AiAssistantScreen(
                    service: AiAssistantService(
                      elevationMeters: widget.preferences.elevationMeters,
                    ),
                    currentLanguage: widget.preferences.language,
                  ),
                ),
              );
            },
          ),
          IconButton(
            key: const Key('companion_displays_button'),
            icon: const Icon(Icons.widgets_outlined, color: SitiColors.dark),
            tooltip: _isNepali ? 'विजेट र घडी' : 'Widgets & Watch',
            onPressed: _openCompanionDisplays,
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: SitiColors.dark),
            tooltip: 'Setup Wizard',
            onPressed: widget.onResetOnboarding,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Six Ritus Season Indicator
              SixRitusIndicator(
                currentDate: todayBs,
                preferNepali: _isNepali,
              ),
              const SizedBox(height: 12),

              // Guest badge lives in the body, not the app bar: at 411dp the badge plus
              // four icon buttons overflowed the action row and the right-most buttons were
              // clipped off-screen and untappable.
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  key: const Key('guest_mode_badge'),
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade700, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.person_outline_rounded,
                        size: 14,
                        color: Colors.amber.shade900,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isNepali ? 'अतिथि (Guest)' : 'Guest Mode',
                        style: NepaliTypography.labelLarge.copyWith(
                          color: Colors.amber.shade900,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Progressive household setup, shown until every essential is configured.
              _buildSetupChecklist(),
              const SizedBox(height: 24),

              // Whistle Counter Hero Card
              Container(
                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Text(
                      _isNepali ? 'सिट्ठी संख्या' : 'Whistle Count',
                      style: NepaliTypography.titleMedium.copyWith(
                        color: Colors.grey.shade600,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Massive Counter Display
                    Text(
                      _isNepali
                          ? NepaliCalendar.toDevanagariDigits(_whistleCount)
                          : '$_whistleCount',
                      style: SitiTypography.counterArmsLengthStyle.copyWith(
                        color: SitiColors.terracotta,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Text(
                      _isListening
                          ? (_isNepali ? 'ध्वनि सुन्दैछ... (Listening)' : 'Listening for whistle...')
                          : (_isNepali ? 'स्ट्यान्डबाइ (Standby)' : 'Standby Mode'),
                      style: NepaliTypography.bodyMedium.copyWith(
                        color: _isListening ? SitiColors.freshGreen : Colors.grey.shade500,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Manual Adjustment Buttons
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 16,
                      runSpacing: 12,
                      children: [
                        IconButton.filledTonal(
                          onPressed: _decrementWhistle,
                          icon: const Icon(Icons.remove_rounded),
                          iconSize: 28,
                          tooltip: '-1 Whistle',
                        ),
                        FilledButton.icon(
                          onPressed: () {
                            setState(() {
                              _isListening = !_isListening;
                            });
                          },
                          icon: Icon(
                            _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                            size: 20,
                          ),
                          label: Text(_isListening ? 'Stop' : 'Start Auto-Listen'),
                          style: FilledButton.styleFrom(
                            backgroundColor: _isListening ? SitiColors.alert : SitiColors.terracotta,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        IconButton.filledTonal(
                          onPressed: _incrementWhistle,
                          icon: const Icon(Icons.add_rounded),
                          iconSize: 28,
                          tooltip: '+1 Whistle',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Full-Screen Active Session Button
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ActiveCookingSessionScreen(
                        targetWhistles: 4,
                        currentLanguage: widget.preferences.language,
                        initialWhistles: _whistleCount,
                        onSessionComplete: () {
                          _showPostMealPrompt();
                        },
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.fullscreen_rounded, size: 22),
                label: Text(
                  _isNepali ? 'सक्रिय भान्सा मोड खोल्नुहोस् (Active Mode)' : 'Open Full-Screen Kitchen Mode',
                  style: NepaliTypography.titleSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SitiColors.terracotta,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 1,
                ),
              ),
              const SizedBox(height: 12),

              // Reset Button
              Center(
                child: TextButton.icon(
                  onPressed: _resetWhistle,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: Text(_isNepali ? 'सिट्ठी रिसेट' : 'Reset Counter'),
                  style: TextButton.styleFrom(foregroundColor: Colors.grey.shade600),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return NavigationBar(
      selectedIndex: _currentTabIndex,
      onDestinationSelected: (index) {
        setState(() {
          _currentTabIndex = index;
        });
        if (index == 1) {
          _ensurePlannerRepo();
        }
      },
      destinations: [
        NavigationDestination(
          icon: const Icon(Icons.soup_kitchen_outlined),
          selectedIcon: const Icon(Icons.soup_kitchen_rounded),
          label: _isNepali ? 'भान्सा' : 'Kitchen',
        ),
        NavigationDestination(
          icon: const Icon(Icons.calendar_month_outlined),
          selectedIcon: const Icon(Icons.calendar_month_rounded),
          label: _isNepali ? 'योजना' : 'Planner',
        ),
        NavigationDestination(
          icon: const Icon(Icons.explore_outlined),
          selectedIcon: const Icon(Icons.explore_rounded),
          label: _isNepali ? 'खोज्नुहोस्' : 'Discover',
        ),
      ],
    );
  }
}
