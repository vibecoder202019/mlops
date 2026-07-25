import os
import httpx
from fastapi import FastAPI
from pydantic import BaseModel
from qdrant_client import QdrantClient

app = FastAPI()
qdrant = QdrantClient(url=os.getenv("QDRANT_URL", "http://qdrant:6333"))
EMBEDDING_URL = os.getenv("EMBEDDING_URL", "http://embedding:8080")
LLM_URL = os.getenv("LLM_URL", "http://vllm:8000")
COLLECTION = "documents"


class QueryRequest(BaseModel):
    question: str
    top_k: int = 3


class QueryResponse(BaseModel):
    answer: str
    sources: list[str]


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/query", response_model=QueryResponse)
async def query(req: QueryRequest):
    async with httpx.AsyncClient(timeout=120.0) as client:
        emb = await client.post(f"{EMBEDDING_URL}/embed", json={"texts": [req.question]})
        vector = emb.json()["embeddings"][0]

        try:
            hits = qdrant.search(collection_name=COLLECTION, query_vector=vector, limit=req.top_k)
            context = "\n".join([h.payload.get("text", "") for h in hits])
            sources = list({h.payload.get("source", "unknown") for h in hits})
        except Exception:
            context = ""
            sources = []

        prompt = f"Context:\n{context}\n\nQuestion: {req.question}\n\nAnswer:"
        llm = await client.post(
            f"{LLM_URL}/v1/completions",
            json={"model": "meta-llama/Llama-3.2-1B-Instruct", "prompt": prompt, "max_tokens": 200},
        )
        answer = llm.json()["choices"][0]["text"].strip()

    return QueryResponse(answer=answer, sources=sources)
