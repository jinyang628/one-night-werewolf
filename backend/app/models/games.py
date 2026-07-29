from enum import StrEnum

from pydantic import BaseModel, Field, model_validator


class Role(StrEnum):
    werewolf = "werewolf"
    minion = "minion"
    seer = "seer"
    robber = "robber"
    troublemaker = "troublemaker"
    insomniac = "insomniac"
    villager = "villager"


class GameMode(StrEnum):
    pass_and_play = "pass_and_play"
    room = "room"


class GameStatus(StrEnum):
    waiting = "waiting"
    in_progress = "in_progress"
    complete = "complete"


class GamePhase(StrEnum):
    role_reveal = "role_reveal"
    night = "night"
    discussion = "discussion"
    voting = "voting"
    complete = "complete"


class PlayerInput(BaseModel):
    id: str = Field(min_length=1)
    name: str = Field(min_length=1, max_length=30)
    seat: int = Field(ge=1)


class GamePlayer(BaseModel):
    id: str
    name: str
    seat: int
    original_role: Role
    current_role: Role


class VoteTally(BaseModel):
    player_id: str
    votes: int


class GameResult(BaseModel):
    winning_team: str
    eliminated_player_ids: list[str]
    werewolf_player_ids: list[str]
    tallies: list[VoteTally]


class GameState(BaseModel):
    id: str
    room_code: str
    mode: GameMode
    status: GameStatus
    phase: GamePhase
    revision: int = 0
    host_player_id: str | None = None
    players: list[GamePlayer]
    original_center: list[Role]
    center: list[Role]
    revealed_role_player_ids: list[str] = Field(default_factory=list)
    completed_action_player_ids: list[str] = Field(default_factory=list)
    votes: dict[str, str] = Field(default_factory=dict)
    discussion_started_at: str | None = None
    result: GameResult | None = None


class StartGameRequest(BaseModel):
    players: list[PlayerInput] = Field(min_length=3, max_length=8)
    roles: list[Role] = Field(min_length=6, max_length=11)

    @model_validator(mode="after")
    def validate_players(self):
        ids = [player.id for player in self.players]
        seats = [player.seat for player in self.players]
        if len(ids) != len(set(ids)):
            raise ValueError("Player ids must be unique")
        if sorted(seats) != list(range(1, len(self.players) + 1)):
            raise ValueError("Seats must be numbered consecutively from 1")
        if len(self.roles) != len(self.players) + 3:
            raise ValueError("Role count must equal player count plus 3 center cards")
        return self


class NightActionRequest(BaseModel):
    actor_id: str
    player_targets: list[str] = Field(default_factory=list, max_length=2)
    center_targets: list[int] = Field(default_factory=list, max_length=2)
    expected_revision: int | None = Field(default=None, ge=0)


class NightActionResponse(BaseModel):
    game: GameState
    seen_roles: list[Role] = Field(default_factory=list)


class AdvanceGameRequest(BaseModel):
    player_id: str | None = None
    expected_revision: int | None = Field(default=None, ge=0)


class VoteRequest(BaseModel):
    voter_id: str
    target_id: str
    expected_revision: int | None = Field(default=None, ge=0)


class VoteResponse(BaseModel):
    game: GameState


class CreateRoomRequest(BaseModel):
    player_name: str = Field(min_length=1, max_length=30)


class JoinRoomRequest(BaseModel):
    player_name: str = Field(min_length=1, max_length=30)


class StartRoomRequest(BaseModel):
    player_id: str
    player_token: str
    expected_revision: int | None = Field(default=None, ge=0)


class ConfigureRoomRolesRequest(BaseModel):
    player_id: str
    player_token: str
    roles: list[Role] = Field(min_length=4, max_length=11)
    expected_revision: int | None = Field(default=None, ge=0)


class RoomPlayer(BaseModel):
    id: str
    name: str
    seat: int


class RoomState(BaseModel):
    id: str
    room_code: str
    status: GameStatus
    revision: int
    players: list[RoomPlayer]
    host_player_id: str
    selected_roles: list[Role]


class RoomSession(BaseModel):
    room: RoomState
    player_id: str
    player_token: str
