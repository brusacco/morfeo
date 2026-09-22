---
type: Model
title: NewspaperText
description: Daily content snapshots from newspapers
resource: app/models/newspaper_text.rb
tags: [archival, newspapers, content]
timestamp: 2026-09-22T00:00:00Z
---

# Overview

The NewspaperText model stores text content extracted from newspaper pages.

# Schema

| Field        | Type    | Description                  |
| ------------ | ------- | ---------------------------- |
| newspaper_id | integer | Foreign key to Newspaper     |
| content      | text    | Extracted text content       |
| page_number  | integer | Page number in the newspaper |

# Associations

- `belongs_to :newspaper` - The newspaper this text is from ([Newspaper](newspaper.md))
