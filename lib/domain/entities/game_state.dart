/// Domain Layer - Game State Entity
///
/// Represents the complete state of an El-Shayeb game.
/// This is the authoritative state used by the host and synchronized to clients.
library;

import 'package:equatable/equatable.dart';
import 'player.dart';

/// Phases of the game
enum GamePhase {
  /// Waiting for players to join
  lobby,

  /// Cards are being dealt
  dealing,

  /// Game is in progress
  playing,

  /// Round has ended, showing results
  roundEnd,

  /// Game has ended completely
  gameEnd,
}

/// Immutable game state entity
class GameState extends Equatable {
  final String roomId;
  final String roomCode;
  final List<Player> players;
  final int currentPlayerIndex;
  final GamePhase phase;
  final int roundNumber;
  final int nextFinishPosition;
  final String? lastAction;
  final DateTime? lastActionTime;
  final String hostId;

  const GameState({
    required this.roomId,
    required this.roomCode,
    required this.players,
    this.currentPlayerIndex = 0,
    this.phase = GamePhase.lobby,
    this.roundNumber = 1,
    this.nextFinishPosition = 1,
    this.lastAction,
    this.lastActionTime,
    required this.hostId,
  });

  /// Get the current player whose turn it is
  Player? get currentPlayer {
    if (players.isEmpty || currentPlayerIndex >= players.length) return null;
    return players[currentPlayerIndex];
  }

  /// Get player by ID
  Player? getPlayerById(String id) {
    try {
      return players.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Get the index of the next player who is still playing
  int getNextPlayerIndex() {
    if (players.isEmpty) return 0;

    int nextIndex = (currentPlayerIndex + 1) % players.length;
    int attempts = 0;

    while (attempts < players.length) {
      if (players[nextIndex].isPlaying) {
        return nextIndex;
      }
      nextIndex = (nextIndex + 1) % players.length;
      attempts++;
    }

    return currentPlayerIndex;
  }

  /// Get the player from whom the current player can draw
  Player? get drawFromPlayer {
    if (players.isEmpty) return null;

    // Find the previous player who is still playing
    int prevIndex = (currentPlayerIndex - 1 + players.length) % players.length;
    int attempts = 0;

    while (attempts < players.length) {
      if (players[prevIndex].isPlaying && players[prevIndex].hand.isNotEmpty) {
        return players[prevIndex];
      }
      prevIndex = (prevIndex - 1 + players.length) % players.length;
      attempts++;
    }

    return null;
  }

  /// Count of players still playing
  int get playersStillPlaying => players.where((p) => p.isPlaying).length;

  /// Check if the round is over
  bool get isRoundOver {
    // Round ends when only one player remains with cards
    final playingPlayers = players.where((p) => p.isPlaying).toList();
    if (playingPlayers.isEmpty) return true;
    if (playingPlayers.length == 1) {
      // The last player is the Shayeb
      return true;
    }
    return false;
  }

  /// Check if game can start
  bool get canStart => players.length >= 2 && phase == GamePhase.lobby;

  /// Check if room is full
  bool get isFull => players.length >= 6;

  /// Create a copy with updated fields
  GameState copyWith({
    String? roomId,
    String? roomCode,
    List<Player>? players,
    int? currentPlayerIndex,
    GamePhase? phase,
    int? roundNumber,
    int? nextFinishPosition,
    String? lastAction,
    DateTime? lastActionTime,
    String? hostId,
  }) {
    return GameState(
      roomId: roomId ?? this.roomId,
      roomCode: roomCode ?? this.roomCode,
      players: players ?? this.players,
      currentPlayerIndex: currentPlayerIndex ?? this.currentPlayerIndex,
      phase: phase ?? this.phase,
      roundNumber: roundNumber ?? this.roundNumber,
      nextFinishPosition: nextFinishPosition ?? this.nextFinishPosition,
      lastAction: lastAction ?? this.lastAction,
      lastActionTime: lastActionTime ?? this.lastActionTime,
      hostId: hostId ?? this.hostId,
    );
  }

  @override
  List<Object?> get props => [
        roomId,
        roomCode,
        players,
        currentPlayerIndex,
        phase,
        roundNumber,
        nextFinishPosition,
        lastAction,
        lastActionTime,
        hostId,
      ];

  /// Convert to JSON for network serialization
  Map<String, dynamic> toJson() => {
        'roomId': roomId,
        'roomCode': roomCode,
        'players': players.map((p) => p.toJson()).toList(),
        'currentPlayerIndex': currentPlayerIndex,
        'phase': phase.index,
        'roundNumber': roundNumber,
        'nextFinishPosition': nextFinishPosition,
        'lastAction': lastAction,
        'lastActionTime': lastActionTime?.toIso8601String(),
        'hostId': hostId,
      };

  /// Create from JSON for network deserialization
  factory GameState.fromJson(Map<String, dynamic> json) {
    return GameState(
      roomId: json['roomId'] as String,
      roomCode: json['roomCode'] as String,
      players: (json['players'] as List<dynamic>?)
              ?.map((p) => Player.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
      currentPlayerIndex: json['currentPlayerIndex'] as int,
      phase: GamePhase.values[json['phase'] as int],
      roundNumber: json['roundNumber'] as int,
      nextFinishPosition: json['nextFinishPosition'] as int,
      lastAction: json['lastAction'] as String?,
      lastActionTime: json['lastActionTime'] != null
          ? DateTime.parse(json['lastActionTime'] as String)
          : null,
      hostId: json['hostId'] as String,
    );
  }

  /// Create initial empty game state
  factory GameState.initial({
    required String roomId,
    required String roomCode,
    required String hostId,
  }) {
    return GameState(
      roomId: roomId,
      roomCode: roomCode,
      players: const [],
      hostId: hostId,
    );
  }
}
