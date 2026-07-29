import logging
from datetime import UTC, datetime

from postgrest.exceptions import APIError
from starlette.concurrency import run_in_threadpool

from app.clients.supabase import get_supabase_service_client
from app.models.preferences import PreferencesRequest

log = logging.getLogger(__name__)


class PreferencesSaveError(RuntimeError):
    pass


class PreferencesStatusError(RuntimeError):
    pass


class PreferencesService:
    async def has_preferences(self, user_id: str) -> bool:
        return await run_in_threadpool(self._has_preferences, user_id=user_id)

    async def save_preferences(self, input: PreferencesRequest, user_id: str) -> None:
        payload = {
            "user_id": user_id,
            "name": input.name,
            "age": input.age,
            "sex": input.sex.value,
            "health_conditions": input.health_conditions,
            "distance_meters": input.distance_meters,
            "budget_level": input.budget_level,
            "diet_preferences": [
                preference.value for preference in input.diet_preferences
            ],
            "updated_at": datetime.now(UTC).isoformat(),
        }

        await run_in_threadpool(self._upsert_preferences, payload=payload)

    def _upsert_preferences(self, payload: dict) -> None:
        try:
            (
                get_supabase_service_client()
                .table("preferences")
                .upsert(payload, on_conflict="user_id")
                .execute()
            )
        except APIError as exc:
            log.error(exc)
            raise PreferencesSaveError(str(exc)) from exc

    def _has_preferences(self, user_id: str) -> bool:
        try:
            response = (
                get_supabase_service_client()
                .table("preferences")
                .select("user_id")
                .eq("user_id", user_id)
                .limit(1)
                .execute()
            )
        except APIError as exc:
            log.error(exc)
            raise PreferencesStatusError(str(exc)) from exc

        return bool(response.data)
