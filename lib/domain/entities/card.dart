/// Domain Layer - Card Entity
///
/// Represents a single playing card in the El-Shayeb game.
/// Cards are immutable value objects identified by their suit and rank.
library;

import 'package:equatable/equatable.dart';

/// Card suits available in the game
enum Suit {
  hearts,
  diamonds,
  clubs,
  spades;

  String get symbol {
    switch (this) {
      case Suit.hearts:
        return '♥';
      case Suit.diamonds:
        return '♦';
      case Suit.clubs:
        return '♣';
      case Suit.spades:
        return '♠';
    }
  }

  String get name {
    switch (this) {
      case Suit.hearts:
        return 'H';
      case Suit.diamonds:
        return 'D';
      case Suit.clubs:
        return 'C';
      case Suit.spades:
        return 'S';
    }
  }

  bool get isRed => this == Suit.hearts || this == Suit.diamonds;
}

/// Card ranks in order from Ace to King
enum Rank {
  ace,
  two,
  three,
  four,
  five,
  six,
  seven,
  eight,
  nine,
  ten,
  jack,
  queen,
  king;

  int get value {
    switch (this) {
      case Rank.ace:
        return 1;
      case Rank.two:
        return 2;
      case Rank.three:
        return 3;
      case Rank.four:
        return 4;
      case Rank.five:
        return 5;
      case Rank.six:
        return 6;
      case Rank.seven:
        return 7;
      case Rank.eight:
        return 8;
      case Rank.nine:
        return 9;
      case Rank.ten:
        return 10;
      case Rank.jack:
        return 11;
      case Rank.queen:
        return 12;
      case Rank.king:
        return 13;
    }
  }

  String get symbol {
    switch (this) {
      case Rank.ace:
        return 'A';
      case Rank.two:
        return '2';
      case Rank.three:
        return '3';
      case Rank.four:
        return '4';
      case Rank.five:
        return '5';
      case Rank.six:
        return '6';
      case Rank.seven:
        return '7';
      case Rank.eight:
        return '8';
      case Rank.nine:
        return '9';
      case Rank.ten:
        return '10';
      case Rank.jack:
        return 'J';
      case Rank.queen:
        return 'Q';
      case Rank.king:
        return 'K';
    }
  }

  String get fullName {
    switch (this) {
      case Rank.ace:
        return 'ace';
      case Rank.two:
        return 'two';
      case Rank.three:
        return 'three';
      case Rank.four:
        return 'four';
      case Rank.five:
        return 'five';
      case Rank.six:
        return 'six';
      case Rank.seven:
        return 'seven';
      case Rank.eight:
        return 'eight';
      case Rank.nine:
        return 'nine';
      case Rank.ten:
        return 'ten';
      case Rank.jack:
        return 'jack';
      case Rank.queen:
        return 'queen';
      case Rank.king:
        return 'king';
    }
  }
}

/// Immutable playing card entity
class PlayingCard extends Equatable {
  final Suit suit;
  final Rank rank;
  final String id;

  const PlayingCard({
    required this.suit,
    required this.rank,
    required this.id,
  });

  /// Creates a unique ID for a card based on suit and rank
  factory PlayingCard.create(Suit suit, Rank rank) {
    return PlayingCard(
      suit: suit,
      rank: rank,
      id: '${suit.name}_${rank.fullName}',
    );
  }

  /// Check if this card matches another card by rank (for pairing)
  bool matchesByRank(PlayingCard other) => rank == other.rank;

  /// Check if this card is the Shayeb (the single King kept in the game)
  bool get isShayeb => rank == Rank.king;

  /// Display name for the card
  String get displayName => '${rank.symbol}${suit.symbol}';

  /// Asset path for the card SVG
  String get assetPath => 'assets/cards/${rank.symbol}${suit.name}.svg';

  @override
  List<Object?> get props => [suit, rank, id];

  @override
  String toString() => displayName;

  /// Convert to JSON for network serialization
  Map<String, dynamic> toJson() => {
        'suit': suit.index,
        'rank': rank.index,
        'id': id,
      };

  /// Create from JSON for network deserialization
  factory PlayingCard.fromJson(Map<String, dynamic> json) {
    return PlayingCard(
      suit: Suit.values[json['suit'] as int],
      rank: Rank.values[json['rank'] as int],
      id: json['id'] as String,
    );
  }
}
