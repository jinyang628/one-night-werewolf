import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:http/http.dart' as http;

import 'l10n.dart';

enum Role {
  werewolf,
  minion,
  seer,
  robber,
  troublemaker,
  insomniac,
  villager;

  static Role fromJson(String value) =>
      Role.values.firstWhere((role) => role.name == value);
}

List<Role> defaultRolesForPlayerCount(int playerCount) {
  final roles = [
    Role.werewolf,
    Role.minion,
    Role.seer,
    Role.robber,
    Role.troublemaker,
    Role.insomniac,
  ];
  if (playerCount >= 4) roles.add(Role.werewolf);
  roles.addAll(List.filled(playerCount + 3 - roles.length, Role.villager));
  return roles;
}

class Player {
  const Player({required this.id, required this.name});

  final String id;
  final String name;

  Player copyWith({String? name}) => Player(id: id, name: name ?? this.name);
}

class GamePlayer {
  const GamePlayer({
    required this.player,
    required this.seat,
    required this.originalRole,
    required this.currentRole,
  });

  final Player player;
  final int seat;
  final Role originalRole;
  final Role currentRole;

  factory GamePlayer.fromJson(Map<String, dynamic> json) => GamePlayer(
    player: Player(id: json['id'] as String, name: json['name'] as String),
    seat: json['seat'] as int,
    originalRole: Role.fromJson(json['original_role'] as String),
    currentRole: Role.fromJson(json['current_role'] as String),
  );
}

class GameResult {
  const GameResult({
    required this.winningTeam,
    required this.eliminatedIds,
    required this.werewolfIds,
    required this.tallies,
  });

  final String winningTeam;
  bool get villageWon => winningTeam == 'village';
  final Set<String> eliminatedIds;
  final Set<String> werewolfIds;
  final Map<String, int> tallies;

  factory GameResult.fromJson(Map<String, dynamic> json) => GameResult(
    winningTeam: json['winning_team'] as String,
    eliminatedIds: Set<String>.from(json['eliminated_player_ids'] as List),
    werewolfIds: Set<String>.from(json['werewolf_player_ids'] as List),
    tallies: {
      for (final tally in json['tallies'] as List)
        (tally as Map<String, dynamic>)['player_id'] as String:
            tally['votes'] as int,
    },
  );
}

class GameSession {
  const GameSession({
    required this.id,
    required this.roomCode,
    required this.revision,
    required this.serverPhase,
    required this.players,
    required this.originalCenter,
    required this.center,
    required this.completedActionPlayerIds,
    required this.votes,
    this.result,
  });

  final String id;
  final String roomCode;
  final int revision;
  final String serverPhase;
  final List<GamePlayer> players;
  final List<Role> originalCenter;
  final List<Role> center;
  final Set<String> completedActionPlayerIds;
  final Map<String, String> votes;
  final GameResult? result;

  factory GameSession.fromJson(Map<String, dynamic> json) => GameSession(
    id: json['id'] as String,
    roomCode: json['room_code'] as String,
    revision: json['revision'] as int,
    serverPhase: json['phase'] as String,
    players: [
      for (final player in json['players'] as List)
        GamePlayer.fromJson(player as Map<String, dynamic>),
    ],
    originalCenter: [
      for (final role in json['original_center'] as List)
        Role.fromJson(role as String),
    ],
    center: [
      for (final role in json['center'] as List) Role.fromJson(role as String),
    ],
    completedActionPlayerIds: Set<String>.from(
      json['completed_action_player_ids'] as List? ?? const [],
    ),
    votes: Map<String, String>.from(
      json['votes'] as Map<String, dynamic>? ?? const {},
    ),
    result: json['result'] == null
        ? null
        : GameResult.fromJson(json['result'] as Map<String, dynamic>),
  );
}

class NightActionResponse {
  const NightActionResponse({required this.game, required this.seenRoles});
  final GameSession game;
  final List<Role> seenRoles;

  factory NightActionResponse.fromJson(Map<String, dynamic> json) =>
      NightActionResponse(
        game: GameSession.fromJson(json['game'] as Map<String, dynamic>),
        seenRoles: [
          for (final role in json['seen_roles'] as List)
            Role.fromJson(role as String),
        ],
      );
}

class RoomPlayer {
  const RoomPlayer({required this.id, required this.name, required this.seat});
  final String id;
  final String name;
  final int seat;

  factory RoomPlayer.fromJson(Map<String, dynamic> json) => RoomPlayer(
    id: json['id'] as String,
    name: json['name'] as String,
    seat: json['seat'] as int,
  );
}

