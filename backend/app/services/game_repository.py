import logging
from typing import Protocol

from postgrest.exceptions import APIError
from starlette.concurrency import run_in_threadpool

from app.clients.supabase import get_supabase_service_client

log = logging.getLogger(__name__)


class GamePersistenceError(RuntimeError):
    pass


class GameNotFoundError(LookupError):
    pass


class GameConflictError(RuntimeError):
    pass


class GameRepository(Protocol):
    async def create(self, payload: dict) -> dict: ...

    async def get_by_id(self, game_id: str) -> dict: ...

    async def get_by_room_code(self, room_code: str) -> dict: ...

    async def update(self, game_id: str, revision: int, payload: dict) -> dict: ...


class SupabaseGameRepository:
    async def create(self, payload: dict) -> dict:
        return await run_in_threadpool(self._create, payload)

    async def get_by_id(self, game_id: str) -> dict:
        return await run_in_threadpool(self._get_by_id, game_id)

    async def get_by_room_code(self, room_code: str) -> dict:
        return await run_in_threadpool(self._get_by_room_code, room_code)

    async def update(self, game_id: str, revision: int, payload: dict) -> dict:
        return await run_in_threadpool(self._update, game_id, revision, payload)

    @staticmethod
    def _create(payload: dict) -> dict:
        try:
            response = (
                get_supabase_service_client().table("games").insert(payload).execute()
            )
        except APIError as exc:
            log.error("Failed to create game: %s", exc)
            raise GamePersistenceError(str(exc)) from exc
        if not response.data:
            raise GamePersistenceError("Supabase did not return the created game")
        return response.data[0]

    @staticmethod
    def _get_by_id(game_id: str) -> dict:
        try:
            response = (
                get_supabase_service_client()
                .table("games")
                .select("*")
                .eq("id", game_id)
                .limit(1)
                .execute()
            )
        except APIError as exc:
            log.error("Failed to load game: %s", exc)
            raise GamePersistenceError(str(exc)) from exc
        if not response.data:
            raise GameNotFoundError("Game not found")
        return response.data[0]

    @staticmethod
    def _get_by_room_code(room_code: str) -> dict:
        try:
            response = (
                get_supabase_service_client()
                .table("games")
                .select("*")
                .eq("room_code", room_code)
                .limit(1)
                .execute()
            )
        except APIError as exc:
            log.error("Failed to load room: %s", exc)
            raise GamePersistenceError(str(exc)) from exc
        if not response.data:
            raise GameNotFoundError("Room not found")
        return response.data[0]

    @staticmethod
    def _update(game_id: str, revision: int, payload: dict) -> dict:
        try:
            response = (
                get_supabase_service_client()
                .table("games")
                .update(payload)
                .eq("id", game_id)
                .eq("revision", revision)
                .execute()
            )
        except APIError as exc:
            log.error("Failed to update game: %s", exc)
            raise GamePersistenceError(str(exc)) from exc
        if not response.data:
            raise GameConflictError("Game changed on another device; refresh and retry")
        return response.data[0]
