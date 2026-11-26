import 'package:flutter/widgets.dart';

/// Where the living "a" stood in Welcome's doorway when someone tapped a door: the next screen picks it up from
/// exactly there and carries it to its new place (the walk through the doorway).
@immutable
class AFlightStart {
  const AFlightStart({required this.bowl, required this.scale});

  /// The centre of the a's bowl, in global (screen) coordinates.
  final Offset bowl;

  /// The a's scale in logo units: its bowl radius is 45 × [scale] px.
  final double scale;
}

/// Welcome writes the a's place here as a door is tapped; the router hands it to the next screen.
abstract final class DoorwayHandOff {
  static AFlightStart? _last;

  static void leave(AFlightStart start) => _last = start;

  /// The place, once (a later open without a tap starts fresh).
  static AFlightStart? take() {
    final s = _last;
    _last = null;
    return s;
  }
}
