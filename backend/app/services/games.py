import random
import secrets
import string
from collections import Counter
from copy import deepcopy
from datetime import UTC, datetime, timedelta
from uuid import uuid4

from app.models.games import (
    AdvanceGameRequest,
    ConfigureRoomRolesRequest,
    CreateRoomRequest,
    GameMode,
    GamePhase,
    GamePlayer,
    GameResult,
    GameState,
    GameStatus,
    JoinRoomRequest,
    NightActionRequest,
    NightActionResponse,
    Role,
    RoomPlayer,
    RoomSession,
    RoomState,
    StartGameRequest,
    StartRoomRequest,
    VoteRequest,
    VoteResponse,
    VoteTally,
)
from app.services.game_repository import (
    GameConflictError,
    GameRepository,
)


class GameActionError(ValueError):
    pass


class RoomAuthorizationError(PermissionError):
    pass


class GameService:
    NIGHT_ACTION_SECONDS = 10
    NIGHT_TRANSITION_SECONDS = 2
    NARRATION_LEAD_SECONDS = 3

    def __init__(self, repository: GameRepository):
        self.repository = repository

    async def start_game(self, input: StartGameRequest) -> GameState:
        game = self._deal_game(
            players=input.players,
            roles=input.roles,
            game_id=str(uuid4()),
            room_code=self._room_code(),
            mode=GameMode.pass_and_play,
            host_player_id=None,
        )
        row = await self.repository.create(self._game_payload(game))
        return self._game_from_row(row)

    async def get_game(self, game_id: str) -> GameState:
        row = await self.repository.get_by_id(game_id)
        game = self._game_from_row(row)
        if self._night_has_ended(game):
            game.phase = GamePhase.discussion
            game.discussion_started_at = self._night_ends_at(game).isoformat()
            try:
                return await self._save_game(game, game.revision)
            except GameConflictError:
                return self._game_from_row(await self.repository.get_by_id(game_id))
        return game

    async def acknowledge_role(
        self, game_id: str, input: AdvanceGameRequest
    ) -> GameState:
        row = await self.repository.get_by_id(game_id)
        game = self._game_from_row(row)
        self._check_revision(game, input.expected_revision)
        if game.phase is not GamePhase.role_reveal:
            raise GameActionError("The game is not revealing roles")
        if input.player_id is None:
            raise GameActionError("A player id is required")
        self._player(game, input.player_id)
        if input.player_id in game.revealed_role_player_ids:
            raise GameActionError("This role was already acknowledged")
        game.revealed_role_player_ids.append(input.player_id)
        if len(game.revealed_role_player_ids) == len(game.players):
            game.phase = GamePhase.night
            game.night_started_at = self._now()
        return await self._save_game(game, game.revision)

    async def perform_night_action(
        self, game_id: str, input: NightActionRequest
    ) -> NightActionResponse:
        row = await self.repository.get_by_id(game_id)
        game = self._game_from_row(row)
        self._check_revision(game, input.expected_revision)
        if game.phase is not GamePhase.night:
            raise GameActionError("The game is not in the night phase")
        if input.actor_id in game.completed_action_player_ids:
            raise GameActionError("This player already completed their night action")

        updated_game = deepcopy(game)
        actor = self._player(updated_game, input.actor_id)
        role = actor.original_role
        seen_roles: list[Role] = []

        if role is Role.werewolf:
            seen_roles = self._werewolf_action(
                updated_game, actor.id, input.center_targets
            )
        elif role is Role.minion:
            seen_roles = self._minion_action(
                updated_game,
                input.player_targets,
                input.center_targets,
            )
        elif role is Role.seer:
            seen_roles = self._seer_action(
                updated_game,
                actor.id,
                input.player_targets,
                input.center_targets,
            )
        elif role is Role.robber:
            seen_roles = self._robber_action(
                updated_game, actor.id, input.player_targets
            )
        elif role is Role.troublemaker:
            self._troublemaker_action(updated_game, actor.id, input.player_targets)
        elif role is Role.insomniac:
            seen_roles = self._insomniac_action(
                updated_game,
                actor.id,
                input.player_targets,
                input.center_targets,
            )
        elif input.player_targets or input.center_targets:
            raise GameActionError("The Villager does not take a night action")

        updated_game.completed_action_player_ids.append(actor.id)
        saved = await self._save_game(updated_game, game.revision)
        return NightActionResponse(game=saved, seen_roles=seen_roles)

    async def end_discussion(
        self, game_id: str, input: AdvanceGameRequest
    ) -> GameState:
        row = await self.repository.get_by_id(game_id)
        game = self._game_from_row(row)
        self._check_revision(game, input.expected_revision)
        if game.phase is not GamePhase.discussion:
            raise GameActionError("The game is not in discussion")
        game.phase = GamePhase.voting
        return await self._save_game(game, game.revision)

    async def cast_vote(self, game_id: str, input: VoteRequest) -> VoteResponse:
        row = await self.repository.get_by_id(game_id)
        game = self._game_from_row(row)
        self._check_revision(game, input.expected_revision)
        if game.phase is not GamePhase.voting:
            raise GameActionError("The game is not accepting votes")
        player_ids = {player.id for player in game.players}
        if input.voter_id not in player_ids:
            raise GameActionError("Unknown voter")
        if input.target_id not in player_ids or input.target_id == input.voter_id:
            raise GameActionError("Vote must target another player")
        if input.voter_id in game.votes:
            raise GameActionError("This player already voted")

        game.votes[input.voter_id] = input.target_id
        if len(game.votes) == len(game.players):
            game.result = self._resolve(game)
            game.status = GameStatus.complete
            game.phase = GamePhase.complete
        return VoteResponse(game=await self._save_game(game, game.revision))

    async def create_room(self, input: CreateRoomRequest) -> RoomSession:
        player_id = str(uuid4())
        player_token = secrets.token_urlsafe(24)
        room = RoomState(
            id=str(uuid4()),
            room_code=self._room_code(),
            status=GameStatus.waiting,
            revision=0,
            players=[RoomPlayer(id=player_id, name=input.player_name.strip(), seat=1)],
            host_player_id=player_id,
            selected_roles=self._default_roles(1),
        )
        row = await self.repository.create(
            self._room_payload(room, {player_id: player_token})
        )
        persisted = self._room_from_row(row)
        return RoomSession(
            room=persisted,
            player_id=player_id,
            player_token=player_token,
        )

    async def join_room(self, room_code: str, input: JoinRoomRequest) -> RoomSession:
        row = await self.repository.get_by_room_code(room_code.upper())
        room = self._room_from_row(row)
        if room.status is not GameStatus.waiting:
            raise GameActionError("This room has already started")
        if len(room.players) >= 8:
            raise GameActionError("This room is full")

        player_id = str(uuid4())
        player_token = secrets.token_urlsafe(24)
        previous_default = self._default_roles(len(room.players))
        used_default = room.selected_roles == previous_default
        room.players.append(
            RoomPlayer(
                id=player_id,
                name=input.player_name.strip(),
                seat=len(room.players) + 1,
            )
        )
        if used_default:
            room.selected_roles = self._default_roles(len(room.players))
        else:
            room.selected_roles.append(Role.villager)
        tokens = dict(row.get("player_tokens") or {})
        tokens[player_id] = player_token
        saved_row = await self.repository.update(
            room.id,
            room.revision,
            {
                "state": room.model_dump(mode="json"),
                "player_tokens": tokens,
                "revision": room.revision + 1,
                "updated_at": self._now(),
            },
        )
        return RoomSession(
            room=self._room_from_row(saved_row),
            player_id=player_id,
            player_token=player_token,
        )

    async def get_room(self, room_code: str) -> RoomState:
        return self._room_from_row(
            await self.repository.get_by_room_code(room_code.upper())
        )

    async def configure_room_roles(
        self,
        room_code: str,
        input: ConfigureRoomRolesRequest,
    ) -> RoomState:
        row = await self.repository.get_by_room_code(room_code.upper())
        room = self._room_from_row(row)
        self._check_revision_value(room.revision, input.expected_revision)
        self._authorize_host(row, room, input.player_id, input.player_token)
        if room.status is not GameStatus.waiting:
            raise GameActionError("Roles cannot be changed after the game starts")
        self._validate_role_count(input.roles, len(room.players))
        room.selected_roles = list(input.roles)
        saved_row = await self.repository.update(
            room.id,
            room.revision,
            {
                "state": room.model_dump(mode="json"),
                "revision": room.revision + 1,
                "updated_at": self._now(),
            },
        )
        return self._room_from_row(saved_row)

    async def start_room(self, room_code: str, input: StartRoomRequest) -> GameState:
        row = await self.repository.get_by_room_code(room_code.upper())
        room = self._room_from_row(row)
        self._check_revision_value(room.revision, input.expected_revision)
        self._authorize_host(row, room, input.player_id, input.player_token)
        if len(room.players) < 3:
            raise GameActionError("At least three players are required")
        self._validate_role_count(room.selected_roles, len(room.players))

        game = self._deal_game(
            players=room.players,
            roles=room.selected_roles,
            game_id=room.id,
            room_code=room.room_code,
            mode=GameMode.room,
            host_player_id=room.host_player_id,
        )
        saved_row = await self.repository.update(
            room.id,
            room.revision,
            {
                **self._game_payload(game),
                "revision": room.revision + 1,
                "updated_at": self._now(),
            },
        )
        return self._game_from_row(saved_row)

    async def _save_game(self, game: GameState, revision: int) -> GameState:
        game.revision = revision + 1
        row = await self.repository.update(
            game.id,
            revision,
            {
                "status": game.status.value,
                "state": game.model_dump(mode="json"),
                "revision": game.revision,
                "updated_at": self._now(),
            },
        )
        return self._game_from_row(row)

    def _deal_game(
        self,
        players,
        roles: list[Role],
        game_id: str,
        room_code: str,
        mode: GameMode,
        host_player_id: str | None,
    ) -> GameState:
        ordered_players = sorted(players, key=lambda player: player.seat)
        self._validate_role_count(roles, len(ordered_players))
        deck = list(roles)
        random.SystemRandom().shuffle(deck)
        game_players = [
            GamePlayer(
                id=player.id,
                name=player.name,
                seat=player.seat,
                original_role=deck[index],
                current_role=deck[index],
            )
            for index, player in enumerate(ordered_players)
        ]
        center = deck[len(ordered_players) :]
        return GameState(
            id=game_id,
            room_code=room_code,
            mode=mode,
            status=GameStatus.in_progress,
            phase=GamePhase.role_reveal,
            host_player_id=host_player_id,
            players=game_players,
            original_center=center,
            center=center,
            night_roles=self._night_roles(roles),
            night_started_at=None,
        )

    @staticmethod
    def _night_roles(roles: list[Role]) -> list[Role]:
        ordered = [
            Role.werewolf,
            Role.minion,
            Role.seer,
            Role.robber,
            Role.troublemaker,
            Role.insomniac,
        ]
        return [role for role in ordered if role in roles]

    def _night_ends_at(self, game: GameState) -> datetime:
        assert game.night_started_at is not None
        started = datetime.fromisoformat(game.night_started_at)
        return started + timedelta(
            seconds=len(game.night_roles) * self._night_slot_seconds(game)
        )

    def _night_slot_seconds(self, game: GameState) -> int:
        return self.NIGHT_ACTION_SECONDS + (
            self.NIGHT_TRANSITION_SECONDS + self.NARRATION_LEAD_SECONDS
            if game.mode is GameMode.pass_and_play
            else 0
        )

    def _night_has_ended(self, game: GameState) -> bool:
        return (
            game.phase is GamePhase.night
            and game.night_started_at is not None
            and datetime.now(UTC) >= self._night_ends_at(game)
        )

    def _game_payload(self, game: GameState) -> dict:
        return {
            "id": game.id,
            "room_code": game.room_code,
            "mode": game.mode.value,
            "status": game.status.value,
            "state": game.model_dump(mode="json"),
            "revision": game.revision,
            "updated_at": self._now(),
        }

    @staticmethod
    def _room_payload(room: RoomState, tokens: dict[str, str]) -> dict:
        return {
            "id": room.id,
            "room_code": room.room_code,
            "mode": GameMode.room.value,
            "status": room.status.value,
            "state": room.model_dump(mode="json"),
            "player_tokens": tokens,
            "revision": room.revision,
            "updated_at": GameService._now(),
        }

    @staticmethod
    def _game_from_row(row: dict) -> GameState:
        state = dict(row["state"])
        state.update(
            {
                "id": row["id"],
                "room_code": row["room_code"],
                "mode": row["mode"],
                "status": row["status"],
                "revision": row["revision"],
            }
        )
        return GameState.model_validate(state)

    @staticmethod
    def _room_from_row(row: dict) -> RoomState:
        state = dict(row["state"])
        if row["status"] != GameStatus.waiting.value:
            state = {
                "players": [
                    {
                        "id": player["id"],
                        "name": player["name"],
                        "seat": player["seat"],
                    }
                    for player in state["players"]
                ],
                "host_player_id": state["host_player_id"],
                "selected_roles": state.get("selected_roles")
                or [
                    *(player["original_role"] for player in state["players"]),
                    *state["original_center"],
                ],
            }
        elif "selected_roles" not in state:
            state["selected_roles"] = GameService._default_roles(len(state["players"]))
        state.update(
            {
                "id": row["id"],
                "room_code": row["room_code"],
                "status": row["status"],
                "revision": row["revision"],
            }
        )
        return RoomState.model_validate(state)

    @staticmethod
    def _check_revision(game: GameState, expected: int | None) -> None:
        GameService._check_revision_value(game.revision, expected)

    @staticmethod
    def _check_revision_value(current: int, expected: int | None) -> None:
        if expected is not None and current != expected:
            raise GameConflictError("Game changed on another device; refresh and retry")

    @staticmethod
    def _room_code() -> str:
        alphabet = string.ascii_uppercase.replace("I", "").replace("O", "") + "23456789"
        return "".join(secrets.choice(alphabet) for _ in range(6))

    @staticmethod
    def _now() -> str:
        return datetime.now(UTC).isoformat()

    @staticmethod
    def _default_roles(player_count: int) -> list[Role]:
        target_count = player_count + 3
        deck = [
            Role.werewolf,
            Role.minion,
            Role.seer,
            Role.robber,
            Role.troublemaker,
            Role.insomniac,
        ]
        if player_count >= 4:
            deck.append(Role.werewolf)
        if len(deck) < target_count:
            deck.extend([Role.villager] * (target_count - len(deck)))
        return deck[:target_count]

    @staticmethod
    def _validate_role_count(roles: list[Role], player_count: int) -> None:
        if len(roles) != player_count + 3:
            raise GameActionError(
                "Role count must equal player count plus 3 center cards"
            )

    @staticmethod
    def _authorize_host(
        row: dict,
        room: RoomState,
        player_id: str,
        player_token: str,
    ) -> None:
        tokens = row.get("player_tokens") or {}
        if player_id != room.host_player_id or tokens.get(player_id) != player_token:
            raise RoomAuthorizationError("Only the room host can configure this game")

    @staticmethod
    def _player(game: GameState, player_id: str) -> GamePlayer:
        player = next(
            (candidate for candidate in game.players if candidate.id == player_id),
            None,
        )
        if player is None:
            raise GameActionError("Unknown player")
        return player

    def _werewolf_action(
        self, game: GameState, actor_id: str, center_targets: list[int]
    ) -> list[Role]:
        partners = [
            player.original_role
            for player in game.players
            if player.id != actor_id and player.original_role is Role.werewolf
        ]
        if partners:
            if center_targets:
                raise GameActionError("Only a lone Werewolf may view a center card")
            return partners
        if len(center_targets) != 1:
            raise GameActionError("A lone Werewolf must choose one center card")
        return [game.center[self._center_index(center_targets[0])]]

    def _seer_action(
        self,
        game: GameState,
        actor_id: str,
        player_targets: list[str],
        center_targets: list[int],
    ) -> list[Role]:
        if len(player_targets) == 1 and not center_targets:
            target = self._player(game, player_targets[0])
            if target.id == actor_id:
                raise GameActionError("The Seer must choose another player")
            return [target.current_role]
        if not player_targets and len(center_targets) == 2:
            indices = [self._center_index(index) for index in center_targets]
            if len(set(indices)) != 2:
                raise GameActionError("Choose two different center cards")
            return [game.center[index] for index in indices]
        raise GameActionError("The Seer views one player or two center cards")

    @staticmethod
    def _minion_action(
        game: GameState,
        player_targets: list[str],
        center_targets: list[int],
    ) -> list[Role]:
        if player_targets or center_targets:
            raise GameActionError("The Minion does not choose a card")
        return [
            player.original_role
            for player in game.players
            if player.original_role is Role.werewolf
        ]

    def _robber_action(
        self, game: GameState, actor_id: str, player_targets: list[str]
    ) -> list[Role]:
        if len(player_targets) != 1:
            raise GameActionError("The Robber must choose one player")
        actor = self._player(game, actor_id)
        target = self._player(game, player_targets[0])
        if target.id == actor.id:
            raise GameActionError("The Robber must choose another player")
        actor.current_role, target.current_role = (
            target.current_role,
            actor.current_role,
        )
        return [actor.current_role]

    def _troublemaker_action(
        self, game: GameState, actor_id: str, player_targets: list[str]
    ) -> None:
        if len(player_targets) != 2 or len(set(player_targets)) != 2:
            raise GameActionError("The Troublemaker must choose two players")
        first = self._player(game, player_targets[0])
        second = self._player(game, player_targets[1])
        if actor_id in {first.id, second.id}:
            raise GameActionError("The Troublemaker cannot choose themself")
        first.current_role, second.current_role = (
            second.current_role,
            first.current_role,
        )

    def _insomniac_action(
        self,
        game: GameState,
        actor_id: str,
        player_targets: list[str],
        center_targets: list[int],
    ) -> list[Role]:
        if player_targets or center_targets:
            raise GameActionError("The Insomniac only views their own card")
        return [self._player(game, actor_id).current_role]

    @staticmethod
    def _resolve(game: GameState) -> GameResult:
        counts = Counter(game.votes.values())
        highest = max(counts.values(), default=0)
        eliminated = (
            sorted(player_id for player_id, count in counts.items() if count == highest)
            if highest >= 2
            else []
        )
        werewolves = sorted(
            player.id for player in game.players if player.current_role is Role.werewolf
        )
        minions = {
            player.id for player in game.players if player.current_role is Role.minion
        }
        if werewolves:
            village_wins = any(player_id in werewolves for player_id in eliminated)
            winning_team = "village" if village_wins else "werewolves"
        elif minions:
            village_wins = not eliminated or any(
                player_id in minions for player_id in eliminated
            )
            winning_team = "village" if village_wins else "minion"
        else:
            village_wins = not eliminated
            winning_team = "village" if village_wins else "werewolves"
        tallies = [
            VoteTally(player_id=player.id, votes=counts[player.id])
            for player in sorted(game.players, key=lambda item: item.seat)
        ]
        return GameResult(
            winning_team=winning_team,
            eliminated_player_ids=eliminated,
            werewolf_player_ids=werewolves,
            tallies=tallies,
        )

    @staticmethod
    def _center_index(index: int) -> int:
        if index not in {0, 1, 2}:
            raise GameActionError("Center card index must be 0, 1, or 2")
        return index