class RoomState {
  const RoomState({
    required this.id,
    required this.roomCode,
    required this.status,
    required this.revision,
    required this.players,
    required this.hostPlayerId,
    required this.selectedRoles,
  });

  final String id;
  final String roomCode;
  final String status;
  final int revision;
  final List<RoomPlayer> players;
  final String hostPlayerId;
  final List<Role> selectedRoles;

  factory RoomState.fromJson(Map<String, dynamic> json) => RoomState(
    id: json['id'] as String,
    roomCode: json['room_code'] as String,
    status: json['status'] as String,
    revision: json['revision'] as int,
    players: [
      for (final player in json['players'] as List)
        RoomPlayer.fromJson(player as Map<String, dynamic>),
    ],
    hostPlayerId: json['host_player_id'] as String,
    selectedRoles: [
      for (final role in json['selected_roles'] as List)
        Role.fromJson(role as String),
    ],
  );
}

class RoomSession {
  const RoomSession({
    required this.room,
    required this.playerId,
    required this.playerToken,
  });

  final RoomState room;
  final String playerId;
  final String playerToken;

  factory RoomSession.fromJson(Map<String, dynamic> json) => RoomSession(
    room: RoomState.fromJson(json['room'] as Map<String, dynamic>),
    playerId: json['player_id'] as String,
    playerToken: json['player_token'] as String,
  );
}

class ApiException implements Exception {
  const ApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

class GameApi {
  GameApi({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      baseUrl = baseUrl ?? _configuredApiBaseUrl();

  final http.Client _client;
  final String baseUrl;

  Future<GameSession> startPassAndPlay(
    List<Player> players,
    List<Role> selectedRoles,
  ) async {
    final json = await _request(
      'POST',
      '/games',
      body: {
        'players': [
          for (var index = 0; index < players.length; index++)
            {
              'id': players[index].id,
              'name': players[index].name,
              'seat': index + 1,
            },
        ],
        'roles': selectedRoles.map((role) => role.name).toList(),
      },
    );
    return GameSession.fromJson(json);
  }

  Future<GameSession> getGame(String gameId) async =>
      GameSession.fromJson(await _request('GET', '/games/$gameId'));

  Future<NightActionResponse> nightAction({
    required GameSession game,
    required String actorId,
    List<String> playerTargets = const [],
    List<int> centerTargets = const [],
  }) async {
    final json = await _request(
      'POST',
      '/games/${game.id}/night-actions',
      body: {
        'actor_id': actorId,
        'player_targets': playerTargets,
        'center_targets': centerTargets,
        'expected_revision': game.revision,
      },
    );
    return NightActionResponse.fromJson(json);
  }

  Future<GameSession> acknowledgeRole({
    required GameSession game,
    required String playerId,
  }) async => GameSession.fromJson(
    await _request(
      'POST',
      '/games/${game.id}/role-acknowledgements',
      body: {'player_id': playerId, 'expected_revision': game.revision},
    ),
  );

  Future<GameSession> endDiscussion(GameSession game) async =>
      GameSession.fromJson(
        await _request(
          'POST',
          '/games/${game.id}/end-discussion',
          body: {'expected_revision': game.revision},
        ),
      );

  Future<GameSession> castVote({
    required GameSession game,
    required String voterId,
    required String targetId,
  }) async {
    final json = await _request(
      'POST',
      '/games/${game.id}/votes',
      body: {
        'voter_id': voterId,
        'target_id': targetId,
        'expected_revision': game.revision,
      },
    );
    return GameSession.fromJson(json['game'] as Map<String, dynamic>);
  }

  Future<RoomSession> createRoom(String playerName) async =>
      RoomSession.fromJson(
        await _request(
          'POST',
          '/games/rooms',
          body: {'player_name': playerName},
        ),
      );

  Future<RoomSession> joinRoom(String roomCode, String playerName) async =>
      RoomSession.fromJson(
        await _request(
          'POST',
          '/games/rooms/${roomCode.toUpperCase()}/join',
          body: {'player_name': playerName},
        ),
      );

  Future<RoomState> getRoom(String roomCode) async => RoomState.fromJson(
    await _request('GET', '/games/rooms/${roomCode.toUpperCase()}'),
  );

  Future<RoomState> configureRoomRoles(
    RoomSession session,
    RoomState room,
    List<Role> roles,
  ) async => RoomState.fromJson(
    await _request(
      'PUT',
      '/games/rooms/${room.roomCode}/roles',
      body: {
        'player_id': session.playerId,
        'player_token': session.playerToken,
        'roles': roles.map((role) => role.name).toList(),
        'expected_revision': room.revision,
      },
    ),
  );

  Future<void> startRoom(RoomSession session, int expectedRevision) async {
    await _request(
      'POST',
      '/games/rooms/${session.room.roomCode}/start',
      body: {
        'player_id': session.playerId,
        'player_token': session.playerToken,
        'expected_revision': expectedRevision,
      },
    );
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = {'Content-Type': 'application/json'};
    late final http.Response response;
    try {
      response = switch (method) {
        'GET' => await _client.get(uri, headers: headers),
        'POST' => await _client.post(
          uri,
          headers: headers,
          body: jsonEncode(body),
        ),
        'PUT' => await _client.put(
          uri,
          headers: headers,
          body: jsonEncode(body),
        ),
        _ => throw ArgumentError('Unsupported method $method'),
      };
    } on Exception {
      throw ApiException('Could not reach the game server: $baseUrl');
    }
    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map<String, dynamic>
          ? decoded['detail']?.toString()
          : null;
      throw ApiException(message ?? 'The server rejected this request.');
    }
    return decoded as Map<String, dynamic>;
  }

  void close() => _client.close();
}

String _configuredApiBaseUrl() {
  final dotenvValue = dotenv.isInitialized
      ? dotenv.maybeGet('API_BASE_URL')?.trim()
      : null;
  if (dotenvValue != null && dotenvValue.isNotEmpty) {
    return dotenvValue;
  }

  const compiledValue = String.fromEnvironment('API_BASE_URL');
  return compiledValue.isNotEmpty
      ? compiledValue
      : 'http://127.0.0.1:8080/api/v1';
}

enum GamePhase {
  home,
  setup,
  roomEntry,
  roomLobby,
  roleHandoff,
  roleReveal,
  nightHandoff,
  nightAction,
  discussion,
  voteHandoff,
  voting,
  result,
}

class GameController extends ChangeNotifier {
  GameController({GameApi? api, this.languageCode = 'en'})
    : _api = api ?? GameApi();

