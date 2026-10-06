import 'package:elshayeb/domain/entities/card.dart';
import 'package:elshayeb/domain/entities/player.dart';
import 'package:elshayeb/presentation/widgets/overlays/card_reveal_overlay.dart';
import 'package:elshayeb/presentation/widgets/overlays/dealing_animation_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('starts the match animation when reveal advances to match',
      (tester) async {
    const drawnCard = PlayingCard(
      id: 'spades_7',
      suit: Suit.spades,
      rank: Rank.seven,
    );
    const matchedCard = PlayingCard(
      id: 'hearts_7',
      suit: Suit.hearts,
      rank: Rank.seven,
    );

    await tester.pumpWidget(const MaterialApp(
      home: CardRevealOverlay(
        drawnCard: drawnCard,
        matchedCard: matchedCard,
      ),
    ));
    await tester.pump(const Duration(milliseconds: 600));

    await tester.pumpWidget(const MaterialApp(
      home: CardRevealOverlay(
        drawnCard: drawnCard,
        matchedCard: matchedCard,
        showMatch: true,
      ),
    ));
    await tester.pump(const Duration(milliseconds: 600));

    final opacities = tester
        .widgetList<Opacity>(find.byType(Opacity))
        .map((widget) => widget.opacity);
    expect(opacities.any((opacity) => opacity < 1), isTrue);
  });

  testWidgets('does not complete dealing after the overlay is disposed',
      (tester) async {
    var completed = false;
    const players = [
      Player(id: 'user-1', name: 'One', avatarId: 'default'),
      Player(id: 'user-2', name: 'Two', avatarId: 'default'),
    ];

    await tester.pumpWidget(MaterialApp(
      home: DealingAnimationOverlay(
        players: players,
        localPlayerId: 'user-1',
        onComplete: () => completed = true,
      ),
    ));
    await tester.pump(const Duration(milliseconds: 2600));
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump(const Duration(seconds: 1));

    expect(completed, isFalse);
  });
}
