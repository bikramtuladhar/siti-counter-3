import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:kitchen_engine/kitchen_engine.dart';

import 'display_feed_cache.dart' show httpDisplayFeedTransport;

/// Result of a display-feed refresh attempt against the API.
class DisplayFeedResult {
  /// True when the server confirmed the cached feed is still current (HTTP 304).
  final bool notModified;

  /// True when fresh payloads were fetched and written to the cache.
  final bool refreshed;

  /// Set when the fetch failed; the previously cached payloads remain in use.
  final String? errorMessage;

  const DisplayFeedResult({
    required this.notModified,
    required this.refreshed,
    this.errorMessage,
  });

  const DisplayFeedResult.notModified()
    : notModified = true,
      refreshed = false,
      errorMessage = null;

  const DisplayFeedResult.refreshed()
    : notModified = false,
      refreshed = true,
      errorMessage = null;

  const DisplayFeedResult.failed(String message)
    : notModified = false,
      refreshed = false,
      errorMessage = message;
}

/// Abstraction over the API feed transport so tests can inject a fake.
typedef DisplayFeedTransport = Future<Map<String, dynamic>> Function({
  required String url,
  Map<String, String>? headers,
});

/// Persists the last known-good display feed payloads plus the ETag that produced them.
///
/// Cache-before-network: [CompanionWidgetService] renders from this on launch so the
/// home screen widgets and watch surface never show an empty state while offline.
abstract class DisplayFeedCache {
  Future<void> write(CompanionDisplaySnapshot snapshot, {String? etag});

  Future<CompanionDisplaySnapshot?> read();

  Future<String?> readEtag();

  Future<void> clear();
}

/// In-memory snapshot of everything the glanceable surfaces render.
class CompanionDisplaySnapshot {
  final TodaysMealsWidgetData? todaysMeals;
  final ActiveSitiWidgetData? activeSiti;
  final GroceryChecklistWidgetData? groceryChecklist;
  final WatchCompanionState? watchState;
  final DateTime? fetchedAt;

  const CompanionDisplaySnapshot({
    this.todaysMeals,
    this.activeSiti,
    this.groceryChecklist,
    this.watchState,
    this.fetchedAt,
  });

  static const CompanionDisplaySnapshot empty = CompanionDisplaySnapshot();

  bool get isEmpty =>
      todaysMeals == null &&
      activeSiti == null &&
      groceryChecklist == null &&
      watchState == null;

