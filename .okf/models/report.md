---
type: Model
title: Report
description: Generated reports for topics
resource: app/models/report.rb
tags: [reports, topics]
timestamp: 2026-09-22T00:00:00Z
---

# Overview

The Report model stores generated reports for topics, including AI-powered summaries and analytics.

# Schema

| Field      | Type     | Description            |
| ---------- | -------- | ---------------------- |
| topic_id   | integer  | Foreign key to Topic   |
| content    | text     | Report content         |
| created_at | datetime | Report generation date |
| updated_at | datetime | Last update date       |

# Associations

- `belongs_to :topic` - The topic this report is for ([Topic](topic.md))
