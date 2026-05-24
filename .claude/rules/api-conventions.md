---
description: REST API design and enforcement rules for all files under src/api/
paths:
  - "src/api/**/*"
---

# API Conventions — Scoped Rule

Applies to all files matching `src/api/**/*`.
These rules extend and specialize the project CLAUDE.md for API layer code.

---

## REST Naming Conventions

- Resource URLs use **plural nouns**: `/orders`, `/users`, `/products`.
- URL segments are **kebab-case**: `/audit-events`, `/payment-methods`.
- No verbs in URLs. Actions are expressed via HTTP method:
  - `GET /orders` — list
  - `GET /orders/{id}` — fetch one
  - `POST /orders` — create
  - `PUT /orders/{id}` — full replace
  - `PATCH /orders/{id}` — partial update
  - `DELETE /orders/{id}` — remove
- Sub-resources use nested paths: `GET /orders/{id}/line-items`.
- Query parameters use `snake_case`: `?sort_by=created_at&page_size=20`.

---

## Standard Error Response Schema

Every error response must conform to this JSON schema:

```json
{
  "error": {
    "code": "ORDER_NOT_FOUND",
    "message": "The requested order does not exist.",
    "trace_id": "abc-123",
    "details": []
  }
}
```

- `code`: UPPER_SNAKE_CASE machine-readable error code.
- `message`: human-readable, safe for display. No internal details.
- `trace_id`: correlates to distributed trace. Always present.
- `details`: array of field-level validation errors (empty if not applicable).

HTTP status code mapping:
| Situation                        | Status |
|----------------------------------|--------|
| Validation failure               | 422    |
| Resource not found               | 404    |
| Unauthorized (no credentials)    | 401    |
| Forbidden (credentials, no perm) | 403    |
| Conflict (duplicate)             | 409    |
| Internal server error            | 500    |
| Unprocessable input              | 422    |

---

## Authentication Enforcement

- Every route handler must declare its auth requirement using the project's auth decorator/middleware.
- Public routes must be explicitly annotated `@public` or `auth: none` — never implicitly unauthenticated.
- Authenticated routes must validate the JWT/session on every request — no trust inheritance from adjacent routes.
- Auth errors return 401 (not 403) when credentials are missing or malformed.
- Auth errors return 403 when credentials are valid but permission is denied.

```python
# Required pattern — auth must be explicit
@router.get("/orders/{order_id}", auth=RequireScope("orders:read"))
async def get_order(order_id: str) -> OrderResponse:
    ...
```

---

## Pagination Standards

- All list endpoints support cursor-based pagination by default.
- Required query parameters: `cursor` (opaque string), `limit` (int, default 20, max 100).
- Response must include `next_cursor` (null when no more pages) and `total_count`.

```json
{
  "data": [...],
  "pagination": {
    "next_cursor": "eyJpZCI6MTIzfQ==",
    "total_count": 450,
    "limit": 20
  }
}
```

- Offset-based pagination is not permitted for new endpoints (unbounded scan risk).

---

## API Versioning Rules

- Version prefix in URL path: `/v1/`, `/v2/`.
- Breaking changes require a new version. Non-breaking additions do not.
- Breaking changes = removing a field, changing a field type, changing semantics.
- Deprecated endpoints must include `Deprecation` and `Sunset` headers.
- Old versions supported for minimum 6 months after new version GA.

---

## DTO Validation

- All request bodies must be validated via a typed schema class before reaching business logic.
  - Python: use `pydantic` `BaseModel` with strict validators.
  - TypeScript: use `zod` schemas with `.parse()` (not `.safeParse()` — raise on invalid input).
- Validation errors must be caught and returned as 422 with field-level `details` array.
- Do not pass raw `dict`/`object` to service layer — only validated DTO instances.
- Response DTOs must explicitly select fields — never pass ORM model objects to serializers directly.

```python
class CreateOrderRequest(BaseModel):
    sku: str = Field(..., min_length=3, max_length=50)
    quantity: int = Field(..., ge=1, le=1000)
    customer_id: UUID

class OrderResponse(BaseModel):
    id: UUID
    sku: str
    status: OrderStatus
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)
```

---

## Rate Limiting

- All public and authenticated endpoints must be covered by rate limit rules.
- Declare limits via middleware config, not ad-hoc per-handler.
- When rate limit exceeded: return `429 Too Many Requests` with `Retry-After` header.

---

## Idempotency

- `POST` endpoints that create resources must support `Idempotency-Key` header.
- Repeated requests with the same key return the same response as the first call.
- Idempotency window: minimum 24 hours.
