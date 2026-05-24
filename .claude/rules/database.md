---
description: Database migration and query rules for all schema and ORM files
paths:
  - "migrations/**/*"
  - "alembic/**/*"
  - "**/models.py"
  - "**/schema.prisma"
  - "src/**/repository.py"
  - "src/**/*repository*.py"
  - "src/**/*repository*.ts"
---

# Database Rules — Scoped Rule

Applies to migration files, ORM models, and repository implementations.

---

## Migration Standards

- Every schema change requires a migration file. No manual schema alterations in any environment.
- Migration files are **forward-only**. Provide a rollback script in `migrations/rollbacks/`.
- Migration names describe the change: `20240315_add_audit_events_table.sql`.
- Large table migrations (>1M rows) must use `CONCURRENTLY` for index creation and batched updates.
- Never `DROP COLUMN` in the same migration that removes the code using it — deprecate in step 1, drop in step 2.
- Test migrations on a production-sized dataset snapshot before merge.

---

## Query Safety

- Parameterized queries exclusively. String interpolation into SQL is forbidden.
- Repository methods must declare explicit column projections — no `SELECT *`.
- N+1 queries are forbidden. Use eager loading / joins when accessing related entities.
- Long-running queries must have explicit timeouts set at the connection or query level.

---

## Repository Pattern

- Business logic layer receives domain objects — never raw database rows.
- Repository interfaces live in the domain layer. Implementations live in infrastructure.
- Unit tests mock the repository interface. Integration tests use a real test database.
