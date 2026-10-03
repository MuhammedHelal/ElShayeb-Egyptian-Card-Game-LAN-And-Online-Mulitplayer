import 'package:elshayeb/features/online_session/data/models/online_protocol_models.dart';
import 'package:elshayeb/features/online_session/domain/entities/online_lobby.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OnlineLobbyModel', () {
    test('maps the server-owned private room view', () {
      final model = OnlineLobbyModel.fromProtocolMessage(_snapshot());

      expect(model.roomCode, 'ABC123');
      expect(model.phase, OnlineRoomPhase.playing);
      expect(model.players, hasLength(2));
      expect(model.players.first.hand, hasLength(1));
      expect(model.players.last.hand, isNull);
      expect(model.toEntity().isMyTurn, isTrue);
      expect(model.toEntity().drawFromPlayer?.cardCount, 2);
    });

    test('rejects snapshots without a player list', () {
      final snapshot = _snapshot();
      (snapshot['payload'] as Map<String, dynamic>).remove('players');
      expect(
        () => OnlineLobbyModel.fromProtocolMessage(snapshot),
        throwsA(isA<OnlineProtocolException>()),
      );
    });

    test('rejects a private hand whose public count does not match', () {
      final snapshot = _snapshot();
      final players =
          (snapshot['payload'] as Map<String, dynamic>)['players'] as List;
      (players.first as Map<String, dynamic>)['cardCount'] = 2;
      expect(
        () => OnlineLobbyModel.fromProtocolMessage(snapshot),
        throwsA(isA<OnlineProtocolException>()),
      );
    });

    test('rejects a snapshot that exposes an opponent hand', () {
      final snapshot = _snapshot();
      final players =
          (snapshot['payload'] as Map<String, dynamic>)['players'] as List;
      (players.last as Map<String, dynamic>)['hand'] = [
        {'id': 'spades_13', 'suit': 'spades', 'rank': 13},
        {'id': 'clubs_2', 'suit': 'clubs', 'rank': 2},
      ];
      expect(
        () => OnlineLobbyModel.fromProtocolMessage(snapshot),
        throwsA(isA<OnlineProtocolException>()),
      );
    });
  });
}

Map<String, dynamic> _snapshot() => {
      'type': 'room_snapshot',
      'stateVersion': 3,
      'payload': {
        'roomCode': 'ABC123',
        'localUserId': 'user-1',
        'phase': 'playing',
        'canStart': false,
        'canStartNewRound': false,
        'currentPlayerUserId': 'user-1',
        'drawFromUserId': 'user-2',
        'roundNumber': 1,
        'players': [
          {
            'userId': 'user-1',
            'name': 'Ashraf',
            'avatarId': 'default',
            'connected': true,
            'cardCount': 1,
            'score': 0,
            'status': 'playing',
            'finishPosition': 0,
            'hand': [
              {'id': 'hearts_5', 'suit': 'hearts', 'rank': 5},
            ],
          },
          {
            'userId': 'user-2',
            'name': 'Player 2',
            'avatarId': 'default',
            'connected': true,
            'cardCount': 2,
            'score': 0,
            'status': 'playing',
            'finishPosition': 0,
          },
        ],
      },
    };
