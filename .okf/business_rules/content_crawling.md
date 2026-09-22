---
type: Business Rule
title: Content Crawling
description: Website crawling and article extraction business rules
tags: [crawling, content, extraction, scheduling]
timestamp: 2026-09-22T00:00:00Z
---

# Overview

Morfeo crawls monitored websites on a scheduled basis to extract new articles and store them as Entry records.

# Rules

## Crawling Schedule

- Main web crawler runs hourly via `rake crawler`
- JavaScript-heavy sites use Selenium-based crawler via `rake headless_crawler`
- Crawling is configured per-site with inclusion/exclusion filters

## Article Extraction

- Each article is stored as an Entry record with a unique URL
- Duplicate URLs are prevented via database unique constraint
- Articles are extracted with title, content, image URL, and publication date
- Content filtering uses CSS selectors configured per site

## Site Configuration

- Sites can be enabled/disabled individually
- JavaScript sites are flagged with `is_js: true` for Selenium crawling
- Each site can have custom filters for content inclusion/exclusion
- Site logos are stored as Base64-encoded images

## Entry Status

- Entries have an `enabled` flag for active/inactive status
- Entries can be marked as `repeated` (No/Si/Limpiado) for duplicate detection
- Entries are associated with a Site via foreign key

# Related

- [Entry Model](../models/entry.md) - Entry data structure
- [Site Model](../models/site.md) - Site configuration
