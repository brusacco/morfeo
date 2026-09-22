---
type: Business Rule
title: User Access Control
description: Authentication and authorization rules
tags: [auth, users, access, authorization]
timestamp: 2026-09-22T00:00:00Z
---

# Overview

Morfeo uses a dual authentication system with separate user types for frontend access and admin management.

# Rules

## Frontend Users

- Model: `User`
- Authentication: Devise with database_authenticatable, recoverable, rememberable, validatable
- Access: Can view topics they're assigned to
- Topic assignment: Via `UserTopic` join model
- Cannot manage content or configuration

## Admin Users

- Model: `AdminUser`
- Authentication: Separate Devise configuration
- Access: ActiveAdmin interface for content management
- Can manage: Sites, topics, tags, users, reports, templates
- Can perform bulk operations via scoped collection actions

## Topic Authorization

- All topic controllers use `TopicAuthorizable` concern
- `authorize_topic_access!` checks:
  1. Topic exists
  2. Topic status is enabled
  3. User is assigned to topic
- Unauthorized users redirected to root with alert message

## API Access

- Public API endpoints under `/api/v1/`
- Uses Rack CORS for cross-origin requests
- Separate from web authentication

# Related

- [User Model](../models/user.md) - Frontend user structure
- [AdminUser Model](../models/admin_user.md) - Admin user structure
- [UserTopic Model](../models/user_topic.md) - Topic assignment
- [Topic Organization](topic_organization.md) - Topic access rules
