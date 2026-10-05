import 'dart:convert';
import 'dart:io';

import '../sync/sync_repository.dart';
import 'companion_widget_service.dart';

/// SQLite-backed [DisplayFeedCache], so the home screen widgets and the watch companion
/// render the last server-confirmed payloads on a cold, offline start.
///
/// The ETag is stored alongside the payload: it is what lets the next launch revalidate
/// with `If-None-Match` and pay zero payload bytes when nothing changed.
class SqliteDisplayFeedCache implements DisplayFeedCache {
  final SyncRepository repository;
  final String householdId;

  SqliteDisplayFeedCache({
    required this.repository,
    required this.householdId,
  });

  @override
  Future<void> write(CompanionDisplaySnapshot snapshot, {String? etag}) async {
    await repository.writeDisplayFeed(
      householdId,
      snapshot.toJson(),
      etag: etag,
    );
  }

  @override
  Future<CompanionDisplaySnapshot?> read() async {
    final cached = await repository.readDisplayFeed(householdId);
    final payload = cached?.payload;
    if (payload == null) return null;

    try {
      final snapshot = CompanionDisplaySnapshot.fromFeedJson(payload);
      // An all-null snapshot means the row held nothing usable (e.g. written by an older
      // schema). Treat it as a miss so the caller re-fetches instead of rendering nothing.
      if (snapshot.isEmpty) return null;
      return snapshot;
    } catch (_) {
      // A malformed row must not brick the widget surfaces; drop it and let the next
      // refresh repopulate it.
      await repository.writeDisplayFeed(householdId, const {}, etag: null);
      return null;
    }
  }

  @override
  Future<String?> readEtag() async {
    final cached = await repository.readDisplayFeed(householdId);
    return cached?.etag;
  }

  @override
  Future<void> clear() async {
    await repository.writeDisplayFeed(householdId, const {}, etag: null);
  }
}

/// Default [DisplayFeedTransport] over `HttpClient`.
///
/// Reports a 304 as `{'notModified': true}` rather than throwing, and never throws on a
/// transport failure: [CompanionWidgetService.refreshFromApi] turns that into a failed
/// result and keeps serving the cached payloads.
Future<Map<String, dynamic>> httpDisplayFeedTransport({
  required String url,
  Map<String, String>? headers,
}) async {
  final client = HttpClient();
  try {
    final uri = Uri.parse(url);
    final request = await client.getUrl(uri);

    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    headers?.forEach(request.headers.set);

    final response = await request.close();

    if (response.statusCode == HttpStatus.notModified) {
      return const {'notModified': true};
    }

    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode >= 400) {
      // Surface the server's error envelope so the service can report it.
      try {
        return jsonDecode(body) as Map<String, dynamic>;
      } on FormatException {
        return {
          'error': 'HTTP_${response.statusCode}',
          'message': 'Display feed request failed with status ${response.statusCode}.',
        };
      }
    }

    final decoded = jsonDecode(body) as Map<String, dynamic>;
    final etag = response.headers.value(HttpHeaders.etagHeader);
    if (etag != null) decoded['etag'] = etag;
    return decoded;
  } finally {
    client.close(force: true);
  }
}