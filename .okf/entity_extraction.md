---
type: Architecture
title: Entity Extraction Service
description: GLiNER2-based named-entity extraction service (Python/FastAPI) and its Rails integration for the Entity & Narrative Intelligence layer
resource: app/services/entity_extractor/extract_entities.rb
tags:
  [entity-extraction, gliner, nlp, fastapi, architecture, entity-intelligence]
timestamp: 2026-09-27T00:00:00Z
---

# Overview

Morfeo uses a small internal Python service powered by **GLiNER2** to extract named entities from ingested content.

The service runs independently from Rails and exposes a private HTTP API. Its responsibility is intentionally limited to:

```
Text → Entity Detection → Structured Entity Spans
```

All business logic remains in the Rails application, including entity resolution, aliases, persistence, content associations, and historical backfills.

# Current Implementation Status

The extraction service is being introduced incrementally. What exists in the codebase today:

- **Python service** — FastAPI + GLiNER2 (`fastino/gliner2.5-multi-v1`), deployed in Docker and bound to `127.0.0.1:8001`. The service source no longer lives under `app/services/entity_extractor/` (it was moved to its own deployment location); that directory now holds the Rails client.
- **Rails HTTP client** — [`EntityExtractor::ExtractEntities`](services.md) (`app/services/entity_extractor/extract_entities.rb`), an `ApplicationService` that POSTs `text` to `/v1/entities` and returns `result.entities` (array of `{ text, type, confidence, start, end }`) or `result.error`.
  - Endpoint resolution order: explicit `api_url:` argument → `ENV['ENTITY_API_URL']` → default `http://www.morfeo.com.py:8001/v1/entities`.
- **Persistence service** — `EntityExtractor::PersistEntities` (`app/services/entity_extractor/persist_entities.rb`). `call(text:, content:)` extracts, keeps only detections with `confidence > 0.9` (`MIN_CONFIDENCE`; lower ones are counted as `ignored`), resolves each to a canonical [Entity](models/entity.md) via `find_or_create_by!(name:, entity_type:)`, and records an [EntityMention](models/entity_mention.md) on the content object. On extraction failure nothing is persisted and the result is a failure (callers must retry, never mark complete).
- **Models** — [Entity](models/entity.md) (canonical identity: `name`, `entity_type`) and [EntityMention](models/entity_mention.md) (polymorphic join `content_type`/`content_id` + raw detection `text`, `entity_type`, `confidence`, `start`, `end`). `Entry` is wired (`has_many :entities, through: :entity_mentions`); `FacebookEntry`/`TwitterPost`/`InstagramPost` join later with two association lines each and **no schema migration**.
  - The type column is `entity_type` (not `type`) to avoid Rails STI. `end` is a Ruby keyword — access via `mention[:end]` / `'end' =>`.
- **Tasks** — `rake entities:test[limit]` (read-only diagnostic, prints ALL detections) and `rake entities:extract[limit]` (persists with the 0.9 confidence threshold). Both analyze `title + content` (truncated to 4000 chars) of the last N `Entry.enabled` rows. `extract` resolves the last-N id set up front (`pluck(:id)` ordered by `published_at: :desc`), then streams it with `in_batches(of: 100, order: :asc)` so only one batch is in memory at a time (processing order is by id, not publish date). See [Scheduled Tasks](scheduled_tasks.md).

The following pieces from the target architecture below are **not yet implemented** and are the intended next steps:

- `EntityExtractionWorker` (Sidekiq) for asynchronous extraction.
- A provider-independent `EntityExtractionService` façade delegating to an `EntityExtractors::Gliner` adapter (the current client `EntityExtractor::ExtractEntities` is the interim GLiNER adapter).
- `entity_aliases` table and alias resolution (e.g. "IPS" → "Instituto de Previsión Social").
- Wiring the social content models (`FacebookEntry`, `TwitterPost`, `InstagramPost`) to `EntityMention`.
- Use of the batch endpoint (`POST /v1/entities/batch`) for backfills.

# Architecture

```
Morfeo Content
      │
      ▼
EntityExtractionWorker
      │
      ▼
EntityExtractionService (Rails)
      │
      │ HTTP
      ▼
GLiNER2 Entity Extractor
      │
      ▼
Extracted entities
      │
      ▼
Entity Resolution (Rails)
      │
      ▼
entities / entity_aliases / entity_mentions
```

The extraction service does **not** connect to the Morfeo database.

It does not know about Topics, Tags, Tag Variations, or Morfeo's entity-resolution rules.

This separation allows the extraction model to be replaced or upgraded without coupling the rest of the application to GLiNER2.

# Technology

The service uses:

- Python 3.11
- FastAPI
- Uvicorn
- GLiNER2
- PyTorch
- Hugging Face Transformers

