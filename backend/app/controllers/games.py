import logging

from fastapi import APIRouter, HTTPException, status

from app.models.games import (
    AdvanceGameRequest,
    ConfigureRoomRolesRequest,
    CreateRoomRequest,
    GameState,
    JoinRoomRequest,
    NightActionRequest,
    NightActionResponse,
    RoomSession,
    RoomState,
    StartGameRequest,
    StartRoomRequest,
    VoteRequest,
    VoteResponse,
)
from app.services.game_repository import (
    GameConflictError,
    GameNotFoundError,
    GamePersistenceError,
)
from app.services.games import (
    GameActionError,
    GameService,
    RoomAuthorizationError,
)

log = logging.getLogger(__name__)


class GamesController:
    def __init__(self, service: GameService):
        self.router = APIRouter()
        self.service = service
        self.setup_routes()

    def setup_routes(self):
        router = self.router

        @router.post("", response_model=GameState)
        async def start_game(input: StartGameRequest) -> GameState:
            log.info("Starting a persisted pass-and-play game")
            return await self._handle(self.service.start_game(input=input))

        @router.get("/{game_id}", response_model=GameState)
        async def get_game(game_id: str) -> GameState:
            return await self._handle(self.service.get_game(game_id=game_id))

        @router.post("/{game_id}/night-actions", response_model=NightActionResponse)
        async def perform_night_action(
            game_id: str,
            input: NightActionRequest,
        ) -> NightActionResponse:
            return await self._handle(
                self.service.perform_night_action(game_id=game_id, input=input)
            )

        @router.post("/{game_id}/role-acknowledgements", response_model=GameState)
        async def acknowledge_role(
            game_id: str,
            input: AdvanceGameRequest,
        ) -> GameState:
            return await self._handle(
                self.service.acknowledge_role(game_id=game_id, input=input)
            )

        @router.post("/{game_id}/end-discussion", response_model=GameState)
        async def end_discussion(
            game_id: str,
            input: AdvanceGameRequest,
        ) -> GameState:
            return await self._handle(
                self.service.end_discussion(game_id=game_id, input=input)
            )

        @router.post("/{game_id}/votes", response_model=VoteResponse)
        async def cast_vote(game_id: str, input: VoteRequest) -> VoteResponse:
            return await self._handle(
                self.service.cast_vote(game_id=game_id, input=input)
            )

        @router.post("/rooms", response_model=RoomSession)
        async def create_room(input: CreateRoomRequest) -> RoomSession:
            return await self._handle(self.service.create_room(input=input))

        @router.post("/rooms/{room_code}/join", response_model=RoomSession)
        async def join_room(room_code: str, input: JoinRoomRequest) -> RoomSession:
            return await self._handle(
                self.service.join_room(room_code=room_code, input=input)
            )

        @router.get("/rooms/{room_code}", response_model=RoomState)
        async def get_room(room_code: str) -> RoomState:
            return await self._handle(self.service.get_room(room_code=room_code))

        @router.put("/rooms/{room_code}/roles", response_model=RoomState)
        async def configure_room_roles(
            room_code: str,
            input: ConfigureRoomRolesRequest,
        ) -> RoomState:
            return await self._handle(
                self.service.configure_room_roles(
                    room_code=room_code,
                    input=input,
                )
            )

        @router.post("/rooms/{room_code}/start", response_model=GameState)
        async def start_room(room_code: str, input: StartRoomRequest) -> GameState:
            return await self._handle(
                self.service.start_room(room_code=room_code, input=input)
            )

    @staticmethod
    async def _handle(operation):
        try:
            return await operation
        except GameNotFoundError as exc:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)
            ) from exc
        except GameConflictError as exc:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT, detail=str(exc)
            ) from exc
        except RoomAuthorizationError as exc:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)
            ) from exc
        except GameActionError as exc:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)
            ) from exc
        except GamePersistenceError as exc:
            log.exception("Supabase game persistence failed")
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Failed to persist game state",
            ) from exc
