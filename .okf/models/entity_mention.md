---
type: Model
title: EntityMention
description: Polymorphic join model linking a canonical Entity to a content item with the raw GLiNER detection
resource: app/models/entity_mention.rb
tags: [entity, nlp, gliner, join, polymorphic, content]
timestamp: 2026-09-27T00:00:00Z
---

# Overview

The EntityMention model records a single entity detection inside a content item. It is the polymorphic join between [Entity](entity.md) and any content model — `Entry` now, and `FacebookEntry` / `TwitterPost` / `InstagramPost` later (no schema change needed). It stores the raw GLiNER detection so the same canonical entity can be mentioned many times with different surface forms and confidences.

# Schema

| Field        | Type    | Description                                  |
| ------------ | ------- | -------------------------------------------- |
| entity_id    | integer | Foreign key to Entity                        |
| content_type | string  | Polymorphic content class (Entry, …)         |
| content_id   | integer | Polymorphic content id                       |
| text         | string  | Surface form as detected (e.g. "IPS")        |
| entity_type  | string  | Entity category as detected                  |
| confidence   | float   | Model confidence (only > 0.9 are persisted)  |
| start        | integer | Starting character offset in the source text |
| end          | integer | Ending character offset in the source text   |

> `end` is a Ruby keyword — read it with `mention[:end]` and write it with the string key `'end' => value`.

# Associations

- `belongs_to :entity` ([Entity](entity.md))
- `belongs_to :content, polymorphic: true` ([Entry](entry.md) now; social models later)

# Validations

- `entity_id` unique within scope of `[content_type, content_id, start]` (prevents duplicate detections)
- `text` presence
- `entity_type` presence

# Related

- [Entity](entity.md) - Canonical entity identity
- [Entity Extraction Service](../entity_extraction.md) - Architecture and persistence flow
