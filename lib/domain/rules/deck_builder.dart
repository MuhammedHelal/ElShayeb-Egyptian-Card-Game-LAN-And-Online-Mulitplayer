/// Domain Layer - Deck Builder
///
/// Creates the El-Shayeb deck: standard 52-card deck with 3 Kings removed.
/// Only ONE King (the Shayeb) remains in the deck.
library;

import 'dart:math';
import '../entities/card.dart';

/// Builds and manages the El-Shayeb deck
class DeckBuilder {
  final Random _random;

  DeckBuilder({Random? random}) : _random = random ?? Random();

  /// Creates the El-Shayeb deck (49 cards: 52 - 3 Kings)
  /// The Shayeb (single King) is kept, all other Kings are removed.
  List<PlayingCard> createDeck() {
    final List<PlayingCard> deck = [];

    // Track which King we'll keep (randomly chosen)
    final shayebSuit = Suit.values[_random.nextInt(Suit.values.length)];

    for (final suit in Suit.values) {
      for (final rank in Rank.values) {
        // Skip Kings except for the Shayeb suit
        if (rank == Rank.king && suit != shayebSuit) {
          continue;
        }
        deck.add(PlayingCard.create(suit, rank));
      }
    }

    return deck;
  }

  /// Shuffles the deck using Fisher-Yates algorithm
  List<PlayingCard> shuffle(List<PlayingCard> deck) {
    final shuffled = List<PlayingCard>.from(deck);

    for (int i = shuffled.length - 1; i > 0; i--) {
      final j = _random.nextInt(i + 1);
      final temp = shuffled[i];
      shuffled[i] = shuffled[j];
      shuffled[j] = temp;
    }

    return shuffled;
  }

  /// Creates and shuffles a new deck
  List<PlayingCard> createShuffledDeck() {
    return shuffle(createDeck());
  }
}
