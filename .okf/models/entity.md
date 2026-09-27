---
type: Model
title: Entity
description: Canonical named entity detected by the GLiNER2 extraction service
resource: app/models/entity.rb
tags: [entity, nlp, gliner, content]
timestamp: 2026-09-27T00:00:00Z
---

# Overview

The Entity model represents a canonical named entity (person, location, organization, etc.) detected by the GLiNER2 extraction service. It is the resolved identity (e.g. "Instituto de Previsión Social"); the raw per-content detections live in [EntityMention](entity_mention.md).

# Schema

| Field       | Type   | Description                             |
| ----------- | ------ | --------------------------------------- |
| name        | string | Canonical entity text (unique per type) |
| entity_type | string | Entity category (person, location, …)   |

> The type column is `entity_type` (not `type`) to avoid Rails STI on `Entity < ApplicationRecord`.

# Associations

- `has_many :entity_mentions, dependent: :destroy` ([EntityMention](entity_mention.md))
- `has_many :entries, through: :entity_mentions` ([Entry](entry.md))
- (planned, no schema change) `has_many :facebook_entries / :twitter_posts / :instagram_posts, through: :entity_mentions`

# Validations

- `name` presence + unique within scope of `entity_type`
- `entity_type` presence

# Resolution

Initial resolution is an exact match on `[name, entity_type]` via `find_or_create_by!` in [EntityExtractor::PersistEntities](../entity_extraction.md). Alias resolution (e.g. "IPS" → "Instituto de Previsión Social") is a later step backed by a planned `entity_aliases` table.

# Related

- [Entity Extraction Service](../entity_extraction.md) - Architecture, GLiNER API, and persistence flow
- [EntityMention](entity_mention.md) - Raw detections per content item
