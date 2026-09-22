---
type: concept
title: Admin Interface
description: ActiveAdmin-based admin panel for managing entries, topics, sites, users, and analytics
tags:
  - admin
  - activeadmin
  - management
  - dashboard
---

# Admin Interface

Morfeo uses ActiveAdmin for its admin panel, accessible at `/admin`. The admin interface provides management capabilities for all core entities.

## Admin Resources

### Content Management

- **Entries** (`/admin/entries`) - Manage news articles, view sentiment, edit tags
- **Facebook Entries** (`/admin/facebook_entries`) - Manage Facebook posts
- **Twitter Posts** (`/admin/twitter_posts`) - Manage Twitter posts
- **Instagram Posts** (`/admin/instagram_posts`) - Manage Instagram posts

### Topic & Tag Management

- **Topics** (`/admin/topics`) - Create, edit, and manage topics
- **Tags** (`/admin/tag`) - Manage tags and their associations

### Site Management

- **Sites** (`/admin/sites`) - Configure monitored websites and crawling settings

### Social Media Profiles

- **Pages** (`/admin/pages`) - Manage Facebook pages
- **Twitter Profiles** (`/admin/twitter_profiles`) - Manage Twitter profile tracking
- **Instagram Profiles** (`/admin/instagram_profiles`) - Manage Instagram profile tracking

### User Management

- **Users** (`/admin/users`) - Manage frontend users
- **Admin Users** (`/admin/admin_users`) - Manage admin accounts

### Analytics & Reporting

- **Topic Stats Daily** (`/admin/topic_stat_dailies`) - View daily topic statistics
- **Title Topic Stats Daily** (`/admin/title_topic_stat_dailies`) - View title-tag statistics
- **Templates** (`/admin/templates`) - Manage report templates

### Audit & History

- **Versions** (`/admin/versions`) - PaperTrail audit log for all changes
- **Newspapers** (`/admin/newspapers`) - Newspaper archival records

## Dashboard

The admin dashboard (`/admin/dashboard`) provides an overview of key metrics and recent activity.

## Authentication

Admin authentication uses Devise with the `AdminUser` model, separate from frontend user authentication.

## Customization

Admin resources are defined in `app/admin/` with custom filters, actions, and views as needed.