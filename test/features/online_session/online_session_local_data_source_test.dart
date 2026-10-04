import 'package:elshayeb/features/online_session/data/datasources/online_session_local_data_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('persists and restores room recovery details', () async {
    final preferences = await SharedPreferences.getInstance();
    final dataSource =
        SharedPreferencesOnlineSessionLocalDataSource(preferences);

    await dataSource.save(const SavedOnlineSession(
      roomCode: 'ABC123',
      playerName: 'Ashraf',
      avatarId: 'avatar_1',
    ));

    final restored = dataSource.read();
    expect(restored?.roomCode, 'ABC123');
    expect(restored?.playerName, 'Ashraf');
    expect(restored?.avatarId, 'avatar_1');
  });

  test('clears saved recovery details when leaving', () async {
    final preferences = await SharedPreferences.getInstance();
    final dataSource =
        SharedPreferencesOnlineSessionLocalDataSource(preferences);
    await dataSource.save(const SavedOnlineSession(
      roomCode: 'ABC123',
      playerName: 'Ashraf',
      avatarId: 'avatar_1',
    ));

    await dataSource.clear();

    expect(dataSource.read(), isNull);
  });
}
