from functools import lru_cache

from supabase import Client, create_client

from app.config.supabase import SupabaseConfig


@lru_cache
def get_supabase_auth_client() -> Client:
    return create_client(SupabaseConfig.url(), SupabaseConfig.anon_key())


@lru_cache
def get_supabase_service_client() -> Client:
    return create_client(SupabaseConfig.url(), SupabaseConfig.service_role_key())
