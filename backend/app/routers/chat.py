from __future__ import annotations

import json
import uuid
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import StreamingResponse
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from ..auth import get_current_user
from ..db import Conversation, Message, User, get_session
from ..llm import generate_answer, stream_answer
from ..rag import retrieve
from ..schemas import (
    ChatRequest,
    ChatResponse,
    ConversationDetail,
    ConversationSummary,
    MessageOut,
    Source,
)

router = APIRouter(tags=["chat"])


def _sources_from_docs(docs) -> list[Source]:
    out: list[Source] = []
    for d in docs:
        meta = d.metadata or {}
        page = meta.get("page")
        out.append(
            Source(
                file_name=meta.get("file_name", "unknown"),
                page=(page + 1) if isinstance(page, int) else None,
                snippet=(d.page_content or "")[:240].strip(),
                score=meta.get("score"),
            )
        )
    return out


async def _get_or_create_conversation(
    session: AsyncSession, user_id: str, conv_id: str | None, first_message: str
) -> Conversation:
    if conv_id:
        conv = await session.get(Conversation, conv_id)
        if conv and conv.user_id == user_id:
            return conv
    conv = Conversation(
        id=uuid.uuid4().hex,
        user_id=user_id,
        title=(first_message[:48] + "…") if len(first_message) > 48 else first_message,
    )
    session.add(conv)
    await session.flush()
    return conv


@router.post("/chat", response_model=ChatResponse)
async def chat(
    req: ChatRequest,
    session: AsyncSession = Depends(get_session),
    user: User = Depends(get_current_user),
):
    docs = await retrieve(req.message, user.id)
    history = [h.model_dump() for h in req.history]
    try:
        answer = await generate_answer(req.message, docs, history)
    except RuntimeError as e:
        raise HTTPException(503, str(e))
    except Exception as e:
        raise HTTPException(500, f"LLM failure: {e}")

    sources = _sources_from_docs(docs)

    conv = await _get_or_create_conversation(session, user.id, req.conversation_id, req.message)
    conv.updated_at = datetime.utcnow()
    session.add(
        Message(
            id=uuid.uuid4().hex,
            conversation_id=conv.id,
            role="user",
            content=req.message,
            sources_json="[]",
        )
    )
    session.add(
        Message(
            id=uuid.uuid4().hex,
            conversation_id=conv.id,
            role="assistant",
            content=answer,
            sources_json=json.dumps([s.model_dump() for s in sources]),
        )
    )
    await session.commit()

    return ChatResponse(answer=answer, conversation_id=conv.id, sources=sources)


@router.post("/chat/stream")
async def chat_stream(
    req: ChatRequest,
    session: AsyncSession = Depends(get_session),
    user: User = Depends(get_current_user),
):
    """ndjson stream:
       {"type":"meta","conversation_id":...,"sources":[...]}
       {"type":"token","value":"..."}
       {"type":"done"}
    """
    docs = await retrieve(req.message, user.id)
    history = [h.model_dump() for h in req.history]
    sources = _sources_from_docs(docs)
    conv = await _get_or_create_conversation(session, user.id, req.conversation_id, req.message)
    conv_id = conv.id
    session.add(
        Message(
            id=uuid.uuid4().hex,
            conversation_id=conv_id,
            role="user",
            content=req.message,
            sources_json="[]",
        )
    )
    await session.commit()

    async def gen():
        yield json.dumps(
            {
                "type": "meta",
                "conversation_id": conv_id,
                "sources": [s.model_dump() for s in sources],
            }
        ) + "\n"
        full = []
        try:
            async for tok in stream_answer(req.message, docs, history):
                full.append(tok)
                yield json.dumps({"type": "token", "value": tok}) + "\n"
        except Exception as e:
            yield json.dumps({"type": "error", "value": str(e)}) + "\n"
        answer = "".join(full)
        async for _ in _persist_assistant(conv_id, answer, sources):
            pass
        yield json.dumps({"type": "done"}) + "\n"

    return StreamingResponse(gen(), media_type="application/x-ndjson")


async def _persist_assistant(conv_id: str, answer: str, sources: list[Source]):
    from ..db import get_session as _gs
    async for s in _gs():
        conv = await s.get(Conversation, conv_id)
        if conv:
            conv.updated_at = datetime.utcnow()
        s.add(
            Message(
                id=uuid.uuid4().hex,
                conversation_id=conv_id,
                role="assistant",
                content=answer,
                sources_json=json.dumps([x.model_dump() for x in sources]),
            )
        )
        await s.commit()
        yield True
        return


@router.get("/conversations", response_model=list[ConversationSummary])
async def list_conversations(
    session: AsyncSession = Depends(get_session),
    user: User = Depends(get_current_user),
):
    res = await session.execute(
        select(Conversation)
        .where(Conversation.user_id == user.id)
        .order_by(Conversation.updated_at.desc())
    )
    rows = res.scalars().all()
    out: list[ConversationSummary] = []
    for r in rows:
        cnt = (
            await session.execute(
                select(func.count(Message.id)).where(Message.conversation_id == r.id)
            )
        ).scalar_one()
        out.append(
            ConversationSummary(
                id=r.id,
                title=r.title,
                created_at=r.created_at,
                updated_at=r.updated_at,
                message_count=cnt or 0,
            )
        )
    return out


@router.get("/conversations/{conv_id}", response_model=ConversationDetail)
async def get_conversation(
    conv_id: str,
    session: AsyncSession = Depends(get_session),
    user: User = Depends(get_current_user),
):
    conv = await session.get(Conversation, conv_id)
    if not conv or conv.user_id != user.id:
        raise HTTPException(404, "Conversation not found")
    res = await session.execute(
        select(Message)
        .where(Message.conversation_id == conv_id)
        .order_by(Message.created_at)
    )
    msgs = res.scalars().all()
    return ConversationDetail(
        id=conv.id,
        title=conv.title,
        created_at=conv.created_at,
        updated_at=conv.updated_at,
        messages=[
            MessageOut(
                id=m.id,
                role=m.role,
                content=m.content,
                sources=[Source(**s) for s in json.loads(m.sources_json or "[]")],
                created_at=m.created_at,
            )
            for m in msgs
        ],
    )


@router.delete("/conversations/{conv_id}")
async def delete_conversation(
    conv_id: str,
    session: AsyncSession = Depends(get_session),
    user: User = Depends(get_current_user),
):
    conv = await session.get(Conversation, conv_id)
    if not conv or conv.user_id != user.id:
        raise HTTPException(404, "Conversation not found")
    await session.delete(conv)
    await session.commit()
    return {"ok": True, "id": conv_id}
