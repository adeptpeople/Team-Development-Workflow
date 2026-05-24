# Team AI Development Workflow

Production-ready governance system for AI-assisted software engineering with Claude Code.
Covers project-wide coding standards, scoped file rules, isolated skills, MCP integration,
credential security, and execution mode decision-making.

## Quick Start

```bash
# Verify the full governance system
./scripts/run-all-tests.sh

# Copy personal MCP template and customize
cp docs/personal-mcp-template.md ~/personal-mcp-reference.md
# Then edit ~/.claude.json with your local servers

# Set up local credentials (never commit .env)
cp .env.example .env   # if this repo has one
```

## What's in This Repo

```
├── CLAUDE.md                              # Universal coding governance (always active)
├── .mcp.json                              # Project MCP servers (committed, env-var creds)
│
├── .claude/
│   ├── rules/
│   │   ├── api-conventions.md             # REST API rules → src/api/**
│   │   ├── testing.md                     # Test authoring rules → *.test.*, tests/**
│   │   ├── frontend.md                    # UI component rules → src/ui/**, src/components/**
│   │   └── database.md                    # Migration/query rules → migrations/**, repositories
│   │
│   └── skills/
│       ├── library-migration/             # Migrate libraries safely (forked, scoped tools)
│       │   ├── skill.md
│       │   └── examples/requests-to-httpx.md
│       └── audit-event-framework/         # Design+implement audit logging (forked)
│           └── skill.md
│
├── docs/
│   ├── architecture.md                    # Full system architecture diagram
│   ├── execution-mode-framework.md        # When to use Direct vs Plan mode
│   ├── benchmark-report.md                # Quantified impact data
│   ├── governance.md                      # Team onboarding + change governance
│   └── personal-mcp-template.md          # Template for ~/.claude.json
│
└── scripts/
    ├── run-all-tests.sh                   # Full validation suite (95 checks)
    ├── validate-claude-md.sh              # Test 1: CLAUDE.md enforcement
    ├── validate-scoped-rules.sh           # Tests 2+3: Rule loading + isolation
    ├── validate-skills.sh                 # Tests 4+5: Skill isolation + tool restrictions
    ├── validate-mcp.sh                    # Tests 6+7+8: MCP config + credential safety
    └── validate-execution-mode.sh         # Test 9: Mode decision framework
```

## Governance Layers

| Layer | What | When Active |
|-------|------|-------------|
| `CLAUDE.md` | Universal coding standards | Always — every file, every session |
| `.claude/rules/*.md` | Domain-specific rules | Only when editing matching file paths |
| `.claude/skills/` | Isolated reusable agents | Only when explicitly invoked |
| `.mcp.json` | Team integration servers | Every session, all contributors |
| `~/.claude.json` | Personal local servers | Your sessions only |

## Scoped Rule Matching

| File You Edit | Rules Loaded |
|---------------|-------------|
| `src/api/orders/create.py` | CLAUDE.md + api-conventions.md |
| `tests/order.test.ts` | CLAUDE.md + testing.md |
| `src/ui/components/OrderCard.tsx` | CLAUDE.md + frontend.md |
| `migrations/20240315_add_audit.sql` | CLAUDE.md + database.md |
| `README.md` | CLAUDE.md only |

## Execution Mode Decision

```
Single-file bug fix, rename, type fix  →  Direct Execution
Multi-file refactor, library migration  →  Plan Mode
New feature, auth change, DB migration  →  Plan Mode (required)
```

See `docs/execution-mode-framework.md` for the full decision matrix, three worked
scenarios, benchmark data, and quick-decision flowchart.

## Validation Results

```
Test 1: CLAUDE.md Enforcement        18/18 ✓
Test 2: Scoped Rule Structure        12/12 ✓
Test 3: Rule Isolation Matching      10/10 ✓
Test 4: Skill Context Isolation       7/7  ✓
Test 5: Tool Restriction Enforcement 12/12 ✓
Test 6: Project MCP Config            8/8  ✓
Test 7: Personal MCP Template         4/4  ✓
Test 8: Credential Expansion Safety   4/4  ✓ (13 env values, 0 hardcoded)
Test 9: Execution Mode Framework     23/23 ✓

Total: 95/95 checks passed
```

## MCP Servers (Project-Shared)

| Server | Purpose | Write? |
|--------|---------|--------|
| `jira` | Issue tracking, link PRs to tickets | Yes (issues) |
| `github` | PRs, review comments, CI status | Yes (PRs, comments) |
| `slack` | Deployment notifications, PR pings | Yes (messages) |
| `datadog` | Query metrics, logs, monitors | No (read-only) |
| `postgres-readonly` | Schema inspection, query analysis | No (read-only) |

All credentials use `${ENV_VAR}` expansion — no values committed to source control.

## Team Onboarding

See `docs/governance.md` for the complete onboarding checklist, change governance
process, security policy, and audit log configuration.
# Team-Development-Workflow
# Team-Development-Workflow
