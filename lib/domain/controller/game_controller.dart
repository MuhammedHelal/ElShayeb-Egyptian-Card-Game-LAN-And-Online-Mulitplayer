/// Application Layer - Game Controller
///
/// Orchestrates game flow between rules engine and networking.
/// This is the central coordinator that doesn't contain game logic itself
/// but delegates to the rules engine for all decisions.
library;

import 'dart:developer';

import '../entities/entities.dart';
import '../rules/rules.dart';
import '../../data/network/network_manager.dart';

/// Game events that can occur
enum GameEventType {
  playerJoined,
  playerLeft,
  gameStarted,
  cardDealt,
  cardDrawn,
  pairRemoved,
  playerFinished,
  roundEnded,
  gameEnded,
  turnChanged,
  stateSync,
  error,
}

/// A game event for logging and UI feedback
class GameEvent {
  final GameEventType type;
  final String message;
  final Map<String, dynamic>? data;
  final DateTime timestamp;

  GameEvent({
    required this.type,
    required this.message,
    this.data,
  }) : timestamp = DateTime.now();
}

/// Callback type for game events
typedef GameEventCallback = void Function(GameEvent event);

/// Callback type for state updates
typedef StateUpdateCallback = void Function(GameState state);

/// Game controller that coordinates all game components
class GameController {
  final GameRulesEngine _rulesEngine;
  final NetworkManager _networkManager;

  GameState _state;
  final List<GameEventCallback> _eventListeners = [];
  final List<StateUpdateCallback> _stateListeners = [];

  String? _localPlayerId;
  bool _isHost = false;

  GameController({
    required GameRulesEngine rulesEngine,
    required NetworkManager networkManager,
    required GameState initialState,
  })  : _rulesEngine = rulesEngine,
        _networkManager = networkManager,
        _state = initialState {
    // Listen to network state updates
    _networkManager.onStateUpdate = _handleNetworkStateUpdate;
    _networkManager.onPlayerAction = _handlePlayerAction;
    _networkManager.onConnectionChange = _handleConnectionChange;
  }

  /// Current game state
  GameState get state => _state;

  /// Whether this instance is the host
  bool get isHost => _isHost;

  /// Local player ID
  String? get localPlayerId => _localPlayerId;

  /// Local player
  Player? get localPlayer =>
      _localPlayerId != null ? _state.getPlayerById(_localPlayerId!) : null;

  /// Whether it's the local player's turn
  bool get isMyTurn => _state.currentPlayer?.id == _localPlayerId;

  /// Add event listener
  void addEventListener(GameEventCallback callback) {
    _eventListeners.add(callback);
  }

  /// Remove event listener
  void removeEventListener(GameEventCallback callback) {
    _eventListeners.remove(callback);
  }

  /// Add state listener
  void addStateListener(StateUpdateCallback callback) {
    _stateListeners.add(callback);
  }

  /// Remove state listener
  void removeStateListener(StateUpdateCallback callback) {
    _stateListeners.remove(callback);
  }

  /// Emit a game event to all listeners
  void _emitEvent(GameEvent event) {
    for (final listener in _eventListeners) {
      listener(event);
    }
  }

  /// Notify state change to all listeners
  void _notifyStateChange() {
    for (final listener in _stateListeners) {
      listener(_state);
    }
  }

  /// Update state and notify
  void _updateState(GameState newState) {
    _state = newState;
    _notifyStateChange();
  }

  /// Host creates a new game
  Future<void> createGame(Player hostPlayer) async {
    _isHost = true;
    _localPlayerId = hostPlayer.id;

    final roomCode = _rulesEngine.generateRoomCode();
    _state = GameState.initial(
      roomId: hostPlayer.id,
      roomCode: roomCode,
      hostId: hostPlayer.id,
    );

    _state = _rulesEngine.addPlayer(_state, hostPlayer.copyWith(isHost: true));

    await _networkManager.startHosting(_state);

    _emitEvent(GameEvent(
      type: GameEventType.playerJoined,
      message: '${hostPlayer.name} created the room',
      data: {'playerId': hostPlayer.id},
    ));

    _notifyStateChange();
  }

  /// Client joins an existing game
  Future<void> joinGame(Player player, String hostAddress, int port) async {
    _isHost = false;
    _localPlayerId = player.id;

    await _networkManager.connectToHost(hostAddress, port, player);

    _emitEvent(GameEvent(
      type: GameEventType.playerJoined,
      message: '${player.name} is joining...',
      data: {'playerId': player.id},
    ));
  }

  /// Host starts the game
  Future<void> startGame() async {
    if (!_isHost) return;
    if (!_state.canStart) return;

    try {
      _state = _rulesEngine.startGame(_state);

      // Notify local listeners first
      _notifyStateChange();

      _emitEvent(GameEvent(
        type: GameEventType.gameStarted,
        message: 'Game started!',
      ));

      // Then broadcast to clients (async)
      await _networkManager.broadcastState(_state);
    } catch (e) {
      log('Error starting game: $e');
      _emitEvent(GameEvent(
        type: GameEventType.error,
        message: 'Failed to start game: $e',
      ));
    }
  }

  /// Player draws a card (client sends action, host validates and executes)
  /// [cardIndex] - Optional specific card index to draw (if null, random)
  Future<void> drawCard(String targetPlayerId, [int? cardIndex]) async {
    if (_localPlayerId == null) return;

    if (_isHost) {
      // Host executes directly
      _executeDrawAction(_localPlayerId!, targetPlayerId, cardIndex);
    } else {
      // Client sends action to host
      await _networkManager.sendAction({
        'type': 'draw',
        'drawerId': _localPlayerId,
        'targetId': targetPlayerId,
        'cardIndex': cardIndex,
      });
    }
  }

