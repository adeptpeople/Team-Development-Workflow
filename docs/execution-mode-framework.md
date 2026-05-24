# Execution Mode Decision Framework

This document defines when to use **Direct Execution** versus **Plan Mode** for
AI-assisted development tasks. Following this framework reduces rework, improves
architectural quality, and ensures the right level of human oversight for each class of work.

---

## The Two Modes

### Direct Execution
Claude acts immediately without presenting a plan first.

**Characteristics:**
- Fastest time-to-change
- Suitable for well-understood, low-risk, localized work
- Changes are typically reversible in one step
- Human review happens post-facto in the PR

### Plan Mode (`/plan` or `Shift+Tab` in Claude Code)
Claude presents a structured proposal before touching any file. The developer
reviews and approves (or redirects) before execution begins.

**Characteristics:**
- Adds a review gate before execution
- Exposes the agent's reasoning for human evaluation
- Enables course-correction before cost is incurred
- Essential when the solution space has multiple valid paths

---

## Decision Matrix

| Task Type              | Complexity | Ambiguity | Files Affected | Preferred Mode   | Rationale                                           |
|------------------------|-----------|-----------|----------------|------------------|-----------------------------------------------------|
| Single-file bug fix    | Low       | Low       | 1              | Direct           | Well-scoped, fast feedback loop                     |
| Rename/refactor        | Low       | Low       | 1–3            | Direct           | Mechanical, grep-verifiable, easily reversible      |
| Add test for known bug | Low       | Low       | 1–2            | Direct           | Requirement is clear; test captures the spec        |
| Localized type fix     | Low       | Low       | 1              | Direct           | Deterministic change, zero architectural impact     |
| Add field to DTO       | Low       | Low       | 2–5            | Direct           | Pattern is established; ripple is predictable       |
| Multi-file refactor    | Medium    | Low       | 5–20           | Plan             | Ripple analysis needed before touching files        |
| Library migration      | Medium    | Medium    | 5–50           | Plan             | Dependency graph + API mapping needed first         |
| New API endpoint       | Medium    | Medium    | 3–8            | Plan             | Auth, schema, validation, tests all need alignment  |
| New background job     | Medium    | Medium    | 3–6            | Plan             | Retry, failure, idempotency tradeoffs need review   |
| Feature with UI+API    | High      | Medium    | 10–30          | Plan (required)  | Cross-layer coordination; stale frontend risk       |
| New microservice       | High      | High      | New repo       | Plan (required)  | Architecture decision; team alignment needed        |
| Audit/compliance feat. | High      | High      | 5–20           | Plan (required)  | Legal/compliance requirements need explicit sign-off|
| Auth system change     | High      | Low       | 5–15           | Plan (required)  | Security-critical; requires explicit approval chain |
| Database migration     | Medium    | Low       | 1–3            | Plan             | Irreversibility risk; production data at stake      |
| Performance tuning     | Medium    | High      | 2–10           | Plan             | Multiple valid approaches; profiling guides choice  |
| Dependency upgrade     | Low–High  | Low–Med   | 2–50           | Plan             | Breakage surface unknown until mapped               |
| Incident hotfix        | High      | Low       | 1–3            | Direct + review  | Speed prioritized; expedited review process         |

---

## Scenario Deep Dives

### Scenario 1 — Single-file Bug Fix
**Example:** `NullPointerError in src/auth/token.py line 47 when refresh_token is None`

**Analysis:**
- Location: known, single file
- Fix: guard clause or early return
- Tests: one regression test required
- Risk: low, reversible

**Recommendation: Direct Execution**

Expected behavior:
1. Claude reads the file, identifies the null path.
2. Applies the guard clause directly.
3. Generates a regression test.
4. Reports: file changed, test added, coverage delta.

**When to override to Plan Mode:**
- If the null pointer symptom points to a design flaw (token should never be None here — why is it?)
- If fixing the symptom requires changing the token contract across multiple callers

**Benchmark metrics:**
| Metric                | Direct | Plan |
|-----------------------|--------|------|
| Time to PR            | ~3 min | ~8 min |
| Rework rate           | 5%     | 2%   |
| Defect escape rate    | Same   | Same |
| Overhead              | Low    | Medium |

**Verdict:** Direct wins on latency. Plan adds overhead without benefit for this class.

---

### Scenario 2 — Multi-file Library Migration
**Example:** `Migrate all usage of requests to httpx across the service`

**Analysis:**
- Scope: unknown until inventoried (could be 3 files or 30)
- API surface: some mappings are direct, some require semantic changes
- Test mocks: likely need updating too (responses → respx)
- Risk: medium — if exception hierarchy differs, silent behavioral changes possible

**Recommendation: Plan Mode**

