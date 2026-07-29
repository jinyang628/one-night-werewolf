import logging

from fastapi import APIRouter

from app.controllers.games import GamesController
from app.controllers.preferences import PreferencesController
from app.services.game_repository import SupabaseGameRepository
from app.services.games import GameService
from app.services.preferences import PreferencesService

log = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1")

### Health check


@router.get("/status")
async def status():
    log.info("Status endpoint called")
    return {"status": "ok"}


### Preferences


def get_preferences_controller_router():
    service = PreferencesService()
    return PreferencesController(service=service).router


router.include_router(
    get_preferences_controller_router(),
    tags=["preferences"],
    prefix="/preferences",
)


### Games


def get_games_controller_router():
    service = GameService(repository=SupabaseGameRepository())
    return GamesController(service=service).router


router.include_router(
    get_games_controller_router(),
    tags=["games"],
    prefix="/games",
)
