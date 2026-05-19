"""HuggingFace Inference API embeddings (no local torch/sentence-transformers).

We deliberately implement this with a tiny httpx wrapper so the production image
stays under ~200 MB and starts in seconds on Render's free tier.
"""
from __future__ import annotations

import asyncio
from functools import lru_cache
from typing import List

import httpx

from .config import get_settings

_HF_BASE = "https://api-inference.huggingface.co/pipeline/feature-extraction"


class HFInferenceEmbedder:
    def __init__(self, model: str, token: str, dim: int = 384) -> None:
        self.model = model
        self.token = token
        self.dim = dim
        self._url = f"{_HF_BASE}/{model}"
        self._headers = {"Authorization": f"Bearer {token}"} if token else {}

    # ---- async core ----
    async def _embed_async(self, inputs: List[str]) -> List[List[float]]:
        if not inputs:
            return []
        if not self.token:
            raise RuntimeError(
                "HF_API_TOKEN is not set. Get a free token at "
                "https://huggingface.co/settings/tokens and add it to .env"
            )

        async with httpx.AsyncClient(timeout=60.0) as client:
            # HF cold-start protection: retry once on 503 with `wait_for_model`.
            for attempt in range(2):
                resp = await client.post(
                    self._url,
                    headers=self._headers,
                    json={
                        "inputs": inputs,
                        "options": {"wait_for_model": True, "use_cache": True},
                    },
                )
                if resp.status_code == 503 and attempt == 0:
                    await asyncio.sleep(2)
                    continue
                resp.raise_for_status()
                data = resp.json()
                break

        # HF returns either:
        #   * list[list[float]]                  for sentence-similarity models
        #   * list[list[list[float]]]            for token-level (mean-pooled here)
        out: List[List[float]] = []
        for v in data:
            if v and isinstance(v[0], list):
                # token-level: mean-pool
                cols = list(zip(*v))
                pooled = [sum(c) / len(c) for c in cols]
                out.append(pooled)
            else:
                out.append(v)  # already a flat vector
        return out

    # ---- sync facade (LangChain Embeddings interface) ----
    def embed_documents(self, texts: List[str]) -> List[List[float]]:
        return asyncio.run(self._embed_async(texts))

    def embed_query(self, text: str) -> List[float]:
        return self.embed_documents([text])[0]

    async def aembed_documents(self, texts: List[str]) -> List[List[float]]:
        return await self._embed_async(texts)

    async def aembed_query(self, text: str) -> List[float]:
        v = await self._embed_async([text])
        return v[0]


@lru_cache
def get_embedder() -> HFInferenceEmbedder:
    s = get_settings()
    return HFInferenceEmbedder(
        model=s.hf_embedding_model,
        token=s.hf_api_token,
        dim=s.embedding_dim,
    )
