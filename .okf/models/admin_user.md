---
type: Model
title: AdminUser
description: ActiveAdmin users with separate authentication
resource: app/models/admin_user.rb
tags: [auth, admin]
timestamp: 2026-09-22T00:00:00Z
---

# Overview

The AdminUser model represents users who can access the ActiveAdmin interface for content management.

# Schema

| Field                  | Type     | Description                  |
| ---------------------- | -------- | ---------------------------- |
| email                  | string   | Admin email (unique)         |
| password_digest        | string   | Encrypted password           |
| reset_password_token   | string   | Password reset token         |
| reset_password_sent_at | datetime | When reset token was sent    |
| remember_created_at    | datetime | When remember-me was created |
| created_at             | datetime | Account creation date        |
| updated_at             | datetime | Last update date             |

# Associations

- `has_many :templates` - Report templates created by this admin ([Template](template.md))

# Authentication

Uses Devise with modules: `database_authenticatable`, `recoverable`, `rememberable`, `validatable`.

# Related

- [User Access Control](../business_rules/user_access_control.md) - Authentication and authorization rules
