import 'dart:async';

import '../displays/companion_widget_service.dart';
import '../displays/display_feed_cache.dart';
import 'sync_engine.dart';
import 'sync_repository.dart';

/// Owns the app's server-connected state: the delta-sync engine and the glanceable
/// display service that the home screen widgets and watch companion read from.
///
/// Lifecycle on launch:
///  1. open the local sync database (source of the cached entity mirror + display feed),
///  2. hydrate the display surfaces from cache so they render immediately and offline,
///  3. sync and revalidate the feed against the API, updating cache and surfaces in place.
///
/// Everything is best-effort: a device that is offline, signed out, or has no network at all
/// still starts and renders from cache, because no step is allowed to throw during startup.
class AppSyncCoordinator {
  final SyncRepository repository;
  final SyncEngine syncEngine;
  final CompanionWidgetService displayService;

  /// Supplies the bearer token for household-scoped calls; null while signed out.
  final AccessTokenProvider? accessTokenProvider;

  /// Renews an expired access token before a sync pass.
  ///
  /// Without this the app authorises requests with a token the API has already rejected: the
  /// token's expiry was never tracked, so nothing noticed until every call came back 401.
  final Future<bool> Function()? ensureFreshToken;

  /// True when the last sync could not verify credentials because the API was unreachable.
  ///
  /// The sync result is then cache-only, which the UI should say rather than presenting an
  /// empty household as the truth.
  bool lastRunWasOffline = false;

  bool _isRefreshing = false;

  AppSyncCoordinator({
    required this.repository,
    required this.syncEngine,
    required this.displayService,
    this.accessTokenProvider,
    this.ensureFreshToken,
  });

  /// Builds a coordinator against the on-disk sync database.
  ///
  /// [householdId] must match the household the access token is scoped to, otherwise the API
  /// rejects the request with 403.
  static Future<AppSyncCoordinator> bootstrap({
    required String householdId,
    String apiBaseUrl = 'https://api.siticounter.app',
    AccessTokenProvider? accessTokenProvider,
    String databasePath = 'siti_sync.db',
  }) async {
    final repository = await SyncRepository.openOnDisk(databasePath);

    final displayService = CompanionWidgetService(
      cache: SqliteDisplayFeedCache(repository: repository, householdId: householdId),
      apiBaseUrl: apiBaseUrl,
    )..accessTokenProvider = accessTokenProvider;

    final syncEngine = SyncEngine(
      repository: repository,
      householdId: householdId,
      apiBaseUrl: apiBaseUrl,
      accessTokenProvider: accessTokenProvider,
    );

    return AppSyncCoordinator(
      repository: repository,
      syncEngine: syncEngine,
      displayService: displayService,
      accessTokenProvider: accessTokenProvider,
    );
  }

  /// Cache-first startup, then a background revalidation.
  ///
  /// [sync] performs the delta sync; pass false to skip it (e.g. a read-only preview).
  Future<void> start({bool sync = true}) async {
    await _hydrateFromCache();

    if (sync) {
      // Deliberately not awaited: startup must not block on the network. The surfaces
      // already have cached payloads, and the sync/refresh listeners update them in place.
      unawaited(refresh());
    }
  }

  /// Renders cached payloads immediately. Safe to call with no network.
  Future<void> _hydrateFromCache() async {
    try {
      await displayService.hydrateFromCache();
    } catch (_) {
      // A cache read failure must not prevent the app from starting.
    }
  }

  /// Syncs deltas then revalidates the display feed, coalescing concurrent calls.
  Future<SyncResult?> refresh() async {
    if (_isRefreshing) return null;
    _isRefreshing = true;

    try {
      // Renew first, so the pass does not authorise itself with a dead token.
      if (ensureFreshToken != null) {
        lastRunWasOffline = !(await ensureFreshToken!());
      }

      final result = await syncEngine.syncNow();

      // Only revalidate the feed when the token is present; without it the API answers 401
      // and the cached payloads are the best we can render.
      if (accessTokenProvider?.call() != null && !lastRunWasOffline) {
        await displayService.refreshFromApi();
      }

      return result;
    } catch (_) {
      return null;
    } finally {
      _isRefreshing = false;
    }
  }

  /// Runs a delta sync immediately, e.g. right after a cooking session finishes.
  Future<SyncResult?> onCookingCompleted() async {
    final result = await syncEngine.onCookingCompleted();
    if (accessTokenProvider?.call() != null) {
      await displayService.refreshFromApi();
    }
    return result;
  }

  void dispose() {
    syncEngine.detachLifecycleObserver();
    syncEngine.statusNotifier.dispose();
    displayService.dispose();
  }
}