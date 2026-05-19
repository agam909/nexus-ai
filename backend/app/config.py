from functools import lru_cache
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    # ── LLM (Groq) ─────────────────────────────────────────
    groq_api_key: str = ""
    groq_model: str = "llama-3.3-70b-versatile"

    # ── Embeddings (HuggingFace Inference API - no local torch) ──
    hf_api_token: str = ""
    hf_embedding_model: str = "sentence-transformers/all-MiniLM-L6-v2"
    embedding_dim: int = 384  # MiniLM-L6-v2 = 384

    # ── Vector DB (Qdrant Cloud) ──────────────────────────
    qdrant_url: str = ""           # e.g. https://xxxx.aws.cloud.qdrant.io:6333
    qdrant_api_key: str = ""
    qdrant_collection: str = "nexus_docs"

    # ── Database (Postgres on Neon, falls back to SQLite locally) ──
    database_url: str = "sqlite+aiosqlite:///./data/nexus.db"

    # ── Auth ──────────────────────────────────────────────
    jwt_secret: str = "change-me-in-production-please-use-a-long-random-string"
    jwt_algorithm: str = "HS256"
    jwt_expires_minutes: int = 60 * 24 * 30  # 30 days

    # ── Storage ───────────────────────────────────────────
    upload_dir: str = "./data/uploads"

    # ── RAG ───────────────────────────────────────────────
    chunk_size: int = 1000
    chunk_overlap: int = 150
    top_k: int = 4

    # ── HTTP ──────────────────────────────────────────────
    cors_origins: str = "*"
    host: str = "0.0.0.0"
    port: int = 8000

    @property
    def cors_list(self) -> list[str]:
        if self.cors_origins.strip() == "*":
            return ["*"]
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]

    @property
    def is_postgres(self) -> bool:
        return self.database_url.startswith(("postgres", "postgresql"))

    @property
    def normalized_db_url(self) -> str:
        """Render/Neon hand out `postgres://...?sslmode=require` URLs.
        SQLAlchemy needs the `postgresql+asyncpg://` driver, AND asyncpg does
        not understand the `sslmode` query param (that's a psycopg2 thing) -
        we strip it here and rely on `connect_args={'ssl': True}` in db.py."""
        import re
        url = self.database_url
        if url.startswith("postgres://"):
            url = "postgresql+asyncpg://" + url[len("postgres://"):]
        elif url.startswith("postgresql://") and "+asyncpg" not in url:
            url = "postgresql+asyncpg://" + url[len("postgresql://"):]
        # Drop sslmode=...  &  channel_binding=...  (psycopg-only params)
        url = re.sub(r"[?&](sslmode|channel_binding)=[^&]*", "", url)
        # Tidy any leftover dangling ? or & at the end
        url = re.sub(r"[?&]+$", "", url)
        # If we removed the only query and left a bare `?`, drop it
        url = url.replace("?&", "?")
        return url

    def ensure_dirs(self) -> None:
        Path(self.upload_dir).mkdir(parents=True, exist_ok=True)
        if self.database_url.startswith("sqlite"):
            # sqlite+aiosqlite:///./data/nexus.db
            p = self.database_url.split("///", 1)[-1]
            Path(p).parent.mkdir(parents=True, exist_ok=True)


@lru_cache
def get_settings() -> Settings:
    s = Settings()
    s.ensure_dirs()
    return s
