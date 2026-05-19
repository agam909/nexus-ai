from __future__ import annotations

import os
import shutil
import uuid
from pathlib import Path

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..auth import get_current_user
from ..config import get_settings
from ..db import Document, User, get_session
from ..rag import delete_doc, ingest
from ..schemas import DocumentOut, UploadResponse

router = APIRouter(tags=["documents"])

_ALLOWED = {".pdf", ".docx", ".txt", ".md"}


@router.post("/upload", response_model=UploadResponse)
async def upload(
    file: UploadFile = File(...),
    session: AsyncSession = Depends(get_session),
    user: User = Depends(get_current_user),
):
    s = get_settings()
    if not file.filename:
        raise HTTPException(400, "Missing filename")

    ext = Path(file.filename).suffix.lower()
    if ext not in _ALLOWED:
        raise HTTPException(
            400, f"Unsupported file type {ext}. Allowed: {sorted(_ALLOWED)}"
        )

    doc_id = uuid.uuid4().hex
    safe_name = f"{user.id}_{doc_id}{ext}"
    dest = Path(s.upload_dir) / safe_name

    try:
        with dest.open("wb") as out:
            shutil.copyfileobj(file.file, out)
    finally:
        await file.close()

    size = dest.stat().st_size
    try:
        chunks = await ingest(str(dest), doc_id, file.filename, user.id)
    except Exception as e:
        if dest.exists():
            dest.unlink(missing_ok=True)
        raise HTTPException(500, f"Failed to index document: {e}")

    if chunks == 0:
        if dest.exists():
            dest.unlink(missing_ok=True)
        raise HTTPException(400, "Document produced no extractable text")

    row = Document(
        id=doc_id,
        user_id=user.id,
        file_name=file.filename,
        size_bytes=size,
        chunks=chunks,
        storage_path=str(dest),
    )
    session.add(row)
    await session.commit()

    return UploadResponse(
        id=doc_id, file_name=file.filename, chunks=chunks, size_bytes=size
    )


@router.get("/documents", response_model=list[DocumentOut])
async def list_documents(
    session: AsyncSession = Depends(get_session),
    user: User = Depends(get_current_user),
):
    res = await session.execute(
        select(Document)
        .where(Document.user_id == user.id)
        .order_by(Document.created_at.desc())
    )
    rows = res.scalars().all()
    return [
        DocumentOut(
            id=r.id,
            file_name=r.file_name,
            size_bytes=r.size_bytes,
            chunks=r.chunks,
            created_at=r.created_at,
        )
        for r in rows
    ]


@router.delete("/documents/{doc_id}")
async def delete_document(
    doc_id: str,
    session: AsyncSession = Depends(get_session),
    user: User = Depends(get_current_user),
):
    row = await session.get(Document, doc_id)
    if not row or row.user_id != user.id:
        raise HTTPException(404, "Document not found")
    delete_doc(doc_id, user.id)
    if row.storage_path and os.path.exists(row.storage_path):
        try:
            os.remove(row.storage_path)
        except OSError:
            pass
    await session.delete(row)
    await session.commit()
    return {"ok": True, "id": doc_id}
