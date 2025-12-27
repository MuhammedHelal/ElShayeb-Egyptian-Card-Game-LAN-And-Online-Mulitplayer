/// Domain Layer - Game Rules Engine
///
/// PURE Dart implementation of El-Shayeb game rules.
/// This class contains NO Flutter dependencies and can be reused anywhere.
/// All game logic is centralized here - UI and networking NEVER decide rules.
library;

import 'dart:math';
import '../entities/entities.dart';
import 'deck_builder.dart';

/// Scoring configuration for El-Shayeb
class ScoringConfig {
  static const Map<int, int> positionScores = {
    1: 100, // 1st place
    2: 60, // 2nd place
    3: 40, // 3rd place
    4: 20, // 4th place
    5: 10, // 5th place
  };

  static const int shayebPenalty = -50; // Last place (Shayeb)
}

/// Result of dealing cards
class DealResult {
  final List<Player> players;

  const DealResult({required this.players});
}

/// Result of a draw action
class DrawResult {
  final bool success;
  final PlayingCard? drawnCard;
  final bool madeMatch;
  final PlayingCard? matchedCard;
  final Player updatedDrawer;
  final Player updatedTarget;
  final String? error;

  const DrawResult({
    required this.success,
    this.drawnCard,
    this.madeMatch = false,
    this.matchedCard,
    required this.updatedDrawer,
    required this.updatedTarget,
    this.error,
  });

  factory DrawResult.failure(String error, Player drawer, Player target) {
    return DrawResult(
      success: false,
      error: error,
      updatedDrawer: drawer,
      updatedTarget: target,
    );
  }
}

/// Pure Dart game rules engine for El-Shayeb
class GameRulesEngine {
  final DeckBuilder _deckBuilder;
  final Random _random;

  GameRulesEngine({
    DeckBuilder? deckBuilder,
    Random? random,
  })  : _deckBuilder = deckBuilder ?? DeckBuilder(),
        _random = random ?? Random();

  /// Validates if a player can join the game
  bool canPlayerJoin(GameState state, String playerId) {
    // Allow joining in lobby or during gameplay (late join)
    if (state.isFull) return false;
    if (state.players.any((p) => p.id == playerId)) return false;
    return true;
  }

  /// Adds a player to the game
  GameState addPlayer(GameState state, Player player) {
    if (!canPlayerJoin(state, player.id)) return state;

    // If game is already in progress, add player as spectator/waiting
    final playerToAdd = state.phase == GamePhase.lobby
        ? player
        : player.copyWith(
            status: PlayerStatus.waiting,
            hand: const [],
          );

    return state.copyWith(
      players: [...state.players, playerToAdd],
    );
  }

  /// Removes a player from the game
  GameState removePlayer(GameState state, String playerId) {
    final players = state.players.where((p) => p.id != playerId).toList();

    // Adjust current player index if needed
    int newIndex = state.currentPlayerIndex;
    final removedIndex = state.players.indexWhere((p) => p.id == playerId);
    if (removedIndex >= 0 && removedIndex < state.currentPlayerIndex) {
      newIndex = (newIndex - 1).clamp(0, players.length - 1);
    } else if (newIndex >= players.length) {
      newIndex = 0;
    }

    return state.copyWith(
      players: players,
      currentPlayerIndex: newIndex,
    );
  }

  /// Deals cards to all players
  /// Cards are dealt one by one until deck is empty
  DealResult dealCards(List<Player> players) {
    if (players.isEmpty) {
      return DealResult(players: players);
    }

    // Create and shuffle deck
    final deck = _deckBuilder.createShuffledDeck();

    // Initialize empty hands for each player
    final hands = List<List<PlayingCard>>.generate(
      players.length,
      (_) => [],
    );

    // Deal one card at a time to each player
    int playerIndex = 0;
    for (final card in deck) {
      hands[playerIndex].add(card);
      playerIndex = (playerIndex + 1) % players.length;
    }

    // Remove initial pairs from each hand
    final updatedPlayers = <Player>[];
    for (int i = 0; i < players.length; i++) {
      final handAfterPairs = _removeAllPairs(hands[i]);
      updatedPlayers.add(players[i].copyWith(hand: handAfterPairs));
    }

    return DealResult(players: updatedPlayers);
  }

  /// Removes all matching pairs from a hand
  List<PlayingCard> _removeAllPairs(List<PlayingCard> hand) {
    final rankCounts = <Rank, List<PlayingCard>>{};

    // Group cards by rank
    for (final card in hand) {
      rankCounts.putIfAbsent(card.rank, () => []).add(card);
    }

    // Keep only cards that don't have a pair
    final remaining = <PlayingCard>[];
    for (final cards in rankCounts.values) {
      // If odd number of cards, one remains
      if (cards.length % 2 == 1) {
        remaining.add(cards.last);
      }
      // If even, all pairs are removed
    }

    // Shuffle the remaining cards to prevent predictability
    remaining.shuffle(_random);

    return remaining;
  }

  /// Validates if a draw action is legal
  bool isValidDraw(GameState state, String drawerId, String targetId) {
    // Must be in playing phase
    if (state.phase != GamePhase.playing) return false;

    // Must be drawer's turn
    if (state.currentPlayer?.id != drawerId) return false;

    // Drawer must be playing
    final drawer = state.getPlayerById(drawerId);
    if (drawer == null || !drawer.isPlaying) return false;

    // Target must be playing and have cards
    final target = state.getPlayerById(targetId);
    if (target == null || !target.isPlaying) return false;
    if (target.hand.isEmpty) return false;

    // Can't draw from self
    if (drawerId == targetId) return false;

    return true;
  }

