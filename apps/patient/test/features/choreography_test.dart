import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:apnedoctors/features/opening/opening_choreography.dart';
import 'package:apnedoctors/features/opening/opening_spec.g.dart';

/// The opening must land on the board's numbers at every beat (docs/design/kalighat-pop/gen/splash.py).
void main() {
  final board = OpeningChoreography(screen: const Size(390, 844));

  test('starts where the native splash leaves the a: scale 1, bounds centred', () {
    final p = board.aPose(0);
    expect(p.scale, 1);
    // bounds centre (9.5, 1) in a units sits on the screen centre (195, 422)
    expect(p.bowl.dx + 9.5, closeTo(195, 1e-9));
    expect(p.bowl.dy + 1, closeTo(422, 1e-9));
  });

  test('hero pose when the alpana blooms (0.55 s)', () {
    final p = board.aPose(OpeningSpec.expand);
    expect(p.bowl.dx, closeTo(OpeningSpec.heroBx, .01));
    expect(p.bowl.dy, closeTo(OpeningSpec.heroBy, .01));
    expect(p.scale, closeTo(1.4, 1e-6));
  });

  test('becomes the first letter of the name (2.8 s)', () {
    final p = board.aPose(OpeningSpec.moveEnd);
    expect(p.bowl.dx, closeTo(67.45, .01));
    expect(p.bowl.dy, closeTo(408.16, .01));
    expect(p.scale, closeTo(.4687, 1e-4));
  });

  test('glides to the doorway on the board (6.5 s) and waits at the centre line', () {
    final p = board.aPose(OpeningSpec.glideEnd);
    expect(p.bowl.dx, closeTo(182.7, .01));
    expect(p.bowl.dy, closeTo(432, .01));
    expect(p.scale, closeTo(1.05, 1e-9));
    expect(board.push, closeTo(105.28, .01));
  });

  test('the doorway waits until the rising headline pushes it into place', () {
    expect(board.heroOffset(OpeningSpec.handRise), closeTo(board.push, .01));
    expect(board.heroOffset(OpeningSpec.handRise + OpeningSpec.riseDuration), closeTo(0, 1e-9));
  });

  test('on other screens the a lands on the measured doorway', () {
    const screen = Size(360, 640);
    final c = OpeningChoreography(
      screen: screen,
      doorway: const DoorwayTarget(bowl: Offset(170, 200), scale: .52),
    );
    final p = c.aPose(OpeningSpec.glideEnd);
    // board space is centred: x offset (360 - 390) / 2, y offset 640 / 2 - 422
    expect(p.bowl.dx + c.boardOffset.dx, closeTo(170, 1e-9));
    expect(p.scale, closeTo(.52, 1e-9));
    expect(p.bowl.dy + c.boardOffset.dy, closeTo(330, 1e-9), reason: 'waits 10 px below the screen centre');
    expect(c.push, closeTo(130, 1e-9));
  });

  test('the overlay a hands over to the doorway a at the swap', () {
    expect(board.aOpacity(OpeningSpec.swap - .01), 1);
    expect(board.aOpacity(OpeningSpec.swap + .02), 0);
  });

  test('eyes: happy when touched, awake at 1.35 s, smiling again at 4.3 s', () {
    expect(board.aFace(.5).happy, 1);
    expect(board.aFace(.5).open, 0);
    expect(board.aFace(1.5).open, 1);
    expect(board.aFace(4.4).happy, 1);
  });
}
