import 'package:elshayeb/features/online_session/data/models/online_protocol_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OnlineLobbyModel', () {
    test('maps a server lobby snapshot', () {
      final model = OnlineLobbyModel.fromProtocolMessage({
        'type': 'lobby_snapshot',
        'stateVersion': 3,
        'payload': {
          'roomCode': 'ABC123',
          'localUserId': 'user-1',
          'canStart': true,
          'players': [
            {
              'userId': 'user-1',
              'name': 'Ashraf',
              'avatarId': 'default',
              'connected': true,
            },
            {
              'userId': 'user-2',
              'name': 'Player 2',
              'avatarId': 'default',
              'connected': false,
            },
          ],
        },
      });

      expect(model.roomCode, 'ABC123');
      expect(model.stateVersion, 3);
      expect(model.players, hasLength(2));
      expect(model.toEntity().players.last.isConnected, isFalse);
    });

    test('rejects snapshots without a player list', () {
      expect(
        () => OnlineLobbyModel.fromProtocolMessage({
          'stateVersion': 1,
          'payload': {'roomCode': 'ABC123'},
        }),
        throwsA(isA<OnlineProtocolException>()),
      );
    });
  });
}