  /// Host executes a draw action
  void _executeDrawAction(String drawerId, String targetId, [int? cardIndex]) {
    if (!_rulesEngine.isValidDraw(_state, drawerId, targetId)) {
      _emitEvent(GameEvent(
        type: GameEventType.error,
        message: 'Invalid draw action',
      ));
      return;
    }

    final result = _rulesEngine.executeDraw(_state, drawerId, targetId,
        cardIndex: cardIndex);

    if (result.success) {
      _state = _rulesEngine.applyDrawResult(_state, result);

      String message;
      if (result.madeMatch) {
        message =
            '${result.updatedDrawer.name} made a pair with ${result.drawnCard?.displayName}!';
        _emitEvent(GameEvent(
          type: GameEventType.pairRemoved,
          message: message,
          data: {
            'card1': result.drawnCard?.toJson(),
            'card2': result.matchedCard?.toJson(),
          },
        ));
      } else {
        message = '${result.updatedDrawer.name} drew a card';
        _emitEvent(GameEvent(
          type: GameEventType.cardDrawn,
          message: message,
        ));
      }

      // Update state message for synchronization
      _state = _state.copyWith(
        lastAction: message,
        lastActionTime: DateTime.now(),
      );

      // Check for player finished
      if (result.updatedDrawer.hand.isEmpty) {
        final finishedMsg = '${result.updatedDrawer.name} finished!';
        _state = _state.copyWith(lastAction: finishedMsg);
        _emitEvent(GameEvent(
          type: GameEventType.playerFinished,
          message: finishedMsg,
          data: {'playerId': result.updatedDrawer.id},
        ));
      }

      // Check for round end
      if (_state.phase == GamePhase.roundEnd) {
        _state = _rulesEngine.applyRoundScores(_state);
        const endMsg = 'Round ended!';
        _state = _state.copyWith(lastAction: endMsg);
        _emitEvent(GameEvent(
          type: GameEventType.roundEnded,
          message: endMsg,
        ));
      }

      // Broadcast new state to all clients
      _networkManager.broadcastState(_state);
      _notifyStateChange();
    }
  }

  /// Start a new round (host only)
  Future<void> startNewRound() async {
    if (!_isHost) return;

    _state = _rulesEngine.startNewRound(_state);

    await _networkManager.broadcastState(_state);

    _emitEvent(GameEvent(
      type: GameEventType.gameStarted,
      message: 'New round started!',
    ));

    _notifyStateChange();
  }

  /// Handle state update from network (client receives from host)
  void _handleNetworkStateUpdate(GameState newState) {
    _updateState(newState);

    _emitEvent(GameEvent(
      type: GameEventType.stateSync,
      message: newState.lastAction ?? 'State synchronized',
    ));
  }

  /// Handle player action from network (host receives from client)
  void _handlePlayerAction(Map<String, dynamic> action) {
    if (!_isHost) return;

    final type = action['type'] as String?;

    switch (type) {
      case 'draw':
        final drawerId = action['drawerId'] as String;
        final targetId = action['targetId'] as String;
        final cardIndex = action['cardIndex'] as int?;
        _executeDrawAction(drawerId, targetId, cardIndex);
        break;
      case 'join':
        final player =
            Player.fromJson(action['player'] as Map<String, dynamic>);
        _handlePlayerJoin(player);
        break;
      case 'shuffle':
        final playerId = action['playerId'] as String;
        _executeShuffleAction(playerId);
        break;
    }
  }

  /// Shuffle the local player's hand
  Future<void> shuffleHand() async {
    if (_localPlayerId == null) return;

    if (_isHost) {
      _executeShuffleAction(_localPlayerId!);
    } else {
      await _networkManager.sendAction({
        'type': 'shuffle',
        'playerId': _localPlayerId,
      });
    }
  }

  /// Host executes a shuffle action
  void _executeShuffleAction(String playerId) {
    if (!_isHost) return;

    final player = _state.getPlayerById(playerId);
    if (player != null) {
      final updatedPlayer = _rulesEngine.shufflePlayerHand(player);
      _state = _state.copyWith(
        players: _state.players
            .map((p) => p.id == updatedPlayer.id ? updatedPlayer : p)
            .toList(),
        lastAction: '${player.name} shuffled their hand',
        lastActionTime: DateTime.now(),
      );

      _networkManager.broadcastState(_state);
      _notifyStateChange();
    }
  }

  /// Handle player joining (host only)
  void _handlePlayerJoin(Player player) {
    if (!_isHost) return;

    if (_rulesEngine.canPlayerJoin(_state, player.id)) {
      _state = _rulesEngine.addPlayer(_state, player);

      _networkManager.broadcastState(_state);

      _emitEvent(GameEvent(
        type: GameEventType.playerJoined,
        message: '${player.name} joined the game',
        data: {'playerId': player.id},
      ));

      _notifyStateChange();
    }
  }

  /// Handle connection changes
  void _handleConnectionChange(String playerId, bool connected) {
    final player = _state.getPlayerById(playerId);
    if (player == null) return;

    final players = _state.players.map((p) {
      if (p.id == playerId) {
        return p.copyWith(isConnected: connected);
      }
      return p;
    }).toList();

    _updateState(_state.copyWith(players: players));

    if (!connected) {
      _emitEvent(GameEvent(
        type: GameEventType.playerLeft,
        message: '${player.name} disconnected',
        data: {'playerId': playerId},
      ));
    }
  }

  /// Leave the current game
  Future<void> leaveGame() async {
    await _networkManager.disconnect();
    _localPlayerId = null;
    _isHost = false;
  }

  /// Dispose resources
  void dispose() {
    _eventListeners.clear();
    _stateListeners.clear();
    _networkManager.dispose();
  }
}
