---
type: Model
title: Template
description: Report templates for topics
resource: app/models/template.rb
tags: [reports, templates]
timestamp: 2026-09-22T00:00:00Z
---

# Overview

The Template model stores report templates that can be applied to topics for consistent reporting.

# Schema

| Field         | Type    | Description              |
| ------------- | ------- | ------------------------ |
| topic_id      | integer | Foreign key to Topic     |
| admin_user_id | integer | Foreign key to AdminUser |
| name          | string  | Template name            |
| content       | text    | Template content         |
| start_date    | date    | Default start date       |
| end_date      | date    | Default end date         |

# Associations

- `belongs_to :topic` - The topic this template is for ([Topic](topic.md))
- `belongs_to :admin_user` - The admin who created the template ([AdminUser](admin_user.md))
