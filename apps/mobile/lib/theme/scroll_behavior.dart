import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Scroll behaviour with the elastic overscroll removed.
///
/// Flutter's defaults add a rubber-band stretch on iOS and a glowing edge on Android, which
/// makes a pull-to-refresh gesture look like the surface itself is stretching. For a
/// kitchen app used one-handed with wet hands, that elasticity reads as the UI misbehaving
/// rather than as feedback, so both effects are suppressed: overscroll draws nothing and
/// every platform clamps instead of bouncing.
///
/// [RefreshIndicator] still works — it is a child gesture detector, not an overscroll
/// effect — so pull-to-refresh keeps functioning while looking static.
class NoElasticScrollBehavior extends ScrollBehavior {
  const NoElasticScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
    PointerDeviceKind.unknown,
  };

  /// Draws no overscroll affordance: no Android edge glow, no iOS stretch shadow.
  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

  /// Clamping on every platform removes the iOS rubber band without disabling scrolling.
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics();
  }
}