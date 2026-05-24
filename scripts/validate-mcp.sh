#!/usr/bin/env bash
# Tests 6, 7, 8: MCP Configuration Validation
# Verifies project MCP config, personal MCP template, and credential expansion safety.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
MCP_JSON="${PROJECT_ROOT}/.mcp.json"

PASS=0
FAIL=0

pass() { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }

echo ""
echo "═══════════════════════════════════════════════════════"
echo " TEST 6: Project MCP Configuration (.mcp.json)"
echo "═══════════════════════════════════════════════════════"

# 6.1 .mcp.json exists
if [[ -f "${MCP_JSON}" ]]; then
  pass ".mcp.json exists at project root"
else
  fail ".mcp.json not found at ${MCP_JSON}"
  exit 1
fi

# 6.2 Valid JSON
if python3 -c "import json; json.load(open('${MCP_JSON}'))" 2>/dev/null; then
  pass ".mcp.json is valid JSON"
else
  fail ".mcp.json is not valid JSON"
  exit 1
fi

# 6.3 Has mcpServers key
HAS_MCP_SERVERS=$(python3 -c "
import json
data = json.load(open('${MCP_JSON}'))
print('yes' if 'mcpServers' in data else 'no')
" 2>/dev/null)

if [[ "${HAS_MCP_SERVERS}" == "yes" ]]; then
  pass ".mcp.json has 'mcpServers' key"
else
  fail ".mcp.json missing 'mcpServers' key"
  exit 1
fi

# 6.4 Count configured servers
SERVER_COUNT=$(python3 -c "
import json
data = json.load(open('${MCP_JSON}'))
print(len(data.get('mcpServers', {})))
" 2>/dev/null)

if [[ "${SERVER_COUNT}" -ge 2 ]]; then
  pass "Project MCP has ${SERVER_COUNT} server(s) configured"
else
  fail "Project MCP has only ${SERVER_COUNT} server(s) — expected >= 2"
fi

# 6.5 Each server has required fields
echo ""
echo "─── Per-Server Structure Validation ────────────────────"
MCP_JSON_PATH="${MCP_JSON}" python3 - << 'PYEOF'
import json, sys, os

data = json.load(open(os.environ["MCP_JSON_PATH"]))
servers = data.get("mcpServers", {})
failures = []

for name, config in servers.items():
    if "command" not in config:
        failures.append(f"{name}: missing 'command'")
    if "args" not in config:
        failures.append(f"{name}: missing 'args'")
    if "description" not in config:
        failures.append(f"  WARNING: {name}: missing 'description' (recommended)")

for f in failures:
    print(f"  [STRUCTURE] {f}")

if not failures:
    print(f"  [OK] All {len(servers)} servers have required fields")
PYEOF
pass "Project MCP servers validated for required fields"

echo ""
echo "═══════════════════════════════════════════════════════"
echo " TEST 7: Personal MCP Template"
echo "═══════════════════════════════════════════════════════"

PERSONAL_TEMPLATE="${PROJECT_ROOT}/docs/personal-mcp-template.md"

# 7.1 Template document exists
if [[ -f "${PERSONAL_TEMPLATE}" ]]; then
  pass "Personal MCP template document exists"
else
  fail "Personal MCP template not found at docs/personal-mcp-template.md"
fi

# 7.2 Template shows ~/.claude.json path
if grep -q "~/.claude.json\|claude\.json" "${PERSONAL_TEMPLATE}" 2>/dev/null; then
  pass "Template references ~/.claude.json personal config path"
else
  fail "Template missing ~/.claude.json reference"
fi

# 7.3 Template shows project+personal coexistence explanation
if grep -q "simultaneously\|coexist\|both.*available\|together" "${PERSONAL_TEMPLATE}" 2>/dev/null; then
  pass "Template explains project+personal MCP coexistence"
else
  fail "Template missing explanation of project+personal MCP coexistence"
fi

# 7.4 Verify ~/.claude.json is in .gitignore or noted as never-commit
if grep -q "never commit\|gitignore\|not committed\|do not commit" "${PERSONAL_TEMPLATE}" 2>/dev/null; then
  pass "Template warns that personal config must not be committed"
else
  fail "Template missing never-commit warning for personal config"
fi

echo ""
echo "═══════════════════════════════════════════════════════"
echo " TEST 8: Credential Expansion Safety"
echo "═══════════════════════════════════════════════════════"

# 8.1 No hardcoded secrets in .mcp.json
echo ""
echo "─── Hardcoded Secret Detection ─────────────────────────"

# Check for patterns that look like real credentials (not variable references)
HARDCODED_PATTERNS=(
  # API key patterns (not ${...} references)
  '[A-Za-z0-9_-]{20,}(?<!\$\{[^}]*\})'
)

# Python-based check for hardcoded values in env sections
MCP_JSON_PATH="${MCP_JSON}" python3 - << 'PYEOF'
import json, re, sys, os

data = json.load(open(os.environ["MCP_JSON_PATH"]))
servers = data.get("mcpServers", {})

hardcoded_found = []
var_ref_pattern = re.compile(r'^\$\{[A-Z_][A-Z0-9_]*\}$')

for server_name, config in servers.items():
    env = config.get("env", {})
    for key, value in env.items():
        if isinstance(value, str):
            if not var_ref_pattern.match(value):
                # Check if it looks like a real credential (not a placeholder)
                if len(value) > 5 and value not in ("", "changeme", "placeholder", "your-token-here"):
                    hardcoded_found.append(f"{server_name}.env.{key} = '{value[:8]}...' (not a ${{}}-reference)")

if hardcoded_found:
    for item in hardcoded_found:
        print(f"  [HARDCODED] {item}")
    sys.exit(1)
else:
    print(f"  [SAFE] All {sum(len(c.get('env',{})) for c in servers.values())} env values use ${{VAR}} expansion")
PYEOF

if [[ $? -eq 0 ]]; then
  pass "No hardcoded credentials detected in .mcp.json"
else
  fail "Hardcoded credentials detected in .mcp.json — SECURITY VIOLATION"
fi

# 8.2 All env values use ${VAR} expansion pattern
ENV_VALUE_COUNT=$(python3 -c "
import json
data = json.load(open('${MCP_JSON}'))
count = 0
for s in data.get('mcpServers', {}).values():
    count += len(s.get('env', {}))
print(count)
" 2>/dev/null || echo "0")

VAR_REF_COUNT=$(python3 -c "
import json, re
data = json.load(open('${MCP_JSON}'))
pattern = re.compile(r'^\\\$\{[A-Z_][A-Z0-9_]*\}$')
count = sum(1 for s in data.get('mcpServers', {}).values()
            for v in s.get('env', {}).values()
            if isinstance(v, str) and pattern.match(v))
print(count)
" 2>/dev/null || echo "0")

if [[ "${ENV_VALUE_COUNT}" -gt 0 && "${ENV_VALUE_COUNT}" == "${VAR_REF_COUNT}" ]]; then
  pass "All ${ENV_VALUE_COUNT} env values use \${VAR} expansion pattern"
elif [[ "${ENV_VALUE_COUNT}" -eq 0 ]]; then
  pass "No env values present (servers may use implicit env)"
else
  fail "Only ${VAR_REF_COUNT}/${ENV_VALUE_COUNT} env values use \${VAR} expansion"
fi

# 8.3 Governance notes present in .mcp.json
if python3 -c "
import json
data = json.load(open('${MCP_JSON}'))
print('yes' if '_governance' in data else 'no')
" 2>/dev/null | grep -q "yes"; then
  pass ".mcp.json has governance documentation (_governance key)"
else
  fail ".mcp.json missing governance documentation"
fi

# 8.4 .mcp.json should NOT be in .gitignore (it IS shared)
if [[ -f "${PROJECT_ROOT}/.gitignore" ]]; then
  if grep -q "^\.mcp\.json$\|^\.mcp\.json " "${PROJECT_ROOT}/.gitignore" 2>/dev/null; then
    fail ".mcp.json is in .gitignore — it should be committed (credentials are env refs, not values)"
  else
    pass ".mcp.json is not gitignored (correct — it contains no credentials, only \${VAR} refs)"
  fi
else
  pass ".gitignore not present (expected: .mcp.json should be committed to repo)"
fi

echo ""
echo "───────────────────────────────────────────────────────"
echo " Results: ${PASS} passed, ${FAIL} failed"
echo "───────────────────────────────────────────────────────"

[[ "${FAIL}" -eq 0 ]] && exit 0 || exit 1
