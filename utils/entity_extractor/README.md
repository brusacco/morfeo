# Morfeo Entity Extractor

Small internal FastAPI service for local entity extraction with GLiNER2.

## Responsibility

This service does only:

    text -> extracted entity spans

It intentionally does **not** connect to MariaDB and does not know about Morfeo
Topics, Tags, aliases, or entity resolution. Rails remains the source of truth.

## Default model

`fastino/gliner2.5-multi-v1`

The multilingual checkpoint is used because Morfeo primarily processes Spanish
content.

## Run with Docker

```bash
docker build -t morfeo-entity-extractor .
docker run --rm   -p 127.0.0.1:8001:8000   -v morfeo_gliner_models:/models/huggingface   morfeo-entity-extractor
```

The first startup downloads the configured model. The Docker volume preserves
the Hugging Face cache across container recreation.

Or adapt `docker-compose.example.yml` into the project's compose configuration.

## Health

```bash
curl http://127.0.0.1:8001/health
```

## Extract entities

```bash
curl -X POST http://127.0.0.1:8001/v1/entities   -H 'Content-Type: application/json'   -d '{
    "text": "Santiago Peña se reunió con autoridades del Instituto de Previsión Social en Asunción."
  }'
```

Response contract:

```json
{
  "entities": [
    {
      "text": "Santiago Peña",
      "type": "person",
      "confidence": 0.95,
      "start": 0,
      "end": 13
    }
  ]
}
```

## Batch endpoint

```bash
curl -X POST http://127.0.0.1:8001/v1/entities/batch   -H 'Content-Type: application/json'   -d '{
    "documents": [
      {"id": "entry:123", "text": "Santiago Peña visitó Asunción."},
      {"id": "twitter:99", "text": "Representantes del IPS dieron una conferencia."}
    ]
  }'
```

The V1 batch endpoint processes documents sequentially. Its API contract is
already suitable for a future native GLiNER2 batch implementation.

## Production notes

- Keep `uvicorn --workers 1` initially. Multiple workers can load multiple model
  copies and increase RAM consumption.
- Inference is serialized by a process-local lock until CPU/RAM behavior is
  benchmarked on the Morfeo production server.
- Keep this endpoint private (`127.0.0.1` or an internal Docker network).
- Entity extraction should be called asynchronously from Sidekiq.
- If this service is unavailable, let Sidekiq retry rather than failing content
  ingestion.
- Rails should perform entity resolution and persist `entities`,
  `entity_aliases`, and `entity_mentions`.

## Rails configuration

Suggested environment variable:

```bash
ENTITY_EXTRACTOR_URL=http://127.0.0.1:8001
```

Suggested Rails abstraction:

    EntityExtractionService
      -> EntityExtractors::Gliner
      -> HTTP POST /v1/entities
      -> EntityResolutionService

Do not expose GLiNER-specific details throughout the Rails application.
