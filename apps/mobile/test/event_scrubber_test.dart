import 'package:flutter_test/flutter_test.dart';
import 'package:siti_counter/telemetry/event_scrubber.dart';

void main() {
  group('isSensitiveKey', () {
    test('catches health and identity data regardless of naming style', () {
      for (final key in [
        'name',
        'Name',
        'memberName',
        'member_name',
        'memberNameEn',
        'householdName',
        'email',
        'EmailAddress',
        'phone',
        'notes',
        'recipeNotesNe',
        'allergens',
        'severeAllergensNe',
        'dietary',
        'childName',
        'dob',
        'latitude',
        'accessToken',
        'password',
        'authorization',
      ]) {
        expect(isSensitiveKey(key), isTrue, reason: '$key should be treated as sensitive');
      }
    });

    test('leaves technical keys alone', () {
      for (final key in [
        'route',
        '/v1/telemetry/session',
        'errorType',
        'frameCount',
        'jankRatio',
        'screen',
        'durationMs',
        'slotId',
        'rituId',
      ]) {
        expect(isSensitiveKey(key), isFalse, reason: '$key should be kept');
      }
    });

    test('the allowlist beats the fragment match', () {
      // 'username' contains 'name' but is not a household member's name.
      expect(isSensitiveKey('username'), isFalse);
      expect(isSensitiveKey('hostname'), isFalse);
      expect(isSensitiveKey('fileName'), isFalse);
    });
  });

  group('scrubStructure', () {
    test('redacts sensitive values and keeps the rest', () {
      final result = scrubStructure({
        'route': '/kitchen',
        'memberName': 'Sita',
        'frameCount': 42,
      });

      expect(result, isA<Map<String, Object?>>());
      final map = result! as Map<String, Object?>;
      expect(map['route'], '/kitchen');
      expect(map['frameCount'], 42);
      expect(map['memberName'], redactedMarker);
    });

    test('recurses into nested maps', () {
      final result = scrubStructure({
        'context': {
          'screen': 'planner',
          'user': {
            'name': 'Ram',
            'allergens': ['peanut'],
          },
        },
      })! as Map<String, Object?>;

      final context = result['context']! as Map<String, Object?>;
      expect(context['screen'], 'planner');
      final user = context['user']! as Map<String, Object?>;
      expect(user['name'], redactedMarker);
      expect(user['allergens'], redactedMarker);
    });

    test('redacts inside lists of maps', () {
      final result = scrubStructure({
        'slots': [
          {'slotId': 'lunch', 'dishName': 'Dal Bhat'},
        ],
      })! as Map<String, Object?>;

      final slots = result['slots']! as List<Object?>;
      final slot = slots.single! as Map<String, Object?>;
      expect(slot['slotId'], 'lunch');
      expect(slot['dishName'], redactedMarker);
    });

    test('a household roster is dropped whole, not field by field', () {
      // 'members' matches the member fragment, so the entire list goes rather than leaving a
      // partially redacted roster behind. A list of names where the ages survive is still a
      // list of people.
      final result = scrubStructure({
        'members': [
          {'name': 'A', 'age': 7},
        ],
      })! as Map<String, Object?>;

      expect(result['members'], redactedMarker);
    });

    test('bounds depth so a deeply nested structure terminates', () {
      Map<String, Object?> node = {'leaf': true};
      for (var i = 0; i < 40; i++) {
        node = {'next': node};
      }

      Map<String, Object?>? result;
      expect(() => result = scrubStructure({'deep': node}) as Map<String, Object?>, returnsNormally);
      expect(result, isNotNull);
    });

    test('truncates long lists', () {
      final result = scrubStructure({
        'log': List<int>.generate(500, (i) => i),
      })! as Map<String, Object?>;

      final log = result['log']! as List<Object?>;
      expect(log.length, lessThanOrEqualTo(51));
      expect(log.last, '[truncated]');
    });

    test('truncates long strings', () {
      final result = scrubStructure({'detail': 'x' * 5000})! as Map<String, Object?>;
      expect((result['detail']! as String).length, lessThan(600));
      expect(result['detail'], endsWith('[truncated]'));
    });
  });

  group('scrubEvent', () {
    test('empties the user object entirely', () {
      final event = scrubEvent({
        'event_id': 'abc',
        'user': {
          'id': 'device-123',
          'email': 'someone@example.com',
          'ip_address': '203.0.113.9',
        },
      });

      expect(event['user'], isEmpty);
    });

    test('drops request body, cookies and headers', () {
      final event = scrubEvent({
        'request': {
          'url': 'https://api.example.com/v1/auth/google?code=secret-code',
          'headers': {'Authorization': 'Bearer abc'},
          'cookies': {'session': 'abc'},
          'data': {'email': 'someone@example.com'},
        },
      });

      final request = event['request']! as Map<String, Object?>;
      expect(request.containsKey('data'), isFalse);
      expect(request.containsKey('cookies'), isFalse);
      expect(request.containsKey('headers'), isFalse);
    });

    test('keeps the path but drops the query string', () {
      final event = scrubEvent({
        'request': {'url': 'https://api.example.com/v1/recipes?userId=42'},
      });
      final request = event['request']! as Map<String, Object?>;
      expect(request['url'], 'https://api.example.com/v1/recipes?[redacted]');
    });

    test('clears server_name', () {
      final event = scrubEvent({'server_name': 'household-laptop.local'});
      expect(event['server_name'], isNull);
    });

    test('redacts sensitive extras', () {
      final event = scrubEvent({
        'extra': {
          'screen': 'family-nutrition',
          'householdMemberName': 'Gita',
          'allergensNe': 'मूङ्ग',
          'frameCount': 12,
        },
      });

      final extra = event['extra']! as Map<String, Object?>;
      expect(extra['screen'], 'family-nutrition');
      expect(extra['frameCount'], 12);
      expect(extra['householdMemberName'], redactedMarker);
      expect(extra['allergensNe'], redactedMarker);
    });

    test('the serialised event contains none of the sensitive values', () {
      // The check that matters: nothing sensitive survives anywhere in the payload.
      final event = scrubEvent({
        'user': {'email': 'sita@example.com', 'ip_address': '198.51.100.7'},
        'extra': {
          'memberName': 'Sita',
          'severeAllergens': ['peanut', 'shellfish'],
          'recipeNotes': 'child reacts badly',
        },
        'contexts': {
          'app': {'householdName': 'Sharma family'},
        },
        'request': {
          'url': 'https://api.example.com/v1/x?member=Sita',
          'data': {'email': 'sita@example.com'},
        },
        'server_name': 'sharma-laptop',
      });

      final serialised = event.toString();
      for (final secret in [
        'sita@example.com',
        'Sita',
        'peanut',
        'shellfish',
        'child reacts badly',
        'Sharma family',
        '198.51.100.7',
        'sharma-laptop',
      ]) {
        expect(
          serialised.contains(secret),
          isFalse,
          reason: '"$secret" must not appear in the outbound event',
        );
      }
    });
  });
}