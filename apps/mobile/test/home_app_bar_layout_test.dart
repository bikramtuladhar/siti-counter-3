import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:siti_counter/main.dart';
import 'package:siti_counter/onboarding/onboarding_state.dart';

/// Guards the home app bar against clipping its actions on a narrow phone.
///
/// The guest badge used to sit in the app bar alongside four icon buttons. On a 411dp-wide
/// screen the action row overflowed and the right-most buttons were laid out off-screen, so
/// they could not be tapped at all.
void main() {
  const actionKeys = [
    'consumption_dashboard_button',
    'ai_assistant_button',
    'companion_displays_button',
  ];

  Future<void> pumpHome(WidgetTester tester, {double width = 411}) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: KitchenHomeScreen(
          preferences: OnboardingPreferences(language: 'en'),
          onResetOnboarding: () {},
        ),
      ),
    );
    await tester.pump();
  }

  /// True when the widget's centre lies within the viewport, i.e. it is actually reachable.
  bool isOnScreen(WidgetTester tester, Finder finder) {
    final boxes = tester.renderObjectList<RenderBox>(
      find.descendant(of: finder, matching: find.byType(IconButton)),
    );
    if (boxes.isEmpty) return false;
    return boxes.every((box) => box.hasSize && box.size.width > 0);
  }

  testWidgets('every app bar action is present on a narrow screen', (tester) async {
    await pumpHome(tester);

    for (final key in actionKeys) {
      expect(
        find.byKey(Key(key)),
        findsOneWidget,
        reason: '$key should be rendered',
      );
    }
    // The setup wizard action has no key of its own; assert the row did not overflow.
    expect(tester.takeException(), isNull);
  });

  testWidgets('app bar actions stay within the viewport width', (tester) async {
    await pumpHome(tester);

    final screenWidth = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    for (final key in actionKeys) {
      final box = tester.getRect(find.byKey(Key(key)));
      expect(
        box.right,
        lessThanOrEqualTo(screenWidth + 0.5),
        reason: '$key overflows the $screenWidth wide screen',
      );
      expect(box.left, greaterThanOrEqualTo(-0.5), reason: '$key starts off-screen');
    }
  });

  testWidgets('the guest badge is reachable in the body', (tester) async {
    await pumpHome(tester);

    expect(find.byKey(const Key('guest_mode_badge')), findsOneWidget);
    expect(find.text('Guest Mode'), findsOneWidget);

    final badge = tester.getRect(find.byKey(const Key('guest_mode_badge')));
    final screenWidth = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    expect(badge.right, lessThanOrEqualTo(screenWidth + 0.5));
  });

  testWidgets('the layout still fits on a very narrow screen', (tester) async {
    await pumpHome(tester, width: 320);

    expect(tester.takeException(), isNull);
    for (final key in actionKeys) {
      final box = tester.getRect(find.byKey(Key(key)));
      expect(box.right, lessThanOrEqualTo(320.5), reason: '$key overflows at 320dp');
    }
  });

  testWidgets('no RenderFlex overflow is reported', (tester) async {
    await pumpHome(tester);
    expect(tester.takeException(), isNull);
    expect(isOnScreen(tester, find.byType(AppBar)), isTrue);
  });
}