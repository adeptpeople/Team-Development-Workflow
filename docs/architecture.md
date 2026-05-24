# Team AI Development Workflow — Architecture

## System Architecture Diagram

```
╔══════════════════════════════════════════════════════════════════════════════════╗
║                        DEVELOPER WORKSTATION                                     ║
║                                                                                  ║
║  ┌────────────────────────────────────────────────────────────────────────────┐  ║
║  │                        Claude Code Runtime                                  │  ║
║  │                                                                              │  ║
║  │  ┌─────────────────────┐     ┌──────────────────────────────────────────┐   │  ║
║  │  │  Governance Layer    │     │           Execution Controller            │   │  ║
║  │  │                     │     │                                            │   │  ║
║  │  │  ┌───────────────┐  │     │  ┌─────────────┐    ┌─────────────────┐  │   │  ║
║  │  │  │  CLAUDE.md    │  │     │  │ Direct Mode │    │   Plan Mode     │  │   │  ║
║  │  │  │ (always loaded│  │     │  │             │    │                 │  │   │  ║
║  │  │  │  at session   │  │     │  │ • Bug fixes │    │ • Architecture  │  │   │  ║
║  │  │  │  start)       │  │     │  │ • Renames   │    │ • Migrations    │  │   │  ║
║  │  │  └───────────────┘  │     │  │ • Type fixes│    │ • New features  │  │   │  ║
║  │  │                     │     │  └──────┬──────┘    └────────┬────────┘  │   │  ║
║  │  │  ┌───────────────┐  │     │         └──────────┬─────────┘           │   │  ║
║  │  │  │ Scoped Rule   │  │     │                    │                      │   │  ║
║  │  │  │    Loader     │  │     │              Task Executor                │   │  ║
║  │  │  │               │  │     └──────────────────────────────────────────┘   │  ║
║  │  │  │ .claude/rules/│  │                                                     │  ║
║  │  │  │  api-*.md     │──┼──► Loaded when editing src/api/**                  │  ║
║  │  │  │  testing.md   │──┼──► Loaded when editing *.test.*                    │  ║
║  │  │  │  frontend.md  │──┼──► Loaded when editing src/ui/**                   │  ║
║  │  │  │  database.md  │──┼──► Loaded when editing migrations/**               │  ║
║  │  │  └───────────────┘  │                                                     │  ║
║  │  └─────────────────────┘                                                     │  ║
║  │                                                                              │  ║
║  │  ┌──────────────────────────────────────────────────────────────────────┐   │  ║
║  │  │                     Skill Isolation Runtime                           │   │  ║
║  │  │                                                                        │   │  ║
║  │  │   ┌─────────────────────────┐    ┌──────────────────────────────┐     │   │  ║
║  │  │   │  library-migration      │    │  audit-event-framework        │     │   │  ║
║  │  │   │  context: fork          │    │  context: fork                │     │   │  ║
║  │  │   │  allowed: Read,Grep,    │    │  allowed: Read,Grep,Edit,     │     │   │  ║
║  │  │   │          Edit,Bash      │    │          Write,Bash           │     │   │  ║
║  │  │   │                         │    │                               │     │   │  ║
║  │  │   │  ┌────────────────────┐ │    │  ┌──────────────────────┐    │     │   │  ║
║  │  │   │  │ Isolated Context   │ │    │  │ Isolated Context     │    │     │   │  ║
║  │  │   │  │ (no parent bleed)  │ │    │  │ (no parent bleed)    │    │     │   │  ║
║  │  │   │  └────────────────────┘ │    │  └──────────────────────┘    │     │   │  ║
║  │  │   └─────────────────────────┘    └──────────────────────────────┘     │   │  ║
║  │  └──────────────────────────────────────────────────────────────────────┘   │  ║
║  │                                                                              │  ║
║  │  ┌──────────────────────────────────────────────────────────────────────┐   │  ║
║  │  │                         MCP Broker                                    │   │  ║
║  │  │                                                                        │   │  ║
║  │  │   Project MCPs (.mcp.json)          Personal MCPs (~/.claude.json)   │   │  ║
║  │  │   ┌──────────┐ ┌──────────┐         ┌──────────────┐ ┌───────────┐  │   │  ║
║  │  │   │  jira    │ │  github  │         │experimental- │ │  local-db │  │   │  ║
║  │  │   │ MCP ─────┼─┤  MCP ───┼──┐  ┌──┤    search    │ │ inspector │  │   │  ║
║  │  │   └──────────┘ └──────────┘  │  │  └──────────────┘ └───────────┘  │   │  ║
║  │  │   ┌──────────┐ ┌──────────┐  │  │                                   │   │  ║
║  │  │   │  slack   │ │datadog   │  │  │  Credential Expansion:            │   │  ║
║  │  │   │  MCP ────┤ │  MCP ───┼──┤  │  ${JIRA_TOKEN} → env var          │   │  ║
║  │  │   └──────────┘ └──────────┘  │  │  ${GITHUB_TOKEN} → env var       │   │  ║
║  │  │   ┌────────────────────────┐ │  │  Never hardcoded                  │   │  ║
║  │  │   │  postgres-readonly MCP │ │  │                                   │   │  ║
║  │  │   └────────────────────────┘ │  │                                   │   │  ║
║  │  │                              ▼  ▼                                   │   │  ║
║  │  │                    ┌──────────────────┐                             │   │  ║
║  │  │                    │  Tool Invocation  │                             │   │  ║
║  │  │                    │  Audit Log        │                             │   │  ║
║  │  │                    │ .claude/audit/    │                             │   │  ║
║  │  │                    └──────────────────┘                             │   │  ║
║  │  └──────────────────────────────────────────────────────────────────────┘   │  ║
║  └────────────────────────────────────────────────────────────────────────────┘  ║
║                                                                                  ║
╚══════════════════════════════════════════════════════════════════════════════════╝
           │              │                    │                │
           ▼              ▼                    ▼                ▼
    ┌─────────────┐ ┌───────────┐    ┌──────────────┐  ┌────────────────┐
    │    Jira     │ │  GitHub   │    │    Slack     │  │   Datadog      │
    │   (write)   │ │  (write)  │    │   (write)    │  │   (read)       │
    └─────────────┘ └───────────┘    └──────────────┘  └────────────────┘
```