  /// Parses the `/v1/displays/feed` response envelope.
  factory CompanionDisplaySnapshot.fromFeedJson(Map<String, dynamic> json) {
    final meals = json['todaysMeals'];
    final activeSiti = json['activeSiti'];
    final grocery = json['groceryChecklist'];
    final watch = json['watchState'];

    return CompanionDisplaySnapshot(
      todaysMeals: meals is Map<String, dynamic>
          ? TodaysMealsWidgetData.fromJson(meals)
          : null,
      activeSiti: activeSiti is Map<String, dynamic>
          ? ActiveSitiWidgetData.fromJson(activeSiti)
          : null,
      groceryChecklist: grocery is Map<String, dynamic>
          ? GroceryChecklistWidgetData.fromJson(grocery)
          : null,
      watchState: watch is Map<String, dynamic>
          ? WatchCompanionState.fromJson(watch)
          : null,
      fetchedAt: DateTime.tryParse(json['fetchedAt']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
    'todaysMeals': todaysMeals?.toJson(),
    'activeSiti': activeSiti?.toJson(),
    'groceryChecklist': groceryChecklist?.toJson(),
    'watchState': watchState?.toJson(),
    'fetchedAt': fetchedAt?.toIso8601String(),
  };

  /// Payload handed to the native widget/watch extensions.
  Map<String, dynamic> toNativeWidgetPayloads() => {
    'todaysMeals': todaysMeals?.toJson(),
    'activeSiti': activeSiti?.toJson(),
    'groceryChecklist': groceryChecklist?.toJson(),
    'watchState': watchState?.toJson(),
    'timestamp': (fetchedAt ?? DateTime.now()).toIso8601String(),
  };
}

/// Simple in-memory cache, used in tests and as the fallback before the SQLite
/// cache is opened.
class InMemoryDisplayFeedCache implements DisplayFeedCache {
  CompanionDisplaySnapshot? _snapshot;
  String? _etag;

  @override
  Future<void> write(CompanionDisplaySnapshot snapshot, {String? etag}) async {
    _snapshot = snapshot;
    if (etag != null) _etag = etag;
  }

  @override
  Future<CompanionDisplaySnapshot?> read() async => _snapshot;

  @override
  Future<String?> readEtag() async => _etag;

  @override
  Future<void> clear() async {
    _snapshot = null;
    _etag = null;
  }
}

/// Service managing glanceable data payloads for native home screen widgets (iOS WidgetKit, Android Glance)
/// and coordinating two-way state synchronization with Apple Watch (watchOS) and Wear OS companion apps.
///
/// Data flow: the API is the source of truth. On launch the service hydrates from
/// [DisplayFeedCache] (cache-first), then [refreshFromApi] revalidates with an ETag so an
/// unchanged household costs a 304 and no payload bytes.
class CompanionWidgetService extends ChangeNotifier {
  TodaysMealsWidgetData? _todaysMealsWidget;
  ActiveSitiWidgetData? _activeSitiWidget;
  GroceryChecklistWidgetData? _groceryChecklistWidget;
  WatchCompanionState? _watchCompanionState;

  /// Steps for the active session, so advancing a step can render the new instruction.
  List<String> _stepsEn = const [];
  List<String> _stepsNe = const [];

  final DisplayFeedCache? cache;
  final String apiBaseUrl;
  final DisplayFeedTransport? transport;

  bool _isRefreshing = false;

  CompanionWidgetService({
    this.cache,
    this.apiBaseUrl = 'https://api.siticounter.app',
    this.transport,
  });

  /// Endpoint serving the glanceable payloads for this household.
  String get feedUrl => '$apiBaseUrl/v1/displays/feed';

  TodaysMealsWidgetData? get todaysMealsWidget => _todaysMealsWidget;
  ActiveSitiWidgetData? get activeSitiWidget => _activeSitiWidget;
  GroceryChecklistWidgetData? get groceryChecklistWidget => _groceryChecklistWidget;
  WatchCompanionState? get watchCompanionState => _watchCompanionState;
  bool get isRefreshing => _isRefreshing;

  /// Whether a payload has been hydrated (from cache or API) for the given surface.
  bool get hasAnyPayload =>
      _todaysMealsWidget != null ||
      _activeSitiWidget != null ||
      _groceryChecklistWidget != null ||
      _watchCompanionState != null;

  /// Loads the cached feed so the surfaces render immediately on a cold, offline start.
  Future<void> hydrateFromCache() async {
    final cached = await cache?.read();
    if (cached == null || cached.isEmpty) return;
    _applySnapshot(cached);
    notifyListeners();
  }

  /// Revalidates against the API using the cached ETag.
  ///
  /// Returns without touching current payloads on 304 or on any error, so a failed
  /// refresh never blanks a working offline surface.
  Future<DisplayFeedResult> refreshFromApi() async {
    if (_isRefreshing) {
      return const DisplayFeedResult.failed('Display feed refresh already in progress.');
    }
    _isRefreshing = true;
    notifyListeners();

    try {
      final etag = await cache?.readEtag();
      final headers = <String, String>{'Accept': 'application/json'};
      if (etag != null && etag.isNotEmpty) headers['If-None-Match'] = etag;

      final response = await _fetch(headers);

      if (response['notModified'] == true) {
        return const DisplayFeedResult.notModified();
      }

      final error = response['error'];
      if (error != null) {
        return DisplayFeedResult.failed(
          response['message']?.toString() ?? error.toString(),
        );
      }

      final snapshot = CompanionDisplaySnapshot.fromFeedJson(response);
      if (snapshot.isEmpty) {
        return const DisplayFeedResult.failed('Display feed payload was empty.');
      }

      _applySnapshot(snapshot);
      await cache?.write(
        snapshot,
        etag: response['etag']?.toString(),
      );
      return const DisplayFeedResult.refreshed();
    } catch (e) {
      return DisplayFeedResult.failed(e.toString());
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> _fetch(Map<String, String> headers) async {
    final transport = this.transport;
    if (transport != null) {
      return transport(url: feedUrl, headers: {...headers, ...?_authHeaders()});
    }

    // Default to the real HTTP transport, so wiring the service is enough to go live.
    return httpDisplayFeedTransport(
      url: feedUrl,
      headers: {...headers, ...?_authHeaders()},
    );
  }

  /// Access token for the household-scoped feed endpoint.
  String? Function()? _accessTokenProvider;

  set accessTokenProvider(String? Function()? provider) =>
      _accessTokenProvider = provider;

  Map<String, String>? _authHeaders() {
    final token = _accessTokenProvider?.call();
    if (token == null || token.isEmpty) return null;
    return {'Authorization': 'Bearer $token'};
  }

  void _applySnapshot(CompanionDisplaySnapshot snapshot) {
    if (snapshot.todaysMeals != null) _todaysMealsWidget = snapshot.todaysMeals;
    if (snapshot.activeSiti != null) _activeSitiWidget = snapshot.activeSiti;
    if (snapshot.groceryChecklist != null) {
      _groceryChecklistWidget = snapshot.groceryChecklist;
    }
    if (snapshot.watchState != null) _watchCompanionState = snapshot.watchState;
  }

  /// Updates Today's Meals widget payload
  void updateTodaysMeals({
    required String dateIso,
    required String rituNameEn,
    required String rituNameNe,
    required List<WidgetPlannedMealSummary> meals,
  }) {
    _todaysMealsWidget = CompanionDisplayEngine.buildTodaysMealsWidget(
      dateIso: dateIso,
      rituNameEn: rituNameEn,
      rituNameNe: rituNameNe,
      meals: meals,
    );
    notifyListeners();
  }

  /// Updates Active Siti Counter widget payload.
  ///
  /// [isAlarmAcknowledged] is threaded through so acknowledging the alarm is sticky:
  /// later whistle increments must not re-arm it.
  void updateActiveSiti({
    required String sessionId,
    required String dishTitleEn,
    required String dishTitleNe,
    required int currentWhistles,
    required int targetWhistles,
    CompanionStatus status = CompanionStatus.cooking,
    bool isAlarmAcknowledged = false,
  }) {
    _activeSitiWidget = CompanionDisplayEngine.buildActiveSitiWidget(
      sessionId: sessionId,
      dishTitleEn: dishTitleEn,
      dishTitleNe: dishTitleNe,
      currentWhistles: currentWhistles,
      targetWhistles: targetWhistles,
      status: status,
      isAlarmAcknowledged: isAlarmAcknowledged,
    );
    notifyListeners();
  }

  /// Updates Grocery Checklist widget payload
  void updateGroceryChecklist(List<GroceryItemWidgetSummary> items) {
    _groceryChecklistWidget = CompanionDisplayEngine.buildGroceryChecklistWidget(items);
    notifyListeners();
  }

  /// Sets or updates watch companion state
  void updateWatchCompanionState(WatchCompanionState state) {
    _watchCompanionState = state;
    notifyListeners();
  }

  /// Registers the full step list so [toggleWatchStep] can render each step's
  /// own instruction instead of repeating the current one.
  void registerWatchSteps({required List<String> stepsEn, required List<String> stepsNe}) {
    _stepsEn = List.unmodifiable(stepsEn);
    _stepsNe = List.unmodifiable(stepsNe);
    final state = _watchCompanionState;
    if (state == null) return;

    _watchCompanionState = state.copyWith(
      totalSteps: _effectiveTotalSteps(state.totalSteps),
      currentStepInstructionEn: _instructionFor(_stepsEn, state.currentStepIndex) ??
          state.currentStepInstructionEn,
      currentStepInstructionNe: _instructionFor(_stepsNe, state.currentStepIndex) ??
          state.currentStepInstructionNe,
    );
    notifyListeners();
  }

  int _effectiveTotalSteps(int declaredTotal) {
    final byEn = _stepsEn.length;
    final byNe = _stepsNe.length;
    final longest = byEn > byNe ? byEn : byNe;
    if (longest > 0) return longest;
    return declaredTotal;
  }

  String? _instructionFor(List<String> steps, int index) {
    if (steps.isEmpty) return null;
    if (index < 0 || index >= steps.length) return null;
    return steps[index];
  }

  /// Handles a whistle increment from the Watch or the main app.
  ///
  /// An acknowledged (completed) session keeps its terminal state: whistles can still be
  /// counted for the record, but the alarm does not come back.
  void incrementWatchWhistle() {
    final current = _watchCompanionState;
    if (current == null) return;

    final nextWhistle = current.currentWhistles + 1;
    final acknowledged = current.isAlarmAcknowledged;

    // Reuse the engine's alarm resolution so an increment follows exactly the same
    // acknowledgement rules as a server- or cache-fed snapshot.
    final resolved = CompanionDisplayEngine.resolveAlarm(
      currentWhistles: nextWhistle,
      targetWhistles: current.targetWhistles,
      requestedAlarm: current.isAlarmActive,
      isAlarmAcknowledged: acknowledged,
      requestedStatus: current.status,
    );

    // Preserve live session fields the snapshot builder does not own (step position and
    // the step texts already resolved for that position).
    final nextState = current.copyWith(
      currentWhistles: nextWhistle,
      isAlarmAcknowledged: acknowledged,
      status: resolved.status,
      isAlarmActive: resolved.isAlarmActive,
      lastHapticPattern: _hapticForIncrement(
        nextWhistle,
        targetWhistles: current.targetWhistles,
        isAlarmAcknowledged: acknowledged,
      ),
    );

    _watchCompanionState = nextState;

    // Keep the phone widget in step with the watch for the same session.
    final activeSiti = _activeSitiWidget;
    if (activeSiti != null && activeSiti.sessionId == current.sessionId) {
      _activeSitiWidget = CompanionDisplayEngine.buildActiveSitiWidget(
        sessionId: current.sessionId,
        dishTitleEn: current.dishTitleEn,
        dishTitleNe: current.dishTitleNe,
        currentWhistles: nextWhistle,
        targetWhistles: current.targetWhistles,
        status: nextState.status,
        isAlarmAcknowledged: acknowledged,
      );
    }

    notifyListeners();
  }

  WatchHapticPattern _hapticForIncrement(
    int whistles, {
    required int targetWhistles,
    required bool isAlarmAcknowledged,
  }) {
    if (isAlarmAcknowledged) return WatchHapticPattern.none;
    if (CompanionDisplayEngine.isTargetReached(whistles, targetWhistles)) {
      return WatchHapticPattern.targetReached;
    }
    if (whistles > 0) return WatchHapticPattern.whistle;
    return WatchHapticPattern.none;
  }

  /// Toggles completion of the current step from the Watch.
  ///
  /// Reversible: tapping again on a completed step reopens it, which is what a
  /// "step completion toggle" needs. Completing the final step finishes the session.
  void toggleWatchStep() {
    final current = _watchCompanionState;
    if (current == null) return;
    if (current.isAlarmAcknowledged || current.status == CompanionStatus.completed) return;

    final totalSteps = _effectiveTotalSteps(current.totalSteps);
    if (totalSteps <= 0) return;
    final maxIndex = totalSteps - 1;

    // Reversible: reopening a completed step walks back one and clears the flag.
    if (current.isStepCompleted) {
      final reopenedIndex = (current.currentStepIndex - 1).clamp(0, maxIndex);
      _watchCompanionState = current.copyWith(
        currentStepIndex: reopenedIndex,
        isStepCompleted: false,
        currentStepInstructionEn:
            _instructionFor(_stepsEn, reopenedIndex) ?? current.currentStepInstructionEn,
        currentStepInstructionNe:
            _instructionFor(_stepsNe, reopenedIndex) ?? current.currentStepInstructionNe,
        lastHapticPattern: WatchHapticPattern.tick,
      );
      notifyListeners();
      return;
    }

    final isFinalStep = current.currentStepIndex >= maxIndex;

    // Completing the last step finishes the session rather than pointing past the end.
    if (isFinalStep) {
      _watchCompanionState = current.copyWith(
        isStepCompleted: true,
        status: CompanionStatus.completed,
        isAlarmAcknowledged: true,
        isAlarmActive: false,
        lastHapticPattern: WatchHapticPattern.targetReached,
      );
      notifyListeners();
      return;
    }

    final nextIndex = current.currentStepIndex + 1;
    _watchCompanionState = current.copyWith(
      currentStepIndex: nextIndex,
      isStepCompleted: false,
      currentStepInstructionEn:
          _instructionFor(_stepsEn, nextIndex) ?? current.currentStepInstructionEn,
      currentStepInstructionNe:
          _instructionFor(_stepsNe, nextIndex) ?? current.currentStepInstructionNe,
      lastHapticPattern: WatchHapticPattern.tick,
    );
    notifyListeners();
  }

  /// Advances to the next step without toggling (kept for callers that only move forward).
  void advanceWatchStep() {
    final current = _watchCompanionState;
    if (current == null) return;
    if (current.isAlarmAcknowledged || current.status == CompanionStatus.completed) return;

    final totalSteps = _effectiveTotalSteps(current.totalSteps);
    if (totalSteps <= 0) return;
    if (current.currentStepIndex >= totalSteps - 1) return;

    final nextIndex = current.currentStepIndex + 1;
    _watchCompanionState = current.copyWith(
      currentStepIndex: nextIndex,
      isStepCompleted: false,
      currentStepInstructionEn:
          _instructionFor(_stepsEn, nextIndex) ?? current.currentStepInstructionEn,
      currentStepInstructionNe:
          _instructionFor(_stepsNe, nextIndex) ?? current.currentStepInstructionNe,
      lastHapticPattern: WatchHapticPattern.tick,
    );
    notifyListeners();
  }

  /// Acknowledges the alarm from the Watch or the phone.
  ///
  /// Marks the session terminal (`completed`) rather than a non-enum `'done'`, and records
  /// the acknowledgement so the alarm cannot be re-derived from the whistle count.
  void dismissAlarm() {
    final current = _watchCompanionState;
    if (current != null && current.isAlarmActive) {
      _watchCompanionState = current.copyWith(
        isAlarmActive: false,
        status: CompanionStatus.completed,
        isAlarmAcknowledged: true,
        lastHapticPattern: WatchHapticPattern.none,
      );
    }

    final activeSiti = _activeSitiWidget;
    if (activeSiti != null && activeSiti.isAlarmActive) {
      _activeSitiWidget = activeSiti.copyWith(
        isAlarmActive: false,
        status: CompanionStatus.completed,
        isAlarmAcknowledged: true,
      );
    }

    notifyListeners();
  }

  /// Exports all current payloads for native platform storage (WidgetKit UserDefaults / Glance SharedPreferences)
  Map<String, dynamic> exportNativeWidgetPayloads() {
    final snapshot = CompanionDisplaySnapshot(
      todaysMeals: _todaysMealsWidget,
      activeSiti: _activeSitiWidget,
      groceryChecklist: _groceryChecklistWidget,
      watchState: _watchCompanionState,
      fetchedAt: DateTime.now(),
    );
    return snapshot.toNativeWidgetPayloads();
  }

  /// The instruction currently shown on the watch surface for [index].
  String currentStepInstructionEn(int index) =>
      _instructionFor(_stepsEn, index) ?? _watchCompanionState?.currentStepInstructionEn ?? '';

  String currentStepInstructionNe(int index) =>
      _instructionFor(_stepsNe, index) ?? _watchCompanionState?.currentStepInstructionNe ?? '';
}