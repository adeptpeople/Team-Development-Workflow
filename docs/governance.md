# AI Development Workflow Governance

## Purpose

This document defines the governance model for AI-assisted engineering in this repository.
It covers how rules are enforced, how tools are controlled, how credentials are protected,
and how teams onboard to this workflow.

---

## Governance Layers

```
Layer 1: Project Governance (CLAUDE.md)
  ↓ Always active — applies to every file, every task, every contributor
  ↓ Defines: coding standards, testing, security, PR quality

Layer 2: Scoped Rules (.claude/rules/)
  ↓ Activated only when editing matching file paths
  ↓ Specializes Layer 1 for specific domains (API, tests, UI, database)

Layer 3: Skill Isolation (.claude/skills/)
  ↓ Forked context — isolated from parent conversation
  ↓ Restricted tool surface — only declared allowed-tools work
  ↓ Reusable — multiple invocations, no cross-invocation state

Layer 4: MCP Integration (.mcp.json + ~/.claude.json)
  ↓ Project tools: shared, team-audited, env-var credential expansion
  ↓ Personal tools: developer-local only, never in shared config
```

---

## Rule Precedence

When multiple rules apply to the same file path:

1. `CLAUDE.md` is always the baseline — never overridden, only extended.
2. Scoped rules in `.claude/rules/` add specificity for their path domain.
3. When two scoped rules both match, both are applied — no conflict resolution needed (they cover different concerns).
4. Skill instructions are fully isolated — they do not see or apply project rules.

---

## Security Governance

### Credential Policy

| Location                | Allowed Content           | Access Scope        |
|-------------------------|---------------------------|---------------------|
| `.mcp.json`             | `${ENV_VAR}` references   | Team (committed)    |
| `~/.claude.json`        | `${ENV_VAR}` references   | Developer-local     |
| `.env`                  | Actual values             | Local only (gitignored) |
| CI secrets manager      | Actual values             | CI pipeline only    |
| Source code             | NOTHING                   | Forbidden           |

### Least Privilege Matrix

| Component            | Read | Write | Network | Execute | Admin |
|----------------------|------|-------|---------|---------|-------|
| library-migration skill | ✓ | ✓ (Edit) | ✗ | ✓ (Bash: test/lint only) | ✗ |
| audit-event-framework skill | ✓ | ✓ | ✗ | ✓ (Bash: test only) | ✗ |
| Jira MCP             | ✓ | ✓ (issues) | ✓ | ✗ | ✗ |
| GitHub MCP           | ✓ | ✓ (PRs, comments) | ✓ | ✗ | ✗ |
| Postgres MCP         | ✓ (read-only) | ✗ | ✓ (internal) | ✗ | ✗ |
| Slack MCP            | ✗ | ✓ (messages) | ✓ | ✗ | ✗ |

### MCP Trust Boundaries

```
TRUST LEVEL: project
  ├── Credentials sourced from team secret store or CI secrets
  ├── Used for auditable operations
  ├── Available to ALL developers
  └── Mutations require explicit user confirmation from Claude

TRUST LEVEL: personal  
  ├── Credentials sourced from developer's own environment
  ├── NOT audited at project level
  ├── Available to ONE developer only
  └── Cannot proxy project-scoped credentials
```

---

## Team Onboarding Checklist

For each new team member:

```
Setup:
  [ ] Install Claude Code CLI (npm install -g @anthropic-ai/claude-code)
  [ ] Clone this repository
  [ ] Read CLAUDE.md — this is non-negotiable before first session
  [ ] Read docs/execution-mode-framework.md — understand when to use /plan
  [ ] Copy docs/personal-mcp-template.md to ~/.claude.json and customize
  [ ] Set environment variables in .env (copy from .env.example)
  [ ] Verify .env is gitignored: git check-ignore .env

First session validation:
  [ ] Run: ./scripts/run-all-tests.sh
        Expected: All tests pass
  [ ] Open a test file, verify testing.md scoped rule is mentioned
  [ ] Open src/api/*, verify api-conventions.md scoped rule is mentioned
  [ ] Invoke: /skill library-migration on a practice branch
        Expected: Skill runs in fork context, does not affect main conversation

Review and acknowledge:
  [ ] I understand that CLAUDE.md rules are enforced, not optional
  [ ] I understand that plan mode is required for architectural changes
  [ ] I understand that credentials must never appear in source code or .mcp.json values
  [ ] I understand that personal MCP servers must not be committed to the project
```

