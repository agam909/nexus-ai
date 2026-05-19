from __future__ import annotations

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, EmailStr, Field


# ─── Auth ──────────────────────────────────────────────────────


class SignupRequest(BaseModel):
    email: EmailStr
    password: str = Field(..., min_length=6, max_length=128)
    name: Optional[str] = Field(default=None, max_length=120)


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(..., min_length=1)


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: "UserOut"


class UserOut(BaseModel):
    id: str
    email: EmailStr
    name: str
    created_at: datetime


# ─── Chat / RAG ───────────────────────────────────────────────


class Source(BaseModel):
    file_name: str
    page: Optional[int] = None
    snippet: Optional[str] = None
    score: Optional[float] = None


class HistoryItem(BaseModel):
    role: str
    content: str


class ChatRequest(BaseModel):
    message: str = Field(..., min_length=1)
    conversation_id: Optional[str] = None
    history: list[HistoryItem] = Field(default_factory=list)


class ChatResponse(BaseModel):
    answer: str
    conversation_id: str
    sources: list[Source] = Field(default_factory=list)


# ─── Documents ────────────────────────────────────────────────


class UploadResponse(BaseModel):
    id: str
    file_name: str
    chunks: int
    size_bytes: int


class DocumentOut(BaseModel):
    id: str
    file_name: str
    size_bytes: int
    chunks: int
    created_at: datetime


# ─── Stats / Conversations ────────────────────────────────────


class StatsResponse(BaseModel):
    documents: int
    chunks: int
    conversations: int
    messages: int
    model: str


class ConversationSummary(BaseModel):
    id: str
    title: str
    created_at: datetime
    updated_at: datetime
    message_count: int


class MessageOut(BaseModel):
    id: str
    role: str
    content: str
    sources: list[Source] = Field(default_factory=list)
    created_at: datetime


class ConversationDetail(BaseModel):
    id: str
    title: str
    created_at: datetime
    updated_at: datetime
    messages: list[MessageOut]


TokenResponse.model_rebuild()
