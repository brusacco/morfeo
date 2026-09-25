from pydantic import BaseModel, Field


class ExtractRequest(BaseModel):
    text: str = Field(min_length=1)


class EntityResult(BaseModel):
    text: str
    type: str
    confidence: float
    start: int
    end: int


class ExtractResponse(BaseModel):
    entities: list[EntityResult]


class BatchDocument(BaseModel):
    id: str
    text: str = Field(min_length=1)


class BatchExtractRequest(BaseModel):
    documents: list[BatchDocument]


class BatchResult(BaseModel):
    id: str
    entities: list[EntityResult]


class BatchExtractResponse(BaseModel):
    documents: list[BatchResult]
