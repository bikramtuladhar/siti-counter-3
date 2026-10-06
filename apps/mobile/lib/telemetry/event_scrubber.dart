/// Removes household and health data from an error event before it leaves the device.
///
/// Siti Counter records who is in the household, what each person is allergic to, what they
/// ate and what a recipe needed. Any of that reaching a third-party error tracker would be a
/// disclosure of health data about identifiable people, and it is exactly the kind of value
/// that ends up pasted into a public issue tracker.
///
/// So scrubbing happens here rather than being left to configuration. Configuration-based
/// filtering only covers the fields you thought of; this walks the whole event and redacts by
/// key name, including nested maps and breadcrumb payloads, which is where surprises live.
///
/// The event is treated as untrusted JSON: keys are matched case-insensitively and after
/// stripping separators, so `MemberName`, `member_name` and `memberName` are all caught.
library;

/// Keys whose values must never be transmitted.
///
/// Matched as a substring so `memberNameEn` and `severeAllergensNe` are covered without
/// enumerating every locale-specific variant.
const Set<String> piiKeyFragments = {
  'name',
  'email',
  'phone',
  'address',
  'notes',
  'note',
  'allergen',
  'dietary',
  'health',
  'medical',
  'condition',
  'ingredient',
  'recipe',
  'household',
  'member',
  'child',
  'dob',
  'birth',
  'lat',
  'lon',
  'lng',
  'latitude',
  'longitude',
  'token',
  'password',
  'secret',
  'authorization',
  'cookie',
  'dsn',
};

/// Keys that are safe even though they contain a blocked fragment.
///
/// `username` would otherwise be caught by the `name` fragment, and a household id is a random
/// opaque identifier, not a person's name — though we still do not send one.
const Set<String> piiKeyAllowlist = {
  'username',
  'hostname',
  'sourcename',
  'filename',
  'classname',
  'namespace',
};

/// Marker written in place of a redacted value.
const String redactedMarker = '[redacted]';

String _normaliseKey(String key) =>
    key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

final Set<String> _piiNormalised = {
  for (final fragment in piiKeyFragments) _normaliseKey(fragment),
};

final Set<String> _allowlistedNormalised = {
  for (final key in piiKeyAllowlist) _normaliseKey(key),
};

/// Whether a key's value must be redacted.
bool isSensitiveKey(String key) {
  final normalised = _normaliseKey(key);
  if (_allowlistedNormalised.contains(normalised)) return false;
  for (final fragment in _piiNormalised) {
    if (normalised.contains(fragment)) return true;
  }
  return false;
}

/// Deep-copies [value], redacting sensitive entries and bounding its size.
///
/// A crash inside a loop can attach a very large payload; an error tracker is not the place to
/// store a megabyte of state, and the depth cap stops a self-referential structure from
/// recursing forever.
Object? scrubStructure(Object? value, {int depth = 0, int maxDepth = 8}) {
  if (depth > maxDepth) return '[truncated]';

  if (value is Map) {
    final out = <String, Object?>{};
    value.forEach((key, entry) {
      final name = key.toString();
      out[name] = isSensitiveKey(name) ? redactedMarker : scrubStructure(entry, depth: depth + 1);
    });
    return out;
  }

  if (value is Iterable) {
    // Cap list length as well as depth: a log attached as a list can be enormous.
    var taken = 0;
    final out = <Object?>[];
    for (final entry in value) {
      if (taken >= 50) {
        out.add('[truncated]');
        break;
      }
      out.add(scrubStructure(entry, depth: depth + 1));
      taken += 1;
    }
    return out;
  }

  if (value is String && value.length > 512) {
    return '${value.substring(0, 512)}…[truncated]';
  }

  return value;
}

/// Redacts a whole Sentry-shaped event map in place and returns it.
///
/// Sends `user` to a bare anonymous shape rather than dropping it: an anonymous crash-free
/// count is useful, an identified one is not.
Map<String, Object?> scrubEvent(Map<String, Object?> event) {
  final result = scrubStructure(event);

  if (result is! Map<String, Object?>) return event;

  // Never transmit identity, even the SDK's own defaults.
  result['user'] = const <String, Object?>{};

  final request = result['request'];
  if (request is Map<String, Object?>) {
    request.remove('data');
    request.remove('cookies');
    request.remove('headers');
    final url = request['url'];
    if (url is String) {
      // Keep the path for triage; drop any query string, which is where ids get smuggled.
      final queryAt = url.indexOf('?');
      request['url'] = queryAt == -1 ? url : '${url.substring(0, queryAt)}?[redacted]';
    }
  }

  result['server_name'] = null;
  return result;
}