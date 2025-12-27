/// Domain Layer - Player Entity
///
/// Represents a player in the El-Shayeb game.
/// Tracks player identity, hand, score, and game status.
library;

import 'package:equatable/equatable.dart';
import 'card.dart';

/// Player status in the current round
enum PlayerStatus {
  /// Player is still in the game
  playing,

  /// Player has finished (no cards left)
  finished,

  /// Player is the Shayeb (last one with the King)
  shayeb,

  /// Player is waiting to join (late joiner, will play next round)
  waiting,
}

/// Immutable player entity
class Player extends Equatable {
  final String id;
  final String name;
  final String avatarId;
  final List<PlayingCard> hand;
  final int score;
  final PlayerStatus status;
  final int finishPosition; // 0 = not finished, 1 = first, 2 = second, etc.
  final bool isHost;
  final bool isConnected;

  const Player({
    required this.id,
    required this.name,
    required this.avatarId,
    this.hand = const [],
    this.score = 0,
    this.status = PlayerStatus.playing,
    this.finishPosition = 0,
    this.isHost = false,
    this.isConnected = true,
  });

  /// Number of cards in hand
  int get cardCount => hand.length;

  /// Check if player has finished (no cards)
  bool get hasFinished => status == PlayerStatus.finished;

  /// Check if player is the Shayeb loser
  bool get isShayeb => status == PlayerStatus.shayeb;

  /// Check if player is still playing
  bool get isPlaying => status == PlayerStatus.playing;

  /// Create a copy with updated fields
  Player copyWith({
    String? id,
    String? name,
    String? avatarId,
    List<PlayingCard>? hand,
    int? score,
    PlayerStatus? status,
    int? finishPosition,
    bool? isHost,
    bool? isConnected,
  }) {
    return Player(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarId: avatarId ?? this.avatarId,
      hand: hand ?? this.hand,
      score: score ?? this.score,
      status: status ?? this.status,
      finishPosition: finishPosition ?? this.finishPosition,
      isHost: isHost ?? this.isHost,
      isConnected: isConnected ?? this.isConnected,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        avatarId,
        hand,
        score,
        status,
        finishPosition,
        isHost,
        isConnected,
      ];

  /// Convert to JSON for network serialization
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'avatarId': avatarId,
        'hand': hand.map((c) => c.toJson()).toList(),
        'score': score,
        'status': status.index,
        'finishPosition': finishPosition,
        'isHost': isHost,
        'isConnected': isConnected,
      };

  /// Create from JSON for network deserialization
  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      id: json['id'] as String,
      name: json['name'] as String,
      avatarId: json['avatarId'] as String,
      hand: (json['hand'] as List<dynamic>)
          .map((c) => PlayingCard.fromJson(c as Map<String, dynamic>))
          .toList(),
      score: json['score'] as int,
      status: PlayerStatus.values[json['status'] as int],
      finishPosition: json['finishPosition'] as int,
      isHost: json['isHost'] as bool,
      isConnected: json['isConnected'] as bool,
    );
  }

  /// Create from minimal join data (for online presence join events)
  /// Only requires id, name, avatarId - other fields have defaults
  factory Player.fromJoinData(Map<String, dynamic> json) {
    return Player(
      id: json['id'] as String? ?? json['player_id'] as String? ?? '',
      name: json['name'] as String? ?? 'Player',
      avatarId: json['avatarId'] as String? ?? 'avatar_1',
      hand: const [],
      score: 0,
      status: PlayerStatus.playing,
      finishPosition: 0,
      isHost: json['isHost'] as bool? ?? false,
      isConnected: true,
    );
  }
}
