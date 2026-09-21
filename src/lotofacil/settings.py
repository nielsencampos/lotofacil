"""Application configuration, loaded from environment variables (or a .env file)."""

from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    postgres_host: str = "localhost"
    postgres_port: int = 5432
    postgres_db: str = "lotofacil"
    postgres_user: str = "lotofacil"
    postgres_password: str = "lotofacil"

    lotofacil_api_base_url: str = "https://servicebus2.caixa.gov.br/portaldeloterias/api/lotofacil"
    lotofacil_data_dir: Path = Path("data/raw")

    holidays_api_base_url: str = "https://brasilapi.com.br/api/feriados/v1"
    holidays_seed_path: Path = Path("dbt/seeds/holidays.csv")

    @property
    def database_url(self) -> str:
        return (
            f"postgresql://{self.postgres_user}:{self.postgres_password}"
            f"@{self.postgres_host}:{self.postgres_port}/{self.postgres_db}"
        )


settings = Settings()