  /// Executes a draw action: drawer takes a random card from target
  DrawResult executeDraw(
    GameState state,
    String drawerId,
    String targetId, {
    int? cardIndex, // Optional: for testing or specific card selection
  }) {
    final drawer = state.getPlayerById(drawerId)!;
    final target = state.getPlayerById(targetId)!;

    if (!isValidDraw(state, drawerId, targetId)) {
      return DrawResult.failure(
        'Invalid draw action',
        drawer,
        target,
      );
    }

    // Select random card from target's hand
    final index = cardIndex ?? _random.nextInt(target.hand.length);
    final drawnCard = target.hand[index];

    // Remove card from target
    final newTargetHand = List<PlayingCard>.from(target.hand)..removeAt(index);

    // Add card to drawer's hand
    var newDrawerHand = List<PlayingCard>.from(drawer.hand)..add(drawnCard);

    // Check for matching pair
    PlayingCard? matchedCard;
    bool madeMatch = false;

    for (final card in drawer.hand) {
      if (card.matchesByRank(drawnCard) && card.id != drawnCard.id) {
        matchedCard = card;
        madeMatch = true;
        // Remove both cards
        newDrawerHand = newDrawerHand
            .where((c) => c.id != drawnCard.id && c.id != matchedCard!.id)
            .toList();
        break;
      }
    }

    // Shuffle the final hand to keep positions unpredictable
    newDrawerHand.shuffle(_random);

    return DrawResult(
      success: true,
      drawnCard: drawnCard,
      madeMatch: madeMatch,
      matchedCard: matchedCard,
      updatedDrawer: drawer.copyWith(hand: newDrawerHand),
      updatedTarget: target.copyWith(hand: newTargetHand),
    );
  }

  /// Applies a draw result to the game state
  GameState applyDrawResult(GameState state, DrawResult result) {
    if (!result.success) return state;

    // Update players with new hands
    var players = state.players.map((p) {
      if (p.id == result.updatedDrawer.id) return result.updatedDrawer;
      if (p.id == result.updatedTarget.id) return result.updatedTarget;
      return p;
    }).toList();

    // Check for players who finished
    int nextPosition = state.nextFinishPosition;
    players = players.map((p) {
      if (p.isPlaying && p.hand.isEmpty) {
        return p.copyWith(
          status: PlayerStatus.finished,
          finishPosition: nextPosition++,
        );
      }
      return p;
    }).toList();

    // Move to next player
    int nextPlayerIndex = state.getNextPlayerIndex();

    // Check if round is over
    final playingPlayers = players.where((p) => p.isPlaying).toList();
    GamePhase newPhase = state.phase;

    if (playingPlayers.length <= 1) {
      // Mark last player as Shayeb
      if (playingPlayers.length == 1) {
        players = players.map((p) {
          if (p.id == playingPlayers.first.id) {
            return p.copyWith(
              status: PlayerStatus.shayeb,
              finishPosition: nextPosition,
            );
          }
          return p;
        }).toList();
      }
      newPhase = GamePhase.roundEnd;
    }

    return state.copyWith(
      players: players,
      currentPlayerIndex: nextPlayerIndex,
      phase: newPhase,
      nextFinishPosition: nextPosition,
      lastAction: result.madeMatch
          ? '${result.updatedDrawer.name} made a pair!'
          : '${result.updatedDrawer.name} drew a card',
      lastActionTime: DateTime.now(),
    );
  }

  /// Calculates scores for a completed round
  Map<String, int> calculateRoundScores(List<Player> players) {
    final scores = <String, int>{};

    for (final player in players) {
      if (player.isShayeb) {
        scores[player.id] = ScoringConfig.shayebPenalty;
      } else if (player.finishPosition > 0) {
        scores[player.id] =
            ScoringConfig.positionScores[player.finishPosition] ?? 0;
      }
    }

    return scores;
  }

  /// Applies round scores to players
  GameState applyRoundScores(GameState state) {
    final roundScores = calculateRoundScores(state.players);

    final players = state.players.map((p) {
      final scoreChange = roundScores[p.id] ?? 0;
      return p.copyWith(score: p.score + scoreChange);
    }).toList();

    return state.copyWith(players: players);
  }

  /// Starts a new round
  GameState startNewRound(GameState state) {
    // Reset player statuses but keep scores
    // Activate any waiting players (late joiners)
    var players = state.players.map((p) {
      return p.copyWith(
        status: PlayerStatus.playing,
        finishPosition: 0,
        hand: const [],
      );
    }).toList();

    // Deal cards
    final dealResult = dealCards(players);

    return state.copyWith(
      players: dealResult.players,
      phase: GamePhase.playing,
      roundNumber: state.roundNumber + 1,
      currentPlayerIndex: 0,
      nextFinishPosition: 1,
      lastAction: 'New round started!',
      lastActionTime: DateTime.now(),
    );
  }

  /// Starts the game from lobby
  GameState startGame(GameState state) {
    if (!state.canStart) return state;

    // Deal cards to all players
    final dealResult = dealCards(state.players);

    return state.copyWith(
      players: dealResult.players,
      phase: GamePhase.playing,
      currentPlayerIndex: 0,
      nextFinishPosition: 1,
      lastAction: 'Game started!',
      lastActionTime: DateTime.now(),
    );
  }

  /// Shuffles a player's hand randomly
  Player shufflePlayerHand(Player player) {
    final shuffledHand = List<PlayingCard>.from(player.hand)..shuffle(_random);
    return player.copyWith(hand: shuffledHand);
  }

  /// Generates a random room code (4 uppercase letters)
  String generateRoomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    return List.generate(4, (_) => chars[_random.nextInt(chars.length)]).join();
  }
}
