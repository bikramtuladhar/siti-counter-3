import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:kitchen_engine/kitchen_engine.dart';
import 'sync_repository.dart';

enum SyncStatus {
  idle,
  syncing,
  offline,
  error,
}

class SyncResult {
  final bool success;
  final int appliedCount;
  final int remoteCount;
  final int conflictsCount;
  final String? syncToken;
  final String? errorMessage;

  const SyncResult({
    required this.success,
    this.appliedCount = 0,
    this.remoteCount = 0,
    this.conflictsCount = 0,
    this.syncToken,
    this.errorMessage,
  });
}

typedef SyncTransport = Future<Map<String, dynamic>> Function({
  required String url,
  required Map<String, dynamic> body,
  Map<String, String>? headers,
});

/// Offline-first delta synchronization engine.
///
/// Features:
/// - Batches pending outbox mutations within the low-bandwidth <30KB budget.
/// - Performs delta synchronization with Cloudflare Workers D1 (`POST /v1/sync`).
/// - Deterministic Last-Write-Wins and safety gate for allergen conflicts.
/// - Lifecycle triggers: App open, app close/background, and post-cooking.
class SyncEngine {
  final SyncRepository repository;
  final String apiBaseUrl;
  final String householdId;
  final SyncTransport? transport;
  final ValueNotifier<SyncStatus> statusNotifier = ValueNotifier<SyncStatus>(SyncStatus.idle);

  // Maximum payload budget: 28KB leaves safe headroom below 30KB limit
  static const int maxBatchBytes = 28 * 1024;

  SyncLifecycleObserver? _lifecycleObserver;

  SyncEngine({
    required this.repository,
    this.apiBaseUrl = 'https://api.siticounter.app',
    required this.householdId,
    this.transport,
  });

  SyncStatus get status => statusNotifier.value;

  /// Attaches app lifecycle observer to trigger sync on open and close.
  void attachLifecycleObserver() {
    _lifecycleObserver ??= SyncLifecycleObserver(this);
    WidgetsBinding.instance.addObserver(_lifecycleObserver!);
  }

  /// Detaches lifecycle observer when engine is disposed.
  void detachLifecycleObserver() {
    if (_lifecycleObserver != null) {
      WidgetsBinding.instance.removeObserver(_lifecycleObserver!);
      _lifecycleObserver = null;
    }
  }

  /// Hook called immediately when cooking session finishes.
  Future<SyncResult> onCookingCompleted() async {
    return syncNow();
  }