  final GameApi _api;
  String languageCode;
  final List<Player> players = [
    const Player(id: 'player-1', name: 'Player 1'),
    const Player(id: 'player-2', name: 'Player 2'),
    const Player(id: 'player-3', name: 'Player 3'),
  ];
  final List<Role> selectedRoles = defaultRolesForPlayerCount(3);

  GamePhase phase = GamePhase.home;
  GameSession? game;
  GameResult? result;
  RoomSession? roomSession;
  RoomState? room;
  int activeIndex = 0;
  int secondsRemaining = 180;
  List<Role> seenRoles = [];
  String actionSummary = '';
  bool actionCommitted = false;
  bool busy = false;
  String? error;
  Timer? _timer;
  Timer? _roomPoller;
  int _nextPlayerNumber = 4;
  List<GamePlayer> _nightActors = [];

  Player get activePlayer {
    if (phase == GamePhase.nightHandoff || phase == GamePhase.nightAction) {
      return _nightActors[activeIndex].player;
    }
    return game!.players[activeIndex].player;
  }

  GamePlayer get activeGamePlayer {
    if (phase == GamePhase.nightHandoff || phase == GamePhase.nightAction) {
      return _nightActors[activeIndex];
    }
    return game!.players[activeIndex];
  }

  bool get isRoomHost =>
      roomSession != null && roomSession!.playerId == room?.hostPlayerId;

  void setLanguage(String value) {
    for (var index = 0; index < players.length; index++) {
      final defaultNamePattern = RegExp(r'^(Player|玩家) \d+$');
      if (defaultNamePattern.hasMatch(players[index].name)) {
        players[index] = players[index].copyWith(
          name: AppLocalizations(
            Locale(value),
          ).text('default_player', {'number': index + 1}),
        );
      }
    }
    languageCode = value;
    notifyListeners();
  }

  void choosePassAndPlay() {
    error = null;
    phase = GamePhase.setup;
    notifyListeners();
  }

  void chooseRoom() {
    error = null;
    phase = GamePhase.roomEntry;
    notifyListeners();
  }

  void goHome() {
    _timer?.cancel();
    _roomPoller?.cancel();
    game = null;
    room = null;
    roomSession = null;
    error = null;
    phase = GamePhase.home;
    notifyListeners();
  }

  void renamePlayer(int index, String name) {
    players[index] = players[index].copyWith(name: name);
  }