Expected plan output:
```
Plan: requests → httpx migration

Inventory: 7 files, 18 usages

Proposed order:
  Step 1: Core HTTP clients (payment_gateway.py, shipping_provider.py)
  Step 2: Utility clients (email_client.py, health_check.py)
  Step 3: Test mock updates (conftest.py, test_*.py)

Breaking API changes requiring manual review:
  - Timeout signature changed: tuple → httpx.Timeout object
  - Session → Client lifecycle (context manager preferred)
  - Exception hierarchy: RequestException → HTTPError (different subclasses)

Test strategy: run pytest after each step

Rollback trigger: if >3 tests fail after Step 1, abort and revert
```

**Benchmark metrics:**
| Metric                | Direct | Plan |
|-----------------------|--------|------|
| Time to PR            | ~15 min | ~25 min |
| Rework rate           | 30%    | 5%   |
| Missed usages         | High   | Low  |
| Silent behavior change| Possible| Unlikely |

**Verdict:** Plan mode pays for itself by eliminating the rework cycle.

---

### Scenario 3 — New Feature: Audit Event Framework
**Example:** `Implement an audit event framework for the Orders service`

**Analysis:**
- Multiple valid architectures (decorator vs. explicit emit, sync vs. async, storage options)
- Cross-cutting concern — affects all domain services
- Compliance implications — design choice has legal/operational consequences
- Stakeholder clarity needed before code is written

**Recommendation: Plan Mode (strongly required)**

Expected plan output:
```
Plan: Audit Event Framework — Orders Service

Architecture options:

Option A: Decorator-based (automatic)
  Pros: Zero boilerplate for service authors; consistent coverage
  Cons: Magic; harder to test; metadata collection is limited
  
Option B: Explicit emit (manual)
  Pros: Full control over metadata; testable; observable
  Cons: Requires discipline; easy to forget new methods
  
Option C: Middleware + domain events
  Pros: Clean separation; event-sourcing compatible
  Cons: Requires domain event infrastructure first

Recommendation: Option B (explicit emit) for the Orders service given:
  - No existing event infrastructure
  - Need for field-level metadata (changed values)
  - Compliance team requires explicit opt-in verification

Proposed components:
  1. AuditEvent dataclass + enums
  2. AuditEmitter (async, fire-and-forget with dead letter)
  3. @auditable decorator (convenience wrapper for Option B)
  4. Request middleware for actor/trace injection
  5. 12 unit tests + integration test with test double

Files affected: 8 new files, 6 existing service files

Estimated effort: 4–6 hours human-equivalent
```

**Benchmark metrics:**
| Metric                | Direct | Plan |
|-----------------------|--------|------|
| Architectural quality | Variable | Consistently high |
| Stakeholder alignment | After rework | Before code |
| Rework rate           | 60%    | 10%  |
| Developer satisfaction| Low    | High |

**Verdict:** Direct execution for architectural features produces low-quality first drafts
and high rework cost. Plan mode is not optional here.

---

## Quick Decision Heuristics

Use this flowchart when uncertain:

```
Is the fix location known exactly?
  NO → Plan Mode

Is the solution approach unambiguous?
  NO → Plan Mode

Does the change touch more than 5 files?
  YES → Plan Mode

Does the change affect auth, security, or compliance?
  YES → Plan Mode (required)

Does the change require an irreversible operation (DB migration, data delete)?
  YES → Plan Mode (required)

Could a wrong first implementation mislead the reviewer?
  YES → Plan Mode

Otherwise → Direct Execution
```

---

## Governance Rules

1. **Auth and security changes always use Plan Mode.** No exceptions.
2. **Database migrations always use Plan Mode.** Irreversibility risk.
3. **Single-file bug fixes always use Direct.** Plan mode is wasted overhead.
4. **Developer may always request Plan Mode** regardless of task classification.
5. **CI failures in a Direct Execution PR trigger mandatory Plan Mode** for the next attempt.
6. **Measure rework rate per contributor per quarter.** High rework rate → review mode defaults.

---

## Metrics Collection

Track these per-PR metrics to calibrate mode selection:

| Metric                      | Target              | Alarm Threshold     |
|-----------------------------|---------------------|---------------------|
| Rework rate (mode: direct)  | < 10%               | > 25%               |
| Rework rate (mode: plan)    | < 5%                | > 15%               |
| Latency: bug fix (direct)   | < 5 min to PR       | > 15 min            |
| Latency: migration (plan)   | < 30 min to PR      | > 90 min            |
| Human correction count      | < 2 per PR          | > 5 per PR          |
| Test pass rate on first run | > 95%               | < 80%               |

Report generated weekly in `docs/benchmarks/execution-mode-weekly.md`.