  /// Triggers a delta-sync pass.
  Future<SyncResult> syncNow({int maxItems = 50}) async {
    if (statusNotifier.value == SyncStatus.syncing) {
      return const SyncResult(
        success: false,
        errorMessage: 'Synchronization is already in progress.',
      );
    }

    statusNotifier.value = SyncStatus.syncing;

    try {
      final lastSyncToken = await repository.getLastSyncToken();
      final allPending = await repository.getPendingOutbox(limit: maxItems);

      // Pack mutations within the 28KB budget
      final batchChanges = <SyncChange>[];
      var currentBytes = jsonEncode({'householdId': householdId, 'lastSyncToken': lastSyncToken, 'changes': []}).length;

      for (final change in allPending) {
        final changeBytes = jsonEncode(change.toJson()).length + 2;
        if (currentBytes + changeBytes > maxBatchBytes) {
          break; // Stop adding to current batch to respect low-bandwidth limit
        }
        batchChanges.add(change);
        currentBytes += changeBytes;
      }

      final requestPayload = {
        'householdId': householdId,
        'lastSyncToken': lastSyncToken,
        'changes': batchChanges.map((c) => c.toJson()).toList(),
      };

      final responseJson = await _sendSyncRequest(requestPayload);

      if (responseJson.containsKey('error')) {
        final err = responseJson['message'] ?? responseJson['error'] ?? 'Unknown sync error';
        await repository.markAttemptFailed(
          batchChanges.map((c) => c.id).toList(),
          err.toString(),
        );
        statusNotifier.value = SyncStatus.error;
        return SyncResult(success: false, errorMessage: err.toString());
      }

      final applied = (responseJson['applied'] as num?)?.toInt() ?? 0;
      final syncToken = responseJson['syncToken'] as String?;
      final serverConflicts = (responseJson['conflicts'] as List?) ?? [];
      final remoteChangesRaw = (responseJson['remoteChanges'] as List?) ?? [];

      // Acknowledge successfully applied outbox items
      final appliedIds = batchChanges
          .where((c) => !serverConflicts.any((sc) => sc['id'] == c.id))
          .map((c) => c.id)
          .toList();
      await repository.markChangesSynced(appliedIds, syncToken);

      // Record any server conflicts
      for (final conflictMap in serverConflicts) {
        if (conflictMap is Map) {
          final conflict = SyncConflict(
            entityType: conflictMap['entityType']?.toString() ?? 'unknown',
            entityId: conflictMap['entityId']?.toString() ?? '',
            reason: conflictMap['reason']?.toString() ?? 'CONFLICT',
            localChange: batchChanges.firstWhere(
              (c) => c.id == conflictMap['id'],
              orElse: () => SyncChange(
                id: conflictMap['id']?.toString() ?? '',
                householdId: householdId,
                entityType: conflictMap['entityType']?.toString() ?? '',
                entityId: conflictMap['entityId']?.toString() ?? '',
                version: 1,
                payload: {},
                createdAt: 0,
              ),
            ),
            remoteChange: SyncChange(
              id: UuidV7.generate(),
              householdId: householdId,
              entityType: conflictMap['entityType']?.toString() ?? '',
              entityId: conflictMap['entityId']?.toString() ?? '',
              version: 1,
              payload: (conflictMap['safeMergedPayload'] as Map<String, dynamic>?) ?? {},
              createdAt: DateTime.now().millisecondsSinceEpoch,
            ),
            requiresPrompt: conflictMap['requiresPrompt'] == true,
            safeMergedPayload: conflictMap['safeMergedPayload'] as Map<String, dynamic>?,
          );
          await repository.recordConflict(conflict);
        }
      }

      statusNotifier.value = SyncStatus.idle;

      return SyncResult(
        success: true,
        appliedCount: applied,
        remoteCount: remoteChangesRaw.length,
        conflictsCount: serverConflicts.length,
        syncToken: syncToken,
      );
    } on SocketException {
      statusNotifier.value = SyncStatus.offline;
      return const SyncResult(success: false, errorMessage: 'Device is offline');
    } catch (e) {
      statusNotifier.value = SyncStatus.error;
      return SyncResult(success: false, errorMessage: e.toString());
    }
  }

  Future<Map<String, dynamic>> _sendSyncRequest(Map<String, dynamic> requestPayload) async {
    if (transport != null) {
      return transport!(
        url: '$apiBaseUrl/v1/sync',
        body: requestPayload,
        headers: {
          'Content-Type': 'application/json',
          'Accept-Encoding': 'gzip, deflate',
        },
      );
    }

    // Default HttpClient implementation with gzip handling
    final client = HttpClient();
    try {
      final uri = Uri.parse('$apiBaseUrl/v1/sync');
      final req = await client.postUrl(uri);
      req.headers.set('Content-Type', 'application/json');
      req.headers.set('Accept-Encoding', 'gzip, deflate');

      final bodyBytes = utf8.encode(jsonEncode(requestPayload));
      req.contentLength = bodyBytes.length;
      req.add(bodyBytes);

      final resp = await req.close();
      final respBody = await resp.transform(utf8.decoder).join();
      return jsonDecode(respBody) as Map<String, dynamic>;
    } finally {
      client.close();
    }
  }
}

/// Lifecycle observer that triggers sync on app resume and background.
class SyncLifecycleObserver extends WidgetsBindingObserver {
  final SyncEngine engine;

  SyncLifecycleObserver(this.engine);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App Open -> Sync
      engine.syncNow();
    } else if (state == AppLifecycleState.paused) {
      // App Close / Background -> Sync
      engine.syncNow();
    }
  }
}