The default model is:

```
fastino/gliner2.5-multi-v1
```

The multilingual model is used because Morfeo primarily processes Spanish-language content.

The model runs locally. No article or social-media content needs to be sent to an external LLM API for entity extraction.

# Supported Entity Types

The initial extraction schema recognizes:

```
person
company
government_institution
political_party
organization
country
location
economic_sector
```

The extraction schema can be expanded later without changing the core Rails entity model.

# Docker Deployment

The service runs in Docker so its Python, PyTorch, Transformers, and GLiNER2 dependencies remain isolated from the host operating system.

This is particularly useful on the current Morfeo server, whose system Python version does not need to be changed.

Build the image from the entity extractor directory:

```
sudo docker build -t morfeo-entity-extractor .
```

Run it:

```
sudo docker run -d \
  --name morfeo-entity-extractor \
  --restart unless-stopped \
  --memory=6g \
  --cpus=4 \
  -p 127.0.0.1:8001:8000 \
  -v morfeo_gliner_models:/models/huggingface \
  morfeo-entity-extractor
```

The service is intentionally bound to:

```
127.0.0.1:8001
```

and should not be exposed publicly.

Rails accesses it through the local server.

The container is initially restricted to:

```
Memory: 6 GB
CPU:    4 cores
Workers: 1
```

These conservative limits protect MariaDB, Puma, Sidekiq, and other production workloads.

# Model Cache

The Hugging Face model cache is stored in the Docker volume:

```
morfeo_gliner_models
```

This prevents the model from being downloaded again whenever the container is recreated.

The volume is mounted as:

```
morfeo_gliner_models:/models/huggingface
```

Removing the container does not remove this volume.

# Starting and Stopping

Stop:

```
sudo docker stop morfeo-entity-extractor
```

Start:

```
sudo docker start morfeo-entity-extractor
```

Restart:

```
sudo docker restart morfeo-entity-extractor
```

Check status:

```
sudo docker ps --filter name=morfeo-entity-extractor
```

Include stopped containers:

```
sudo docker ps -a --filter name=morfeo-entity-extractor
```

Follow logs:

```
sudo docker logs -f morfeo-entity-extractor
```

Inspect resource usage:

```
sudo docker stats morfeo-entity-extractor
```

# Health Check

The service exposes:

```
GET /health
```

Example:

```
curl http://127.0.0.1:8001/health
```

Expected response:

```
{
  "status": "ok",
  "model_loaded": true
}
```

A successful health check indicates that the HTTP service is running and the GLiNER2 model has been loaded.

# Entity Extraction API

Endpoint:

```
POST /v1/entities
```

Request:

```
{
  "text": "Santiago Peña se reunió con autoridades del Instituto de Previsión Social en Asunción."
}
```

Example:

```
curl -s \
  -X POST http://127.0.0.1:8001/v1/entities \
  -H 'Content-Type: application/json' \
  -d '{
    "text": "Santiago Peña se reunió con autoridades del Instituto de Previsión Social en Asunción."
  }' | jq
```

Example response:

```
{
  "entities": [
    {
      "text": "Santiago Peña",
      "type": "person",
      "confidence": 0.9985911250114441,
      "start": 0,
      "end": 13
    },
    {
      "text": "Instituto de Previsión Social",
      "type": "government_institution",
      "confidence": 0.9831680655479431,
      "start": 44,
      "end": 73
    },
    {
      "text": "Asunción",
      "type": "location",
      "confidence": 0.9843350052833557,
      "start": 77,
      "end": 85
    }
  ]
}
```

Each result contains:

- `text` — entity text exactly as detected in the source
- `type` — entity category
- `confidence` — model confidence
- `start` — starting character offset
- `end` — ending character offset

The API deliberately returns extraction results rather than resolved Morfeo entities.

For example, GLiNER2 may return:

```
IPS
```

while Rails may resolve that value to:

```
Instituto de Previsión Social
```

using Morfeo's entity aliases and existing knowledge.

# Batch API

A batch endpoint is also available:

```
POST /v1/entities/batch
```

Example request:

```
{
  "documents": [
    {
      "id": "entry:123",
      "text": "Santiago Peña visitó Asunción."
    },
    {
      "id": "twitter:99",
      "text": "Representantes del IPS dieron una conferencia."
    }
  ]
}
```

The document ID is returned with the extraction result so Rails can associate responses with their source records.

The initial implementation may process these documents sequentially internally. The API contract allows the implementation to use native GLiNER2 batching later without requiring changes to Rails.

# Rails Configuration

Configure:

```
ENTITY_EXTRACTOR_URL=http://127.0.0.1:8001
```

The Rails integration should remain provider-independent:

```
EntityExtractionService
        │
        ▼
EntityExtractors::Gliner
        │
        ▼
POST /v1/entities
```

