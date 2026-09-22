---
type: Architecture
title: Development Guidelines
description: Durable Rails development conventions, operational workflow, and documentation ownership
tags: [rails, development, workflow, security]
timestamp: 2026-09-22T00:00:00Z
---

# Overview

Morfeo is a Rails news-monitoring and analytics platform. Detailed system knowledge belongs in this OKF bundle; repository instructions should remain a short routing layer that directs contributors here.

# Local Development

```bash
bin/dev

docker-compose up
```

`bin/dev` starts Rails and the Tailwind watcher. Docker Compose provides the Elasticsearch and Redis dependencies used by the application.

# Rails Conventions

## Services

Business logic belongs in service objects that inherit from `ApplicationService` and are invoked with `.call(...)`. Services return a result object with `success?` and either `data` or `error`; callers should handle failure explicitly.

## Controllers

- Keep controllers responsible for request handling and assigning view data.
- Put aggregate/report calculations in the appropriate dashboard or PDF service.
- Eager-load associations for collections rendered by views to avoid N+1 queries.
- Scope expensive dashboard work through the existing aggregators and caching layers.

## Topic Access

Topic-facing controllers authenticate users and use `TopicAuthorizable` after loading the topic:

```ruby
before_action :authenticate_user!
before_action :set_topic
before_action :authorize_topic_access!, only: [:show, :pdf]
```

Access requires an enabled topic and an assignment to the current user.

# Data and Background Work

- SQLite is used in development; MySQL is the production database.
- Redis backs caching and operational state.
- Scheduled rake tasks, defined in `config/schedule.rb`, perform most background processing.
- When modifying schedules, crawlers, reports, or cache keys, consult the corresponding architecture concept before changing code.

# Security and Operations

- Keep credentials exclusively in environment variables or Rails credentials; never commit them or paste them into documentation.
- Treat Twitter session cookies and third-party API tokens as secrets. Use the account-status and environment-verification rake tasks rather than logging token values.
- Validate user-controlled inputs, use parameterized Active Record queries, and preserve authorization checks on new topic endpoints.

# Documentation Ownership

Update this bundle when code changes alter a model, route, service contract, scheduled task, crawler, caching behavior, or report workflow. Keep `copilot-instructions.md` concise and link to the relevant OKF concept instead of duplicating implementation details.

# Related

- [Models](models/) - Domain data structures
- [Business Rules](business_rules/) - Product and processing behavior
- [Caching Strategy](caching_strategy.md) - Cache architecture
- [Aggregator Services](aggregator_services.md) - Dashboard aggregation conventions
- [PDF Report Generation](pdf_report_generation.md) - Report generation behavior
- [Scheduled Tasks](scheduled_tasks.md) - Background schedule
- [Crawler Infrastructure](crawler_infrastructure.md) - Collection mechanisms
- [Twitter Account Management](twitter_account_management.md) - Twitter credential rotation
