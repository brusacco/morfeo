---
type: Model
title: Version
description: PaperTrail versioning for audit trails
resource: app/models/version.rb
tags: [versioning, audit]
timestamp: 2026-09-22T00:00:00Z
---

# Overview

The Version model is used by the PaperTrail gem to track changes to models over time, providing an audit trail.

# Usage

Models that need versioning include `has_paper_trail` (e.g., Topic). Each change creates a new Version record with the serialized object state.