  void addPlayer() {
    if (players.length >= 8) return;
    players.add(
      Player(
        id: 'player-${DateTime.now().microsecondsSinceEpoch}',
        name: _text('default_player', {'number': _nextPlayerNumber}),
      ),
    );
    _nextPlayerNumber++;
    _resizeSelectedRoles();
    notifyListeners();
  }

  void removePlayer(int index) {
    if (players.length <= 3) return;
    players.removeAt(index);
    _resizeSelectedRoles();
    notifyListeners();
  }

  void movePlayer(int from, int to) {
    if (to < 0 || to >= players.length) return;
    final player = players.removeAt(from);
    players.insert(to, player);
    notifyListeners();
  }

  Future<bool> startGame() async {
    if (players.any((player) => player.name.trim().isEmpty)) return false;
    return _guard(() async {
      _timer?.cancel();
      game = await _api.startPassAndPlay(
        players
            .map((player) => player.copyWith(name: player.name.trim()))
            .toList(),
        selectedRoles,
      );
      result = null;
      activeIndex = 0;
      phase = GamePhase.roleHandoff;
    });
  }

  Future<bool> createRoom(String playerName) async {
    if (playerName.trim().isEmpty) return false;
    return _guard(() async {
      roomSession = await _api.createRoom(playerName.trim());
      room = roomSession!.room;
      phase = GamePhase.roomLobby;
      _startRoomPolling();
    });
  }

  Future<bool> joinRoom(String roomCode, String playerName) async {
    if (roomCode.trim().isEmpty || playerName.trim().isEmpty) return false;
    return _guard(() async {
      roomSession = await _api.joinRoom(roomCode.trim(), playerName.trim());
      room = roomSession!.room;
      phase = GamePhase.roomLobby;
      _startRoomPolling();
    });
  }

  Future<void> startRemoteRoom() async {
    if (roomSession == null) return;
    await _guard(() async {
      await _api.startRoom(roomSession!, room!.revision);
      room = await _api.getRoom(roomSession!.room.roomCode);
    });
  }

  void setPassAndPlayRoles(List<Role> roles) {
    if (roles.length != players.length + 3) return;
    selectedRoles
      ..clear()
      ..addAll(roles);
    notifyListeners();
  }

  Future<bool> configureRemoteRoomRoles(List<Role> roles) async {
    if (roomSession == null || room == null) return false;
    if (roles.length != room!.players.length + 3) return false;
    return _guard(() async {
      room = await _api.configureRoomRoles(roomSession!, room!, roles);
    });
  }

  void showRole() {
    phase = GamePhase.roleReveal;
    notifyListeners();
  }

  Future<void> hideRoleAndContinue() async {
    final advanced = await _guard(() async {
      game = await _api.acknowledgeRole(game: game!, playerId: activePlayer.id);
    });
    if (!advanced) return;
    if (activeIndex < game!.players.length - 1) {
      activeIndex++;
      phase = GamePhase.roleHandoff;
    } else {
      _nightActors =
          game!.players
              .where((player) => player.originalRole != Role.villager)
              .toList()
            ..sort(
              (a, b) => _nightOrder(
                a.originalRole,
              ).compareTo(_nightOrder(b.originalRole)),
            );
      activeIndex = 0;
      phase = GamePhase.nightHandoff;
    }
    notifyListeners();
  }

  void beginNightAction() {
    seenRoles = [];
    actionSummary = '';
    actionCommitted = false;
    phase = GamePhase.nightAction;
    notifyListeners();
  }

  List<GamePlayer> otherPlayers(String actorId) =>
      game!.players.where((player) => player.player.id != actorId).toList();

  List<GamePlayer> werewolfPartners(String actorId) => game!.players
      .where(
        (player) =>
            player.player.id != actorId && player.originalRole == Role.werewolf,
      )
      .toList();

  Future<void> completeMinionWatch() async {
    await _performAction(summary: _text('minion_result'));
  }

  Future<void> loneWolfViewCenter(int index) async {
    await _performAction(
      centerTargets: [index],
      summary: _text('center_is', {'number': index + 1}),
    );
  }

  Future<void> completeWerewolfMeeting() async {
    await _performAction(summary: _text('found_pack'));
  }

  Future<void> seerViewPlayer(String playerId) async {
    final target = _findPlayer(playerId);
    await _performAction(
      playerTargets: [playerId],
      summary: _text('player_is', {'name': target.player.name}),
    );
  }

  Future<void> seerViewCenter(List<int> indices) async {
    await _performAction(
      centerTargets: indices,
      summary: _text('centers_are', {
        'numbers': indices.map((index) => index + 1).join(' & '),
      }),
    );
  }

