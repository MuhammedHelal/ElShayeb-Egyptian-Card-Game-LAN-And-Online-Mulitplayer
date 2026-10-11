import 'dart:math' as math;

import 'package:elshayeb/domain/entities/player.dart';
import 'package:elshayeb/presentation/widgets/common/playing_card_widget.dart';
import 'package:elshayeb/presentation/widgets/overlays/dealing_animation_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _players = [
  Player(id: 'one', name: 'One', avatarId: 'default'),
  Player(id: 'two', name: 'Two', avatarId: 'default'),
  Player(id: 'three', name: 'Three', avatarId: 'default'),
];

Widget _overlay({
  List<Player> players = _players,
  String? localPlayerId = 'one',
  VoidCallback? onComplete,
}) {
  return MaterialApp(
    home: Center(
      child: SizedBox(
        width: 600,
        height: 600,
        child: DealingAnimationOverlay(
          players: players,
          localPlayerId: localPlayerId,
          onComplete: onComplete ?? () {},
        ),
      ),
    ),
  );
}

Offset _flightOffset(WidgetTester tester, int slot) {
  final transform = tester.widget<Transform>(
    find
        .descendant(
          of: find.byKey(ValueKey('dealing-card-$slot')),
          matching: find.byType(Transform),
        )
        .first,
  );
  return Offset(
      transform.transform.storage[12], transform.transform.storage[13]);
}

double _flightOpacity(WidgetTester tester, int slot) {
  return tester
      .widget<Opacity>(find
          .descendant(
            of: find.byKey(ValueKey('dealing-card-$slot')),
            matching: find.byType(Opacity),
          )
          .first)
      .opacity;
}

void main() {
  testWidgets(
      'flights keep moving toward the correct seat after slots are reused',
      (tester) async {
    await tester.pumpWidget(_overlay());
    final cardStates = tester
        .stateList(find.byType(PlayingCardWidget))
        .toList(growable: false);

    await tester.pump(const Duration(milliseconds: 700));
    // The eleventh card started at 550ms and travels to the second player.
    const radius = 195.0;
    final target = Offset(radius * math.cos(math.pi / 6), radius / 2);
    final before = _flightOffset(tester, 0);
    final expected = target * Curves.easeOut.transform(0.3);
    expect(before.dx, closeTo(expected.dx, 0.001));
    expect(before.dy, closeTo(expected.dy, 0.001));

    await tester.pump(const Duration(milliseconds: 16));
    final after = _flightOffset(tester, 0);
    expect(after.dx, greaterThan(before.dx));
    expect(after.dy, greaterThan(before.dy));
    expect(
      tester.stateList(find.byType(PlayingCardWidget)).toList(),
      orderedEquals(cardStates),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a delayed frame keeps dealing and movement on the same timeline',
      (tester) async {
    await tester.pumpWidget(_overlay(localPlayerId: 'two'));
    await tester.pump(const Duration(milliseconds: 1200));

    // Card 21 started at 1050ms, targets player three, and is 30% through
    // its flight. Local player two occupies the first seat.
    const radius = 195.0;
    final target = Offset(radius * math.cos(math.pi / 6), radius / 2);
    final expected = target * Curves.easeOut.transform(0.3);
    final offset = _flightOffset(tester, 0);
    expect(_flightOpacity(tester, 0), 1);
    expect(offset.dx, closeTo(expected.dx, 0.001));
    expect(offset.dy, closeTo(expected.dy, 0.001));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('finishes once, after the last of 49 cards has landed',
      (tester) async {
    var completions = 0;
    await tester.pumpWidget(_overlay(onComplete: () => completions++));

    await tester.pump(const Duration(milliseconds: 2940));
    expect(_flightOpacity(tester, 8), 1);
    expect(completions, 0);

    await tester.pump(const Duration(milliseconds: 11));
    for (var slot = 0; slot < 10; slot++) {
      expect(_flightOpacity(tester, slot), 0);
    }
    expect(completions, 0);

    await tester.pump(const Duration(milliseconds: 150));
    expect(completions, 1);
    await tester.pump(const Duration(seconds: 1));
    expect(completions, 1);
  });

  testWidgets('an empty player list completes without starting a flight',
      (tester) async {
    var completions = 0;
    await tester.pumpWidget(_overlay(
      players: const [],
      onComplete: () => completions++,
    ));

    expect(tester.takeException(), isNull);
    expect(find.byType(PlayingCardWidget), findsNothing);
    expect(completions, 1);
    await tester.pump(const Duration(seconds: 4));
    expect(completions, 1);
  });
}
