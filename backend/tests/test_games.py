import unittest
from datetime import UTC, datetime, timedelta

from app.models.games import (
    AdvanceGameRequest,
    ConfigureRoomRolesRequest,
    CreateRoomRequest,
    GameMode,
    GamePhase,
    GamePlayer,
    GameState,
    GameStatus,
    JoinRoomRequest,
    NightActionRequest,
    PlayerInput,
    Role,
    StartGameRequest,
    VoteRequest,
)
from app.services.game_repository import GameConflictError, GameNotFoundError
from app.services.games import GameService, RoomAuthorizationError


class MemoryGameRepository:
    def __init__(self):
        self.rows: dict[str, dict] = {}

    async def create(self, payload: dict) -> dict:
        row = dict(payload)
        row.setdefault("player_tokens", {})
        self.rows[row["id"]] = row
        return dict(row)

    async def get_by_id(self, game_id: str) -> dict:
        if game_id not in self.rows:
            raise GameNotFoundError("Game not found")
        return dict(self.rows[game_id])

    async def get_by_room_code(self, room_code: str) -> dict:
        for row in self.rows.values():
            if row["room_code"] == room_code:
                return dict(row)
        raise GameNotFoundError("Room not found")

    async def update(self, game_id: str, revision: int, payload: dict) -> dict:
        row = self.rows[game_id]
        if row["revision"] != revision:
            raise GameConflictError("stale")
        row.update(payload)
        return dict(row)


class GameServiceTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.repository = MemoryGameRepository()
        self.service = GameService(repository=self.repository)
        self.players = [
            PlayerInput(id="a", name="A", seat=1),
            PlayerInput(id="b", name="B", seat=2),
            PlayerInput(id="c", name="C", seat=3),
        ]
        self.start_request = StartGameRequest(
            players=self.players,
            roles=self.service._default_roles(3),
        )

    async def test_game_is_created_in_repository(self):
        game = await self.service.start_game(self.start_request)

        self.assertIn(game.id, self.repository.rows)
        self.assertEqual(game.status, "in_progress")
        self.assertEqual(len(game.players), 3)
        self.assertEqual(len(game.center), 3)
        all_roles = {player.original_role for player in game.players} | set(
            game.original_center
        )
        self.assertIn(Role.minion, all_roles)
        self.assertIn(Role.insomniac, all_roles)
        self.assertIn(Role.troublemaker, all_roles)
        self.assertEqual(
            game.night_roles,
            [
                Role.werewolf,
                Role.minion,
                Role.seer,
                Role.robber,
                Role.troublemaker,
                Role.insomniac,
            ],
        )

    async def test_night_timeline_includes_roles_dealt_to_the_center(self):
        game = await self.service.start_game(self.start_request)
        center_only_roles = {
            *game.original_center,
        } - {player.original_role for player in game.players}

        self.assertTrue(center_only_roles)
        self.assertTrue(center_only_roles.issubset(set(game.night_roles)))

        for player in game.players:
            game = await self.service.acknowledge_role(
                game.id,
                AdvanceGameRequest(player_id=player.id),
            )
        stored_state = self.repository.rows[game.id]["state"]
        stored_state["night_started_at"] = (
            datetime.now(UTC)
            - timedelta(
                seconds=len(game.night_roles)
                * self.service._night_slot_seconds(game)
                + 1
            )
        ).isoformat()

        advanced = await self.service.get_game(game.id)

        self.assertEqual(advanced.phase, GamePhase.discussion)

    def test_minion_wins_when_no_werewolf_is_present_and_someone_else_dies(self):
        game = GameState(
            id="game",
            room_code="ABC234",
            mode=GameMode.pass_and_play,
            status=GameStatus.complete,
            phase=GamePhase.complete,
            players=[
                GamePlayer(
                    id="a",
                    name="A",
                    seat=1,
                    original_role=Role.minion,
                    current_role=Role.minion,
                ),
                GamePlayer(
                    id="b",
                    name="B",
                    seat=2,
                    original_role=Role.seer,
                    current_role=Role.seer,
                ),
                GamePlayer(
                    id="c",
                    name="C",
                    seat=3,
                    original_role=Role.insomniac,
                    current_role=Role.insomniac,
                ),
            ],
            original_center=[
                Role.werewolf,
                Role.robber,
                Role.troublemaker,
            ],
            center=[Role.werewolf, Role.robber, Role.troublemaker],
            night_roles=[
                Role.werewolf,
                Role.minion,
                Role.seer,
                Role.robber,
                Role.troublemaker,
                Role.insomniac,
            ],
            night_started_at=None,
            ready_to_vote_player_ids=[],
            votes={"a": "b", "b": "c", "c": "b"},
        )

        result = self.service._resolve(game)

        self.assertEqual(result.winning_team, "minion")
        self.assertEqual(result.eliminated_player_ids, ["b"])
        self.assertEqual(
            self.service._insomniac_action(game, "c", [], []),
            [Role.insomniac],
        )
        self.assertEqual(self.service._minion_action(game, [], []), [])

    async def test_robber_action_is_persisted(self):
        game = await self.service.start_game(self.start_request)
        stored_state = self.repository.rows[game.id]["state"]
        stored_state["players"][0]["original_role"] = Role.robber.value
        stored_state["players"][0]["current_role"] = Role.robber.value
        stored_state["players"][1]["original_role"] = Role.werewolf.value
        stored_state["players"][1]["current_role"] = Role.werewolf.value
        game = await self.service.get_game(game.id)
        for player in game.players:
            game = await self.service.acknowledge_role(
                game.id,
                AdvanceGameRequest(
                    player_id=player.id,
                    expected_revision=game.revision,
                ),
            )
        robber = game.players[0]
        target = game.players[1]

        response = await self.service.perform_night_action(
            game.id,
            input=NightActionRequest(
                actor_id=robber.id,
                player_targets=[target.id],
                expected_revision=game.revision,
            ),
        )

        self.assertEqual(response.seen_roles, [Role.werewolf])
        persisted = await self.service.get_game(game.id)
        self.assertIn(robber.id, persisted.completed_action_player_ids)
        self.assertEqual(persisted.revision, game.revision + 1)

    async def test_final_vote_persists_result(self):
        game = await self.service.start_game(self.start_request)
        for player in game.players:
            game = await self.service.acknowledge_role(
                game.id,
                AdvanceGameRequest(
                    player_id=player.id,
                    expected_revision=game.revision,
                ),
            )
        stored_state = self.repository.rows[game.id]["state"]
        stored_state["phase"] = "discussion"
        game = await self.service.get_game(game.id)
        game = await self.service.end_discussion(
            game.id,
            AdvanceGameRequest(expected_revision=game.revision),
        )
        targets = {"a": "b", "b": "a", "c": "a"}
        current = game
        for voter_id, target_id in targets.items():
            response = await self.service.cast_vote(
                game.id,
                VoteRequest(
                    voter_id=voter_id,
                    target_id=target_id,
                    expected_revision=current.revision,
                ),
            )
            current = response.game

        self.assertEqual(current.status, "complete")
        self.assertIsNotNone(current.result)
        self.assertEqual(current.result.eliminated_player_ids, ["a"])

    async def test_remote_players_become_ready_and_vote_independently(self):
        game = await self.service.start_game(self.start_request)
        stored_state = self.repository.rows[game.id]["state"]
        stored_state["phase"] = "discussion"
        game = await self.service.get_game(game.id)

        game = await self.service.mark_ready_to_vote(
            game.id,
            AdvanceGameRequest(player_id="a"),
        )
        self.assertEqual(game.phase, GamePhase.discussion)
        self.assertEqual(game.ready_to_vote_player_ids, ["a"])

        response = await self.service.cast_vote(
            game.id,
            VoteRequest(voter_id="a", target_id="b"),
        )
        game = response.game
        self.assertEqual(game.votes, {"a": "b"})
        with self.assertRaisesRegex(ValueError, "not ready"):
            await self.service.cast_vote(
                game.id,
                VoteRequest(voter_id="b", target_id="a"),
            )

        for player_id in ("b", "c"):
            game = await self.service.mark_ready_to_vote(
                game.id,
                AdvanceGameRequest(player_id=player_id),
            )
        self.assertEqual(game.phase, GamePhase.voting)

        for voter_id, target_id in {"b": "a", "c": "a"}.items():
            response = await self.service.cast_vote(
                game.id,
                VoteRequest(voter_id=voter_id, target_id=target_id),
            )
            game = response.game
        self.assertEqual(game.phase, GamePhase.complete)
        self.assertIsNotNone(game.result)

    async def test_room_membership_and_tokens_are_persisted_server_side(self):
        host = await self.service.create_room(CreateRoomRequest(player_name="Host"))
        guest = await self.service.join_room(
            host.room.room_code,
            JoinRoomRequest(player_name="Guest"),
        )

        room = await self.service.get_room(host.room.room_code)
        stored = self.repository.rows[room.id]

        self.assertEqual([player.name for player in room.players], ["Host", "Guest"])
        self.assertEqual(stored["player_tokens"][host.player_id], host.player_token)
        self.assertEqual(stored["player_tokens"][guest.player_id], guest.player_token)
        self.assertNotIn("player_tokens", room.model_dump())

        configured_roles = [
            Role.werewolf,
            Role.minion,
            Role.seer,
            Role.robber,
            Role.troublemaker,
        ]
        configured = await self.service.configure_room_roles(
            room.room_code,
            ConfigureRoomRolesRequest(
                player_id=host.player_id,
                player_token=host.player_token,
                roles=configured_roles,
                expected_revision=room.revision,
            ),
        )
        self.assertEqual(configured.selected_roles, configured_roles)

        with self.assertRaises(RoomAuthorizationError):
            await self.service.configure_room_roles(
                room.room_code,
                ConfigureRoomRolesRequest(
                    player_id=guest.player_id,
                    player_token=guest.player_token,
                    roles=configured_roles,
                    expected_revision=configured.revision,
                ),
            )


if __name__ == "__main__":
    unittest.main()
