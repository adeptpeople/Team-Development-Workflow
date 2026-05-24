# Team Engineering Governance — CLAUDE.md

This file defines the universal engineering conventions for this project.
All AI-assisted contributors (Claude Code sessions) and human contributors
must follow every rule in this file without exception unless a scoped rule
file in `.claude/rules/` explicitly overrides it for a specific path.

---

## 1. Coding Standards

### Python
- Format with `black` (line length 100). Never commit unformatted files.
- Sort imports with `isort` (profile = `black`). Group order: stdlib → third-party → local.
- Type hints are **mandatory** on all function signatures and class attributes.
- All code must pass `mypy --strict` with zero errors.
- Use f-strings for string formatting; never `%` formatting or `.format()`.
- Maximum function length: 40 lines. Extract helpers when exceeded.
- Prefer `pathlib.Path` over `os.path` for filesystem operations.

### TypeScript / Node.js
- Format with `prettier` (printWidth 100, singleQuote true, trailingComma "all").
- Lint with `eslint` using the project's `.eslintrc`. Zero warnings permitted.
- Strict TypeScript: `"strict": true` in `tsconfig.json`. No `any` casts without a comment explaining why.
- Prefer named exports over default exports.
- Use `const` by default; use `let` only when reassignment is required. Never use `var`.

### All Languages
- No trailing whitespace. Files must end with a single newline.
- Remove dead code — no commented-out blocks left in commits.
- Avoid abbreviations in identifiers. `user_authentication_token` not `uat`.

---

## 2. Naming Conventions

| Construct         | Python              | TypeScript          |
|-------------------|---------------------|---------------------|
| Variables         | `snake_case`        | `camelCase`         |
| Functions/Methods | `snake_case`        | `camelCase`         |
| Classes           | `PascalCase`        | `PascalCase`        |
| Constants         | `UPPER_SNAKE_CASE`  | `UPPER_SNAKE_CASE`  |
| Interfaces        | N/A                 | `IPascalCase`       |
| Types             | N/A                 | `TPascalCase`       |
| Files (Python)    | `snake_case.py`     | N/A                 |
| Files (TS)        | N/A                 | `kebab-case.ts`     |
| Test files        | `test_*.py`         | `*.test.ts`         |
| Database tables   | `snake_case` plural | N/A                 |

- Boolean variables must start with `is_`, `has_`, `can_`, `should_`.
- Collection variables must be plural nouns (`users`, `order_ids`).
- Functions that return booleans must start with `is_`, `has_`, `check_`.
- Event handler functions in TS must start with `handle` (`handleSubmit`).

---

## 3. Architecture Guidelines

- Follow **Clean Architecture** layering: `domain → application → infrastructure → presentation`.
- No circular dependencies between layers. Domain layer has zero external imports.
- Feature-based directory structure: group by domain concept, not by type.
  ```
  src/
    orders/
      domain/
      application/
      infrastructure/
      api/
  ```
- Use the **Repository Pattern** for all data access. No raw database queries in service layer.
- Dependency injection over direct instantiation. Classes declare dependencies via constructor.
- No business logic in route handlers, controllers, or view components.
- New integrations (third-party APIs, queues, storage) require an interface + concrete adapter.
- ADRs are required for architectural decisions. See `docs/adr/` template.

---

## 4. Testing Standards

- **Minimum 85% line coverage** across all modules. CI will fail below threshold.
- **Bug fixes require a regression test** that fails before the fix and passes after.
- New features require unit tests for all public interfaces.
- Integration tests required for all external service integrations.
- Use the **AAA pattern**: Arrange → Act → Assert in every test.
- Tests must be deterministic: no time-dependent logic without mocking the clock.
- No real network calls in unit or integration tests. Use fixtures, mocks, or test containers.
- Test names must describe behavior: `test_create_order_returns_422_when_sku_missing`.
- Coverage exemptions require a `# pragma: no cover` comment with justification.

### Python
- Framework: `pytest` with `pytest-cov`.
- Factories via `factory_boy`. Fixtures in `conftest.py`.
- Use `freezegun` for time-dependent tests.

### TypeScript
- Framework: `vitest` (preferred) or `jest`.
- Mock with `vi.mock()` / `jest.mock()`. Never mock the module under test.
- Use `@testing-library` for component tests.

---

## 5. Error Handling Standards

- **Typed exceptions**: define domain-specific exception classes. Never raise bare `Exception`.
  ```python
  class OrderNotFoundError(ApplicationError):
      def __init__(self, order_id: str) -> None:
          super().__init__(f"Order {order_id} not found")
          self.order_id = order_id
  ```
