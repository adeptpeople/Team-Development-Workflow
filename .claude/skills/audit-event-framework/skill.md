---
name: audit-event-framework
description: >
  Design and implement an audit event framework for a service. Analyzes the
  existing domain to identify auditable actions, proposes an event schema,
  generates the framework skeleton, and produces an integration guide.
  Runs in isolated fork context. Requires plan-mode approval before generating code.
context: fork
allowed-tools:
  - Read
  - Grep
  - Edit
  - Write
  - Bash
---

# Skill: Audit Event Framework Architect

You are an expert in audit logging and compliance engineering. Your task is to
design and implement an audit event framework that is observable, tamper-evident,
structured, and easy for other developers to extend.

**This skill always operates in two phases:**
1. **Design Phase** — propose the architecture. Wait for approval.
2. **Implementation Phase** — generate code after approval.

---

## Phase 1 — Domain Analysis

1. Use `Grep` to identify domain models, service classes, and repository methods.
2. Use `Read` to understand the existing domain events or signals (if any).
3. Identify auditable actions:
   - Resource creation / modification / deletion
   - Auth events (login, logout, token refresh, failed auth)
   - Permission changes
   - Financial or sensitive data access
   - Configuration changes
4. Produce an **Audit Surface Report**:

```
AUDIT SURFACE REPORT
====================
Domain:  <service name>

High-priority audit targets:
  - OrderService.create_order() — creates financial record
  - UserService.update_permissions() — access control change
  - AuthService.login() — authentication event
  - ...

Medium-priority:
  - OrderService.update_status() — state machine transition
  - ...

Low-priority / informational:
  - CatalogService.search_products() — read access
  - ...
```

---

## Phase 2 — Framework Design

Propose an audit event schema and framework design:

### Event Schema

```python
@dataclass(frozen=True)
class AuditEvent:
    event_id: UUID                  # Unique per event
    event_type: str                 # e.g., "order.created"
    actor_id: str                   # Who performed the action
    actor_type: ActorType           # USER | SERVICE | SYSTEM
    resource_type: str              # e.g., "Order"
    resource_id: str                # The entity affected
    action: AuditAction             # CREATE | READ | UPDATE | DELETE
    outcome: AuditOutcome           # SUCCESS | FAILURE | PARTIAL
    timestamp: datetime             # UTC, immutable
    metadata: dict[str, Any]        # Action-specific payload (sanitized)
    trace_id: str                   # Correlates to distributed trace
    ip_address: str | None          # Source IP for user-initiated actions
    session_id: str | None          # Session correlation
```

### Storage Strategy Options (present all three, recommend one):

| Option | Description | Tradeoffs |
|--------|-------------|-----------|
| Append-only DB table | Postgres table with no UPDATE/DELETE grants | Simple, queryable, not tamper-proof at DB level |
| Event stream | Kafka / SQS topic, consumers write to cold storage | Durable, async, requires extra infra |
| Dedicated audit service | Separate microservice with its own store | Best isolation, most overhead |

Recommend based on the team's existing infrastructure.

### Integration Pattern

Propose either:
- **Decorator/middleware approach**: audit is automatic based on annotations.
- **Explicit emit approach**: service code calls `audit.emit(event)` explicitly.

Present tradeoffs. Wait for approval before implementing.

---

## Phase 3 — Implementation

After design approval, generate:

1. `src/audit/models.py` — event dataclasses and enums.
2. `src/audit/emitter.py` — async-safe event emitter with batching.
3. `src/audit/middleware.py` — request-level context injection (actor, trace_id).
4. `src/audit/decorators.py` — `@auditable` decorator for service methods.
5. `tests/test_audit_emitter.py` — unit tests for emitter.
6. `docs/audit-integration-guide.md` — how to add audit events to new services.

---

## Behavioral Guardrails

- Audit events must never contain raw PII (passwords, tokens, card numbers).
- Metadata fields must be sanitized before logging — use an allowlist, not a denylist.
- Audit emit failures must not cause the primary business operation to fail (fire-and-forget with dead letter queue).
- Do not implement the storage backend — propose the interface and let the team wire the adapter.
- This skill runs in **forked context**. Do not reference parent conversation state.