---

## Change Governance

### Adding or Modifying CLAUDE.md

- Requires PR review from a minimum of two senior engineers.
- Changes must not reduce existing standards (only raise them or add specificity).
- Effective date must be stated in the PR description — teams need time to adopt.
- Test the change with `./scripts/validate-claude-md.sh` before merging.

### Adding a Scoped Rule

- Requires PR review from the domain owner (API team lead for api-conventions.md, etc.).
- The new rule file must have valid YAML frontmatter with `paths:`.
- Test glob matching with `./scripts/validate-scoped-rules.sh`.
- Document the rule in `docs/governance.md` (this file) under the rule inventory.

### Adding a Project MCP Server

- Requires team review (the server will be available to all contributors).
- Must use `${ENV_VAR}` expansion for all credentials — no hardcoded values.
- Write-capable servers require documentation of what write operations are expected.
- Add the server to `.mcp.json` and update `docs/mcp-servers.md`.
- Run `./scripts/validate-mcp.sh` to verify compliance.

### Adding a Skill

- Requires PR review. New skills must declare `context: fork` and `allowed-tools:`.
- Include at least one worked example in `examples/`.
- Skill must have explicit isolation guardrails in the skill body.
- Run `./scripts/validate-skills.sh` to verify compliance.

---

## Audit and Observability

### AI Session Audit (development mode)

Enable MCP call auditing:
```bash
export CLAUDE_AUDIT_MCP=true
```

Audit log location: `.claude/audit/mcp-calls.jsonl`

Log entry format:
```json
{
  "timestamp": "2026-05-24T14:23:01Z",
  "session_id": "sess_abc123",
  "mcp_server": "jira",
  "tool": "create_issue",
  "args_hash": "sha256:abc...",
  "outcome": "success",
  "duration_ms": 234,
  "triggered_by": "developer_confirmation"
}
```

Note: `args` are hashed, not stored, to prevent credential or sensitive data capture in logs.

### Metrics Dashboard

Track these indicators weekly:
- Mode misclassification rate (from PR descriptions).
- Rework cycle count per contributor.
- Test coverage trajectory.
- Lint error rate at PR open.
- MCP tool invocation volume by server.

Escalation thresholds:
- Rework rate > 20% for a contributor → schedule workflow review.
- Coverage drops below 85% for two consecutive sprints → freeze feature work.
- Hardcoded secret detected → immediate remediation, rotate secret within 24h.

---

## Rule Inventory

| Rule File                       | Scope (glob)                    | Domain Owner         |
|---------------------------------|---------------------------------|----------------------|
| `CLAUDE.md`                     | `**/*` (universal)              | Engineering Lead     |
| `.claude/rules/api-conventions.md` | `src/api/**/*`               | API Team Lead        |
| `.claude/rules/testing.md`      | `**/*.test.*`, `tests/**`       | QA / Test Eng Lead   |
| `.claude/rules/frontend.md`     | `src/ui/**`, `src/components/**`| Frontend Lead        |
| `.claude/rules/database.md`     | `migrations/**`, `**/repository.py` | Data Eng Lead   |

| Skill                               | Context | Tool Grant                    | Owner             |
|-------------------------------------|---------|-------------------------------|-------------------|
| `.claude/skills/library-migration`  | fork    | Read, Grep, Edit, Bash        | Platform Eng      |
| `.claude/skills/audit-event-framework` | fork | Read, Grep, Edit, Write, Bash | Security/Compliance |