- **No swallowed errors**: bare `except: pass` or empty catch blocks are forbidden.
- All caught exceptions must be logged or re-raised. At minimum: `logger.warning(...)`.
- Retry logic must use **exponential backoff** with jitter. Use `tenacity` (Python) or a standard retry utility (TS).
- Define maximum retry counts explicitly. Infinite retry loops are forbidden.
- User-facing error messages must never expose stack traces, internal identifiers, or system paths.
- HTTP error responses must conform to the project's error schema (see `.claude/rules/api-conventions.md`).

---

## 6. Logging Standards

- Use **structured logging** (JSON output in production). Library: `structlog` (Python), `pino` (TypeScript).
- Log levels:
  - `DEBUG`: developer diagnostics — never emitted in production.
  - `INFO`: normal operations (request received, job started).
  - `WARNING`: recoverable anomalies (retry triggered, degraded mode).
  - `ERROR`: unrecoverable failures requiring attention.
  - `CRITICAL`: system-level failures.
- Every log line must include: `trace_id`, `service`, `version`, `environment`.
- Never log PII (names, emails, passwords, tokens, card numbers) at any level.
- Do not log sensitive request/response payloads unless behind a debug flag gated by environment.

---

## 7. Security Standards

- **No hardcoded secrets**: zero tolerance. Secrets in code = PR rejected.
- All secrets must come from environment variables loaded via the project's secret manager.
- Use `.env.example` (committed) + `.env` (gitignored) for local development.
- Input validation is mandatory at all system entry points (API routes, CLI args, queue consumers).
- Use parameterized queries exclusively. String interpolation into SQL is forbidden.
- Authentication boundaries: every API route must explicitly declare its auth requirement.
- Dependency scanning runs in CI via `pip-audit` (Python) and `npm audit` (Node). Failures block merge.
- Never disable TLS certificate verification in production code.
- Principle of least privilege: request only the scopes/permissions the service needs.
- Security-sensitive changes (auth, cryptography, access control) require a security review comment in the PR.

---

## 8. Dependency Management

- Lock files are **committed** and kept up to date: `poetry.lock` / `package-lock.json`.
- Dependency updates must be in dedicated PRs — not bundled with feature work.
- Avoid pinning to patch versions unnecessarily. Pin to minor (`~=1.2`) for stability.
- Adding a new dependency requires a comment in the PR explaining why an existing library doesn't cover it.
- Transitive dependency conflicts must be resolved before merge — no `--force` installs.
- Node.js runtime: match the version in `.nvmrc`. Python: match the version in `.python-version`.

---

## 9. Documentation Standards

- **Public API docs**: every exported function, class, and endpoint must have a docstring/JSDoc.
  - One-line summary, param descriptions, return type, exception list.
- **README**: must be updated when: a new service is added, a setup step changes, a major feature lands.
- **Migration notes**: any breaking change requires a `MIGRATION.md` entry with before/after code.
- **ADRs**: decisions about architecture, frameworks, and patterns go in `docs/adr/NNNN-title.md`.
- Inline comments explain **why**, never **what**. If the code needs a "what" comment, rename identifiers.
- No auto-generated doc files committed to the repo. Docs are built in CI and published to the internal portal.

---

## 10. PR Quality Expectations

- **PR size**: maximum 400 lines changed (excluding generated files and lock files).
  Large changes must be split into a stack of smaller PRs.
- **PR description** must include:
  - What changed and why (link to ticket).
  - How to test it locally.
  - Screenshots for UI changes.
  - Risk assessment (low / medium / high).
- **No self-merges** on `main`. Minimum one approval from a team member.
- **CI must be green** before merge. No "merge and fix CI" — fix CI first.
- **Branch naming**: `type/ticket-id-short-description` (e.g., `feat/ORD-123-add-audit-events`).
- Squash-merge onto `main`. Commit message = PR title + ticket reference.
- Reviewers must be requested within 1 business day of PR creation.

---

## 11. AI Contributor Expectations (Claude Code specific)

- Follow all rules in this file as a hard constraint, not a suggestion.
- Before modifying a file, check whether a `.claude/rules/` file applies to that path.
- Never hardcode secrets, tokens, or credentials — not even as placeholders.
- When uncertain about a design decision, prefer `plan` mode and present options.
- Do not install dependencies without confirming with the developer.
- Surface test failures, lint errors, and type errors — do not suppress them.
- When completing a task, report: files changed, tests added, coverage delta, and any deferred work.
