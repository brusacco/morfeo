---
type: Model
title: Newspaper
description: Newspaper archival records
resource: app/models/newspaper.rb
tags: [archival, newspapers]
timestamp: 2026-09-22T00:00:00Z
---

# Overview

The Newspaper model stores archival records of newspapers, including cover and backcover images.

# Schema

| Field     | Type       | Description         |
| --------- | ---------- | ------------------- |
| site_id   | integer    | Foreign key to Site |
| date      | date       | Newspaper date      |
| cover     | attachment | Cover image         |
| backcover | attachment | Backcover image     |

# Associations

- `belongs_to :site` - The site this newspaper is from ([Site](site.md))
- `has_many :newspaper_texts` - Text content from the newspaper ([NewspaperText](newspaper_text.md))
