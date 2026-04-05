"""Central configuration loaded from environment variables."""
from functools import lru_cache
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    # App
    app_name: str = "Mitra Central"
    app_secret_key: str = "change-me"
    app_host: str = "0.0.0.0"
    app_port: int = 8000
    app_debug: bool = True

    # Auth (hardcoded Phase 1)
    auth_username: str = "admin"
    auth_password: str = "mfgpro"

    # Session
    session_cookie_name: str = "mitra_session"
    session_ttl_seconds: int = 28800

    # Redis
    redis_url: str = "redis://localhost:6379/0"

    # ODBC
    odbc_dsn: str = "QAD_PROGRESS"
    odbc_user: str = ""
    odbc_password: str = ""
    odbc_connection_string: str = ""

    # n8n webhooks
    n8n_webhook_mitra: str = ""
    n8n_webhook_apex: str = ""
    n8n_webhook_visual: str = ""
    n8n_webhook_qadzone: str = ""
    n8n_timeout_seconds: int = 60


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
