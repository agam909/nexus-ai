"""LLM chain builder for RAG-grounded answers."""
from __future__ import annotations

from functools import lru_cache
from typing import AsyncGenerator

from langchain_core.documents import Document as LCDocument
from langchain_core.messages import AIMessage, HumanMessage, SystemMessage
from langchain_groq import ChatGroq

from .config import get_settings

SYSTEM_PROMPT = """You are Nexus, a premium AI assistant with access to the user's private knowledge base.

Rules:
- Answer concisely and helpfully using Markdown (headings, lists, code blocks where useful).
- When the provided CONTEXT is relevant, ground your answer in it and cite sources inline like [1], [2].
- If the CONTEXT is empty or unrelated, answer from general knowledge but say so briefly.
- Never invent file names, page numbers, or quotes that are not in CONTEXT.
- Be friendly, professional, and direct. No filler.
"""


@lru_cache
def get_llm() -> ChatGroq:
    s = get_settings()
    if not s.groq_api_key:
        raise RuntimeError(
            "GROQ_API_KEY is not set. Copy backend/.env.example to backend/.env "
            "and add your key from https://console.groq.com/keys"
        )
    return ChatGroq(
        api_key=s.groq_api_key,
        model=s.groq_model,
        temperature=0.3,
        max_tokens=1024,
    )


def format_context(docs: list[LCDocument]) -> str:
    if not docs:
        return "(no relevant context found)"
    parts = []
    for i, d in enumerate(docs, start=1):
        meta = d.metadata or {}
        name = meta.get("file_name", "unknown")
        page = meta.get("page")
        tag = f"[{i}] {name}" + (f" (page {page + 1})" if isinstance(page, int) else "")
        parts.append(f"{tag}\n{d.page_content.strip()}")
    return "\n\n---\n\n".join(parts)


def build_messages(
    question: str,
    context_docs: list[LCDocument],
    history: list[dict] | None = None,
) -> list:
    msgs = [SystemMessage(content=SYSTEM_PROMPT)]
    for h in (history or [])[-8:]:
        role = (h.get("role") or "").lower()
        content = h.get("content") or ""
        if not content:
            continue
        if role == "user":
            msgs.append(HumanMessage(content=content))
        elif role in ("assistant", "ai"):
            msgs.append(AIMessage(content=content))
    ctx = format_context(context_docs)
    msgs.append(
        HumanMessage(
            content=f"CONTEXT:\n{ctx}\n\nQUESTION:\n{question}"
        )
    )
    return msgs


async def stream_answer(
    question: str,
    context_docs: list[LCDocument],
    history: list[dict] | None = None,
) -> AsyncGenerator[str, None]:
    llm = get_llm()
    msgs = build_messages(question, context_docs, history)
    async for chunk in llm.astream(msgs):
        if chunk.content:
            yield chunk.content


async def generate_answer(
    question: str,
    context_docs: list[LCDocument],
    history: list[dict] | None = None,
) -> str:
    llm = get_llm()
    msgs = build_messages(question, context_docs, history)
    res = await llm.ainvoke(msgs)
    return res.content if isinstance(res.content, str) else str(res.content)
