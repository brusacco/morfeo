from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException

from .extractor import EntityExtractor
from .schemas import (
    BatchExtractRequest,
    BatchExtractResponse,
    ExtractRequest,
    ExtractResponse,
)


extractor: EntityExtractor | None = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    global extractor
    extractor = EntityExtractor()
    yield
    extractor = None


app = FastAPI(
    title="Morfeo Entity Extractor",
    version="0.1.0",
    lifespan=lifespan,
)


@app.get("/health")
def health():
    return {
        "status": "ok" if extractor is not None else "starting",
        "model_loaded": extractor is not None,
    }


@app.post("/v1/entities", response_model=ExtractResponse)
def extract_entities(request: ExtractRequest):
    if extractor is None:
        raise HTTPException(status_code=503, detail="Model is not loaded")

    return {"entities": extractor.extract(request.text)}


@app.post("/v1/entities/batch", response_model=BatchExtractResponse)
def extract_entities_batch(request: BatchExtractRequest):
    if extractor is None:
        raise HTTPException(status_code=503, detail="Model is not loaded")

    # Intentionally simple V1 implementation. The API contract already supports
    # batching; this can later switch to GLiNER2's native batch API after
    # benchmarking without changing Rails.
    return {
        "documents": [
            {"id": document.id, "entities": extractor.extract(document.text)}
            for document in request.documents
        ]
    }
