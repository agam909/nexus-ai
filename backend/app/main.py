from __future__ import annotations

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from .config import get_settings
from .db import init_db
from .routers import auth as auth_router
from .routers import chat as chat_router
from .routers import documents as documents_router
from .routers import stats as stats_router

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)-7s | %(name)s | %(message)s",
)
log = logging.getLogger("nexus")


@asynccontextmanager
async def lifespan(app: FastAPI):
    await init_db()
    s = get_settings()
    log.info(
        "Nexus boot: db=%s | groq=%s | qdrant=%s | hf=%s",
        "postgres" if s.is_postgres else "sqlite",
        "yes" if s.groq_api_key else "MISSING",
        "yes" if s.qdrant_url else "MISSING",
        "yes" if s.hf_api_token else "MISSING",
    )
    yield


def create_app() -> FastAPI:
    s = get_settings()
    app = FastAPI(
        title="Nexus AI Backend",
        version="2.0.0",
        description=(
            "Production RAG backend — JWT auth, Postgres, Qdrant Cloud vector DB, "
            "HuggingFace embeddings, Groq LLM."
        ),
        lifespan=lifespan,
    )

    app.add_middleware(
        CORSMiddleware,
        allow_origins=s.cors_list,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    @app.middleware("http")
    async def access_log(request: Request, call_next):
        try:
            response = await call_next(request)
        except Exception as e:
            log.exception("Unhandled error on %s %s", request.method, request.url.path)
            return JSONResponse({"detail": "Internal server error"}, status_code=500)
        log.info("%s %s -> %s", request.method, request.url.path, response.status_code)
        return response

    app.include_router(auth_router.router)
    app.include_router(stats_router.router)
    app.include_router(documents_router.router)
    app.include_router(chat_router.router)

    @app.get("/", tags=["meta"])
    async def root():
        return {
            "name": "Nexus AI Backend",
            "version": "2.0.0",
            "docs": "/docs",
            "health": "/health",
        }

    @app.get("/healthz", tags=["meta"])
    async def healthz():
        """Lightweight liveness probe for uptime monitors."""
        return {"status": "ok"}

    return app


app = create_app()
