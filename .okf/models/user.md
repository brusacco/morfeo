---
type: Model
title: User
description: Frontend users with authentication
resource: app/models/user.rb
tags: [auth, users]
timestamp: 2026-09-22T00:00:00Z
---

# Overview

The User model represents frontend users who can access the platform and view topics assigned to them.

# Schema

| Field                  | Type     | Description                  |
| ---------------------- | -------- | ---------------------------- |
| email                  | string   | User email (unique)          |
| password_digest        | string   | Encrypted password           |
| reset_password_token   | string   | Password reset token         |
| reset_password_sent_at | datetime | When reset token was sent    |
| remember_created_at    | datetime | When remember-me was created |
| created_at             | datetime | Account creation date        |
| updated_at             | datetime | Last update date             |

# Associations

- `has_many :user_topics` - Topic assignments ([UserTopic](user_topic.md))
- `has_many :topics, through: :user_topics` - Topics user can access ([Topic](topic.md))

# Authentication

Uses Devise with modules: `database_authenticatable`, `recoverable`, `rememberable`, `validatable`.

# Related

- [User Access Control](../business_rules/user_access_control.md) - Authentication and authorization rules
