# Personal MCP Configuration Template

Copy this template to `~/.claude.json` and customize for your local developer setup.
This file is **never committed** — it is developer-local only.

Personal MCP servers are available in all your Claude Code sessions but are not
shared with the team. Use this for experimental tooling, personal productivity
integrations, and local development utilities.

---

## Template: `~/.claude.json`

```json
{
  "mcpServers": {
    "experimental-search": {
      "command": "python",
      "args": ["~/tools/search_server.py"],
      "env": {
        "SEARCH_API_KEY": "${PERSONAL_SEARCH_API_KEY}"
      },
      "description": "Local semantic code search — experimental, developer-personal only"
    },
    "local-db-inspector": {
      "command": "node",
      "args": ["~/tools/db-inspector/index.js"],
      "env": {
        "LOCAL_DB_URL": "${LOCAL_DATABASE_URL}"
      },
      "description": "Inspect local dev database schema and run ad-hoc read queries"
    },
    "linear-personal": {
      "command": "node",
      "args": ["~/tools/linear-mcp/index.js"],
      "env": {
        "LINEAR_API_KEY": "${LINEAR_PERSONAL_API_KEY}"
      },
      "description": "Personal Linear integration — view assigned issues, update status"
    },
    "browser-tools": {
      "command": "npx",
      "args": ["-y", "@agentdeskai/browser-tools-mcp@latest"],
      "description": "Browser automation for local testing and UI verification"
    }
  },
  "_governance": {
    "scope": "personal — never commit this file",
    "note": "These servers supplement project MCP servers defined in .mcp.json. Both are available simultaneously in Claude Code sessions.",
    "isolation": "Personal servers must not have access to production systems. Use read-only credentials scoped to development environments."
  }
}
```

---

## How Personal and Project MCPs Coexist

```
Claude Code Session
├── Project MCP servers  (loaded from .mcp.json)
│   ├── jira             ← team-shared, project-scoped
│   ├── github           ← team-shared, project-scoped
│   └── datadog          ← team-shared, project-scoped
│
└── Personal MCP servers (loaded from ~/.claude.json)
    ├── experimental-search  ← developer-local, not shared
    └── local-db-inspector   ← developer-local, not shared
```

Both sets of tools are available simultaneously. Project tools take precedence
if a name conflict exists.

---

## Security Rules for Personal MCPs

1. Never wire personal servers to production credentials.
2. Development-scoped credentials only: read-only, your org, your tenant.
3. Experimental servers should be clearly labeled as such in their `description`.
4. Do not proxy project secrets through personal MCP servers.
5. Personal servers do not appear in team audit logs — use project servers for auditable actions.