Application code should use `EntityExtractionService` rather than calling GLiNER2 directly.

This makes it possible to replace GLiNER2 later with another local model or provider without changing the rest of the entity pipeline.

> **Note (current code):** the interim client `EntityExtractor::ExtractEntities` reads `ENV['ENTITY_API_URL']` (default `http://www.morfeo.com.py:8001/v1/entities`). When the provider-independent `EntityExtractionService` / `EntityExtractors::Gliner` layering is introduced, it should standardize on `ENTITY_EXTRACTOR_URL`.

# Entity Extraction vs Entity Resolution

These are deliberately separate operations.

## Extraction

GLiNER2 answers:

> What real-world entities appear in this text?

For example:

```
Santiago Peña
IPS
Asunción
Banco Central del Paraguay
```

## Resolution

Rails answers:

> Which known Morfeo entity does this mention represent?

For example:

```
IPS
        │
        ▼
EntityAlias
        │
        ▼
Instituto de Previsión Social
```

Resolution uses Morfeo's own database and may also leverage existing Tag Variations as known aliases where appropriate.

GLiNER2 must not decide canonical identity.

# Topics, Tags, and Entities

Entities do not replace Morfeo's existing Topic/Tag system.

They represent different analytical concepts.

```
TOPIC
What monitoring universe are we analyzing?

TAG
How does Morfeo find/classify content belonging to that universe?

ENTITY
Who or what actually appears in the content?
```

For example, `IPS` may be configured as a Tag used to classify content.

The same article may contain entities such as:

```
Instituto de Previsión Social
Santiago Peña
María Teresa Barán
Asunción
Ministerio de Salud
```

Some may already exist in Morfeo's taxonomy; others may be discovered automatically.

Entity extraction therefore provides a discovery and analytical layer on top of the existing editorial taxonomy. See [Topic Organization](business_rules/topic_organization.md) and [Tag](models/tag.md).

# Failure Behavior

Entity extraction is asynchronous.

A GLiNER2 failure must not prevent Morfeo from ingesting content.

The intended flow is:

```
Content ingestion
      │
      ├── Content saved successfully
      │
      ▼
Sidekiq EntityExtractionWorker
      │
      ▼
GLiNER2
```

If the extraction service is unavailable, the Sidekiq job should fail normally and use the application's retry mechanism.

Do not silently mark extraction as completed when the GLiNER2 request fails.

# Production Considerations

The model is loaded once when the service starts.

The service currently runs with one Uvicorn worker:

```
--workers 1
```

Do not increase the worker count without measuring memory usage first. Multiple Python worker processes may result in multiple copies of the model being loaded into memory.

Inference is initially serialized to protect the production server from excessive CPU and memory pressure.

Monitor with:

```
sudo docker stats morfeo-entity-extractor
```

and:

```
free -h
```

before increasing concurrency.

Backfills should also be controlled because historical Morfeo data can generate a very large number of extraction requests.

# Updating the Service

After changing Python service code or dependencies:

```
sudo docker stop morfeo-entity-extractor
sudo docker rm morfeo-entity-extractor
```

Rebuild:

```
sudo docker build -t morfeo-entity-extractor .
```

Then recreate the container:

```
sudo docker run -d \
  --name morfeo-entity-extractor \
  --restart unless-stopped \
  --memory=6g \
  --cpus=4 \
  -p 127.0.0.1:8001:8000 \
  -v morfeo_gliner_models:/models/huggingface \
  morfeo-entity-extractor
```

The model cache remains available because it is stored in the persistent Docker volume.

# Current Scope

The service is currently responsible only for named-entity extraction.

It does not currently perform:

- entity resolution
- fuzzy identity matching
- entity sentiment
- narrative clustering
- embeddings
- influence scoring
- knowledge graph construction
- relationship extraction
- Topic/Tag classification

Those capabilities belong to later stages of Morfeo's Entity and Narrative Intelligence architecture.

Keeping the extraction service small and stateless makes it inexpensive to operate, easy to benchmark, and straightforward to replace as better extraction models become available.

# Related

- [Services](services.md) - Service object architecture (includes `EntityExtractor::ExtractEntities` and `EntityExtractor::PersistEntities`)
- [Entity](models/entity.md) - Canonical entity model
- [EntityMention](models/entity_mention.md) - Polymorphic mention/join model
- [Scheduled Tasks](scheduled_tasks.md) - `entities:test` (read-only) and `entities:extract` (persist) rake tasks
- [Jobs](jobs.md) - Background jobs (future `EntityExtractionWorker`)
- [Topic Organization](business_rules/topic_organization.md) - How Topics/Tags relate to Entities
- [Tag](models/tag.md) - Tag model (potential alias source for resolution)