  Future<void> robberSwap(String targetId) async {
    final target = _findPlayer(targetId);
    await _performAction(
      playerTargets: [targetId],
      summary: _text('robbed_result', {'name': target.player.name}),
    );
  }

  Future<void> troublemakerSwap(String firstId, String secondId) async {
    final first = _findPlayer(firstId);
    final second = _findPlayer(secondId);
    await _performAction(
      playerTargets: [firstId, secondId],
      summary: _text('trouble_result', {
        'first': first.player.name,
        'second': second.player.name,
      }),
    );
  }

  Future<void> insomniacCheck() async {
    await _performAction(summary: _text('insomniac_result'));
  }

  Future<void> _performAction({
    List<String> playerTargets = const [],
    List<int> centerTargets = const [],
    required String summary,
  }) async {
    await _guard(() async {
      final response = await _api.nightAction(
        game: game!,
        actorId: activePlayer.id,
        playerTargets: playerTargets,
        centerTargets: centerTargets,
      );
      game = response.game;
      seenRoles = response.seenRoles;
      actionSummary = summary;
      actionCommitted = true;
    });
  }

  void finishNightTurn() {
    if (!actionCommitted) return;
    seenRoles = [];
    actionSummary = '';
    if (activeIndex < _nightActors.length - 1) {
      activeIndex++;
      phase = GamePhase.nightHandoff;
    } else {
      activeIndex = 0;
      phase = GamePhase.discussion;
      secondsRemaining = 180;
      _startTimer();
    }
    notifyListeners();
  }

  Future<void> endDiscussion() async {
    final advanced = await _guard(() async {
      game = await _api.endDiscussion(game!);
    });
    if (advanced) {
      _timer?.cancel();
      activeIndex = 0;
      phase = GamePhase.voteHandoff;
      notifyListeners();
    }
  }

  void beginVote() {
    phase = GamePhase.voting;
    notifyListeners();
  }

  Future<void> castVote(String targetId) async {
    if (targetId == activePlayer.id) return;
    await _guard(() async {
      game = await _api.castVote(
        game: game!,
        voterId: activePlayer.id,
        targetId: targetId,
      );
      if (activeIndex < game!.players.length - 1) {
        activeIndex++;
        phase = GamePhase.voteHandoff;
      } else {
        result = game!.result;
        phase = GamePhase.result;
      }
    });
  }

  void returnToSetup() {
    _timer?.cancel();
    game = null;
    result = null;
    activeIndex = 0;
    phase = GamePhase.setup;
    notifyListeners();
  }

  Future<void> playAgain() async {
    await startGame();
  }

  GamePlayer _findPlayer(String id) =>
      game!.players.firstWhere((player) => player.player.id == id);

  void _resizeSelectedRoles() {
    final required = players.length + 3;
    while (selectedRoles.length < required) {
      selectedRoles.add(Role.villager);
    }
    while (selectedRoles.length > required) {
      final villagerIndex = selectedRoles.lastIndexOf(Role.villager);
      selectedRoles.removeAt(
        villagerIndex >= 0 ? villagerIndex : selectedRoles.length - 1,
      );
    }
  }

  String _text(String key, [Map<String, Object> values = const {}]) =>
      AppLocalizations(Locale(languageCode)).text(key, values);

  Future<bool> _guard(Future<void> Function() operation) async {
    if (busy) return false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await operation();
      return true;
    } on ApiException catch (exception) {
      error = exception.message;
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  void _startRoomPolling() {
    _roomPoller?.cancel();
    _roomPoller = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (busy || roomSession == null) return;
      try {
        room = await _api.getRoom(roomSession!.room.roomCode);
        notifyListeners();
        if (room!.status != 'waiting') {
          _roomPoller?.cancel();
        }
      } on ApiException catch (exception) {
        error = exception.message;
        notifyListeners();
      }
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (secondsRemaining <= 1) {
        secondsRemaining = 0;
        timer.cancel();
      } else {
        secondsRemaining--;
      }
      notifyListeners();
    });
  }

  static int _nightOrder(Role role) => switch (role) {
    Role.werewolf => 0,
    Role.minion => 1,
    Role.seer => 2,
    Role.robber => 3,
    Role.troublemaker => 4,
    Role.insomniac => 5,
    Role.villager => 6,
  };

  @override
  void dispose() {
    _timer?.cancel();
    _roomPoller?.cancel();
    _api.close();
    super.dispose();
  }
}
