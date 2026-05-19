from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from ..auth import get_current_user
from ..config import get_settings
from ..db import Conversation, Document, Message, User, get_session
from ..rag import collection_count
from ..schemas import StatsResponse

router = APIRouter(tags=["stats"])


@router.get("/stats", response_model=StatsResponse)
async def stats(
    session: AsyncSession = Depends(get_session),
    user: User = Depends(get_current_user),
):
    s = get_settings()
    docs = (
        await session.execute(
            select(func.count(Document.id)).where(Document.user_id == user.id)
        )
    ).scalar_one()
    convs = (
        await session.execute(
            select(func.count(Conversation.id)).where(Conversation.user_id == user.id)
        )
    ).scalar_one()
    msgs = (
        await session.execute(
            select(func.count(Message.id))
            .join(Conversation, Conversation.id == Message.conversation_id)
            .where(Conversation.user_id == user.id)
        )
    ).scalar_one()
    return StatsResponse(
        documents=docs or 0,
        chunks=collection_count(user.id),
        conversations=convs or 0,
        messages=msgs or 0,
        model=s.groq_model,
    )


@router.get("/health")
async def health():
    """Public health probe used by uptime monitors and the Flutter client."""
    s = get_settings()
    return {
        "status": "ok",
        "model": s.groq_model,
        "groq_configured": bool(s.groq_api_key),
        "embeddings_configured": bool(s.hf_api_token),
        "vector_db_configured": bool(s.qdrant_url),
        "auth_required": True,
    }
