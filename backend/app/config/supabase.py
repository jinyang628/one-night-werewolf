import os


class SupabaseConfigError(RuntimeError):
    pass


class SupabaseConfig:
    @staticmethod
    def url() -> str:
        return _required_env("SUPABASE_URL").rstrip("/")

    @staticmethod
    def anon_key() -> str:
        return _required_env("SUPABASE_ANON_KEY")

    @staticmethod
    def service_role_key() -> str:
        return _required_env("SUPABASE_SERVICE_ROLE_KEY")


def _required_env(name: str) -> str:
    value = os.getenv(name)
    if value is None or not value.strip():
        raise SupabaseConfigError(f"{name} is not configured")

    return value.strip()