---

## Component Descriptions

### Governance Layer

```
CLAUDE.md (always active)
└── Universal rules applied to every task
    ├── Coding standards (Python, TypeScript)
    ├── Naming conventions
    ├── Testing requirements (85% coverage)
    ├── Error handling (typed exceptions)
    ├── Security (no hardcoded secrets)
    ├── Logging (structured, no PII)
    └── PR quality gates
```

### Scoped Rule Loader

```
.claude/rules/ (path-matched, loaded on demand)
├── api-conventions.md    → activated for src/api/**
├── testing.md            → activated for **/*.test.*, tests/**
├── frontend.md           → activated for src/ui/**, src/components/**
└── database.md           → activated for migrations/**, **/repository.py

Rule isolation guarantee:
  Editing src/api/orders.py    → loads api-conventions.md only
  Editing tests/test_orders.py → loads testing.md only
  Editing README.md            → loads nothing (no rule match)
```

### Skill Isolation Runtime

```
context: fork
└── Each skill spawns a new, isolated reasoning context
    ├── No parent conversation state inherited
    ├── No cross-skill context bleed
    ├── Tool permissions strictly scoped by allowed-tools list
    └── Forked context is destroyed after skill completes
```

### MCP Broker Trust Boundaries

```
Trust boundary: project vs. personal

Project (.mcp.json)
├── Available to ALL contributors
├── Credentials from team secret store
├── Subject to project governance rules
└── Mutations require user confirmation

Personal (~/.claude.json)
├── Available to ONE developer only
├── Credentials from developer's local env
├── Not subject to project audit requirements
└── May NOT proxy project secrets
```

---

## Data Flow: Scoped Rule Loading

```
Developer edits: src/api/orders/create.py
        │
        ▼
Claude Code checks .claude/rules/ for glob matches
        │
        ├── api-conventions.md (paths: src/api/**/*) ✓ MATCH → LOADED
        ├── testing.md (paths: **/*.test.*) ✗ no match
        ├── frontend.md (paths: src/ui/**/*) ✗ no match
        └── database.md (paths: migrations/**) ✗ no match
        │
        ▼
Active rule context = CLAUDE.md + api-conventions.md
        │
        ▼
AI generates/edits code conforming to both rule sets
```

---

## Data Flow: Skill Execution

```
Developer invokes: /skill library-migration

        ▼
Claude Code reads .claude/skills/library-migration/skill.md
        │
        ├── context: fork → new isolated context spawned
        ├── allowed-tools: [Read, Grep, Edit, Bash] → enforced
        └── skill instructions loaded as system context

        ▼
Forked skill context executes:
  Phase 1: Inventory (Grep + Read)
  Phase 2: Plan proposal → await developer approval
  Phase 3: Apply edits (Edit)
  Phase 4: Validate (Bash → make test)
  Phase 5: Checklist generation

        ▼
Skill context destroyed → result returned to parent session
No state leaks back to parent conversation
```

---

## Security Architecture

```
Credential Isolation:
  .env (local, gitignored)
      └── JIRA_TOKEN=secret123
  .mcp.json (committed)
      └── "JIRA_TOKEN": "${JIRA_TOKEN}"   ← reference, not value
  Runtime expansion
      └── MCP process receives: JIRA_TOKEN=secret123

Least Privilege:
  Skills         → only tools in allowed-tools list
  Postgres MCP   → read-only connection string
  Jira MCP       → scoped to project, not org-admin
  GitHub MCP     → repo-scoped token, no org write

Audit Trail:
  .claude/audit/mcp-calls.jsonl
      └── { timestamp, server, tool, args_hash, outcome }
  Note: args are hashed (not stored) to prevent credential capture
```
