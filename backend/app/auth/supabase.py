from typing import Annotated

from fastapi import Header, HTTPException, status
from starlette.concurrency import run_in_threadpool

from app.clients.supabase import get_supabase_auth_client
from app.config.supabase import SupabaseConfigError


async def get_current_user_id(
    authorization: Annotated[str | None, Header()] = None,
) -> str:
    token = _extract_bearer_token(authorization=authorization)

    try:
        response = await run_in_threadpool(
            get_supabase_auth_client().auth.get_user,
            token,
        )
    except SupabaseConfigError as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(exc),
        ) from exc
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired access token",
        ) from exc

    user_id = response.user.id if response and response.user else None
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid access token",
        )

    return user_id


def _extract_bearer_token(authorization: str | None) -> str:
    if not authorization:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing authorization header",
        )

    scheme, _, token = authorization.partition(" ")
    if scheme.lower() != "bearer" or not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authorization header",
        )

    return token
