import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:one_night_werewolf/game.dart';
import 'package:one_night_werewolf/l10n.dart';

void main() {
  test('start game sends seating positions to FastAPI', () async {
    late Map<String, dynamic> requestBody;
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/v1/games');
      requestBody = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(jsonEncode(_gameJson()), 200);
    });
    final api = GameApi(
      client: client,
      baseUrl: 'http://localhost:8080/api/v1',
    );

    final game = await api.startPassAndPlay(const [
      Player(id: 'a', name: 'Alice'),
      Player(id: 'b', name: 'Bob'),
      Player(id: 'c', name: 'Casey'),
    ], defaultRolesForPlayerCount(3));

    expect(requestBody['players'][1]['seat'], 2);
    expect(requestBody['roles'], hasLength(6));
    expect(game.id, 'game-1');
    expect(game.players.first.originalRole, Role.robber);
  });

  test('night action sends only intent and expected server revision', () async {
    final original = GameSession.fromJson(_gameJson());
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(request.url.path, '/api/v1/games/game-1/night-actions');
      expect(body['actor_id'], 'a');
      expect(body['player_targets'], ['b']);
      expect(body['expected_revision'], 4);
      final updated = _gameJson()..['revision'] = 5;
      return http.Response(
        jsonEncode({
          'game': updated,
          'seen_roles': ['werewolf'],
        }),
        200,
      );
    });
    final api = GameApi(
      client: client,
      baseUrl: 'http://localhost:8080/api/v1',
    );

    final response = await api.nightAction(
      game: original,
      actorId: 'a',
      playerTargets: ['b'],
    );

    expect(response.game.revision, 5);
    expect(response.seenRoles, [Role.werewolf]);
  });

  test('going home ends and clears the current game session', () async {
    final client = MockClient(
      (_) async => http.Response(jsonEncode(_gameJson()), 200),
    );
    final controller = GameController(
      api: GameApi(client: client, baseUrl: 'http://localhost:8080/api/v1'),
    );
    addTearDown(controller.dispose);

    expect(await controller.startGame(), isTrue);
    expect(controller.phase, GamePhase.roleHandoff);
    expect(controller.game, isNotNull);

    controller.goHome();

    expect(controller.phase, GamePhase.home);
    expect(controller.game, isNull);
    expect(controller.result, isNull);
    expect(controller.room, isNull);
    expect(controller.roomSession, isNull);
    expect(controller.activeIndex, 0);
    expect(controller.secondsRemaining, 180);
    expect(controller.seenRoles, isEmpty);
    expect(controller.actionSummary, isEmpty);
    expect(controller.actionCommitted, isFalse);
  });

  test('parses and localizes Minion and Insomniac roles', () {
    expect(Role.fromJson('minion'), Role.minion);
    expect(Role.fromJson('insomniac'), Role.insomniac);

    const chinese = AppLocalizations(Locale('zh'));
    expect(chinese.text('minion'), '爪牙');
    expect(chinese.text('insomniac'), '失眠者');
  });
}

Map<String, dynamic> _gameJson() => {
  'id': 'game-1',
  'room_code': 'ABC234',
  'mode': 'pass_and_play',
  'status': 'in_progress',
  'phase': 'night',
  'night_roles': ['werewolf', 'seer', 'robber', 'troublemaker'],
  'night_started_at': '2026-08-01T00:00:00Z',
  'revision': 4,
  'players': [
    {
      'id': 'a',
      'name': 'Alice',
      'seat': 1,
      'original_role': 'robber',
      'current_role': 'robber',
    },
    {
      'id': 'b',
      'name': 'Bob',
      'seat': 2,
      'original_role': 'werewolf',
      'current_role': 'werewolf',
    },
    {
      'id': 'c',
      'name': 'Casey',
      'seat': 3,
      'original_role': 'villager',
      'current_role': 'villager',
    },
  ],
  'original_center': ['werewolf', 'seer', 'troublemaker'],
  'center': ['werewolf', 'seer', 'troublemaker'],
  'completed_action_player_ids': [],
  'votes': <String, String>{},
  'result': null,
};
