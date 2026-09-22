# Morfeo Development Instructions

Morfeo is a Rails news-monitoring and analytics platform. Use the OKF bundle at
[`../.okf/index.md`](../.okf/index.md) as the source of truth for detailed domain,
reporting, crawler, caching, scheduling, and integration knowledge.

## Knowledge Discovery

When a `.okf/` directory exists at the repository root:

- Use OKF first to understand business rules, architecture, terminology, and implementation patterns.
- Consult source code after locating the relevant concepts.
- If OKF does not contain the required information, rely on the existing implementation rather than assumptions.

If no `.okf/` directory exists, continue normally.

<!-- CODEGRAPH_START -->

## CodeGraph

In repositories indexed by CodeGraph (a `.codegraph/` directory exists at the repo root), reach for it BEFORE grep/find or reading files when you need to understand or locate code:

- **MCP tool** (when available): `codegraph_explore` answers most code questions in one call — the relevant symbols' verbatim source plus the call paths between them, including dynamic-dispatch hops grep can't follow. Name a file or symbol in the query to read its current line-numbered source. If it's listed but deferred, load it by name via tool search.
- **Shell** (always works): `codegraph explore "<symbol names or question>"` prints the same output.

If there is no `.codegraph/` directory, skip CodeGraph entirely — indexing is the user's decision.

<!-- CODEGRAPH_END -->

## Rails Workflow

- Preserve Rails conventions, existing public APIs, and the established service-object pattern.
- Put business logic in services inheriting from `ApplicationService`; use `.call(...)` and handle result objects explicitly.
- Keep controllers focused on request handling, authorization, and view assignment.
- Prevent N+1 queries with appropriate eager loading and use existing aggregators for report calculations.
- Make database changes through migrations with indexes and foreign keys where appropriate.
- Run the narrowest relevant test, lint, or Rails task after each change.

## Authorization and Security

- Topic controllers authenticate users, load the topic, then call `authorize_topic_access!` from `TopicAuthorizable`.
- Preserve authorization on every topic-facing action, including PDF and drill-down endpoints.
- Never commit, log, or paste credentials, session cookies, or API tokens. Keep them in environment variables or Rails credentials.
- Use parameterized Active Record queries and validate user-controlled input.

## Local Development

```bash
bin/dev
docker-compose up
```

`bin/dev` starts Rails and the Tailwind watcher. Docker Compose starts Redis and Elasticsearch.

## Documentation Maintenance

Update the relevant `.okf` concept whenever a change affects models, routes, services, scheduled tasks, crawler behavior, caching, or report generation. Start with [`../.okf/index.md`](../.okf/index.md), then use the relevant area:

- [Business rules](../.okf/business_rules/)
- [Report infrastructure](../.okf/digital_reports/)
- [Crawler infrastructure](../.okf/crawler_infrastructure.md)
- [Scheduled tasks](../.okf/scheduled_tasks.md)
- [Caching strategy](../.okf/caching_strategy.md)
- [PDF report generation](../.okf/pdf_report_generation.md)
