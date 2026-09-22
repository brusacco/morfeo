---
okf_version: "0.1"
---

# Morfeo - News Monitoring & Analytics Platform

Morfeo is a Rails 7 news monitoring system that crawls websites, extracts articles, performs sentiment analysis, and generates reports. It's a media intelligence platform for Spanish-language news sources.

# Core Architecture

- [Models](models/) - Domain models and data structures
- [Digital Reports](digital_reports/) - Digital media (web articles) analytics dashboard infrastructure
- [Facebook Reports](facebook_reports/) - Facebook analytics dashboard infrastructure
- [Twitter Reports](twitter_reports/) - Twitter analytics dashboard infrastructure
- [Instagram Reports](instagram_reports/) - Instagram analytics dashboard infrastructure
- [Caching Strategy](caching_strategy.md) - Multi-layer caching architecture for fast report generation
- [Aggregator Services](aggregator_services.md) - Dashboard data aggregation services
- [PDF Report Generation](pdf_report_generation.md) - PDF report generation system
- [Twitter Account Management](twitter_account_management.md) - Multi-account Twitter API authentication with rate limit rotation
- [Scheduled Tasks](scheduled_tasks.md) - Complete documentation of all cron-scheduled rake tasks
- [Crawler Infrastructure](crawler_infrastructure.md) - Complete documentation of all crawler types and architectures
- [Controllers](controllers.md) - Controller layer architecture, authorization, and caching
- [Jobs](jobs.md) - Background jobs for crawling, sentiment analysis, and data synchronization
- [Services](services.md) - Service object architecture for business logic and data aggregation
- [Development Guidelines](development_guidelines.md) - Durable Rails development conventions and workflow

# Business Rules

- [Business Rules](business_rules/) - High-level business rules governing the platform
