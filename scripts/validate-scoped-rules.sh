#!/usr/bin/env bash
# Tests 2 & 3: Scoped Rule Loading and Isolation Validation
# Verifies that rule files exist, have valid frontmatter, and that glob patterns
# match the correct file paths (and do NOT match incorrect paths).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
RULES_DIR="${PROJECT_ROOT}/.claude/rules"

PASS=0
FAIL=0

pass() { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }

echo ""
echo "═══════════════════════════════════════════════════════"
echo " TEST 2: Scoped Rule Files Existence and Structure"
echo "═══════════════════════════════════════════════════════"

# 2.1 Rules directory exists
if [[ -d "${RULES_DIR}" ]]; then
  pass "Rules directory exists: .claude/rules/"
else
  fail "Rules directory not found: ${RULES_DIR}"
  exit 1
fi

# 2.2 Required rule files exist
declare -a REQUIRED_RULES=(
  "api-conventions.md"
  "testing.md"
  "frontend.md"
  "database.md"
)

for rule in "${REQUIRED_RULES[@]}"; do
  rule_path="${RULES_DIR}/${rule}"
  if [[ -f "${rule_path}" ]]; then
    pass "Rule file exists: ${rule}"
  else
    fail "Missing rule file: ${rule}"
  fi
done

# 2.3 Frontmatter validation — each rule must have paths: defined
echo ""
echo "─── Frontmatter Validation ─────────────────────────────"
for rule in "${REQUIRED_RULES[@]}"; do
  rule_path="${RULES_DIR}/${rule}"
  [[ ! -f "${rule_path}" ]] && continue

  # Check for YAML frontmatter opening
  if head -1 "${rule_path}" | grep -q "^---"; then
    pass "${rule}: has YAML frontmatter"
  else
    fail "${rule}: missing YAML frontmatter (expected --- at line 1)"
  fi

  # Check for paths: key
  if grep -q "^paths:" "${rule_path}"; then
    pass "${rule}: has paths: key in frontmatter"
  else
    fail "${rule}: missing paths: key in frontmatter"
  fi
done

# 2.4 Content validation — each rule must have substantial content
echo ""
echo "─── Content Validation ─────────────────────────────────"
for rule in "${REQUIRED_RULES[@]}"; do
  rule_path="${RULES_DIR}/${rule}"
  [[ ! -f "${rule_path}" ]] && continue

  line_count=$(wc -l < "${rule_path}")
  if [[ "${line_count}" -gt 20 ]]; then
    pass "${rule}: has substantial content (${line_count} lines)"
  else
    fail "${rule}: too short (${line_count} lines — expected > 20)"
  fi
done

echo ""
echo "═══════════════════════════════════════════════════════"
echo " TEST 3: Rule Isolation — Glob Path Matching"
echo "═══════════════════════════════════════════════════════"

# Helper: test whether a glob pattern matches a path
# Uses bash's glob matching logic
glob_matches() {
  local pattern="$1"
  local filepath="$2"
  # Use python for reliable globbing with ** support
  python3 -c "
import fnmatch, sys
pattern = sys.argv[1]
path = sys.argv[2]
# Normalize pattern for fnmatch (** → * for simple cases)
# For proper ** support we check both with and without leading path
import pathlib
p = pathlib.PurePosixPath(path)
pat = pathlib.PurePosixPath(pattern)
result = p.match(pattern)
sys.exit(0 if result else 1)
" "${pattern}" "${filepath}" 2>/dev/null
}

echo ""
echo "─── Scenario: Editing src/api/orders/create.py ─────────"
TEST_FILE="src/api/orders/create.py"

# api-conventions.md should match
API_PATTERNS=$(python3 -c "
import re
content = open('${RULES_DIR}/api-conventions.md').read()
match = re.search(r'paths:\s*\n(.*?)(?:\n---|\Z)', content, re.DOTALL)
if match:
    lines = [l.strip().lstrip('- ').strip('\"') for l in match.group(1).split('\n') if l.strip().startswith('-')]
    print('\n'.join(lines))
" 2>/dev/null || echo "src/api/**/*")

MATCHED_API=false
while IFS= read -r pattern; do
  [[ -z "${pattern}" ]] && continue
  if python3 -c "
import pathlib
p = pathlib.PurePosixPath('${TEST_FILE}')
result = p.match('${pattern}')
exit(0 if result else 1)
" 2>/dev/null; then
    MATCHED_API=true
    break
  fi
done <<< "${API_PATTERNS}"

if ${MATCHED_API}; then
  pass "api-conventions.md MATCHES '${TEST_FILE}' (expected: load)"
else
  fail "api-conventions.md does NOT match '${TEST_FILE}' (expected: load)"
fi

# testing.md should NOT match src/api/orders/create.py
MATCHED_TEST=false
TEST_PATTERNS=$(python3 -c "
import re
content = open('${RULES_DIR}/testing.md').read()
match = re.search(r'paths:\s*\n(.*?)(?:\n---|\Z)', content, re.DOTALL)
if match:
    lines = [l.strip().lstrip('- ').strip('\"') for l in match.group(1).split('\n') if l.strip().startswith('-')]
    print('\n'.join(lines))
" 2>/dev/null || echo "**/*.test.*")

while IFS= read -r pattern; do
  [[ -z "${pattern}" ]] && continue
  if python3 -c "
import pathlib
p = pathlib.PurePosixPath('${TEST_FILE}')
result = p.match('${pattern}')
exit(0 if result else 1)
" 2>/dev/null; then
    MATCHED_TEST=true
    break
  fi
done <<< "${TEST_PATTERNS}"

if ! ${MATCHED_TEST}; then
  pass "testing.md does NOT match '${TEST_FILE}' (expected: no load)"
else
  fail "testing.md MATCHES '${TEST_FILE}' — unexpected scope leakage"
fi

echo ""
echo "─── Scenario: Editing tests/order.test.ts ───────────────"
TEST_FILE2="tests/order.test.ts"

# testing.md should match
MATCHED_TEST2=false
while IFS= read -r pattern; do
  [[ -z "${pattern}" ]] && continue
  if python3 -c "
import pathlib
p = pathlib.PurePosixPath('${TEST_FILE2}')
result = p.match('${pattern}')
exit(0 if result else 1)
" 2>/dev/null; then
    MATCHED_TEST2=true
    break
  fi
done <<< "${TEST_PATTERNS}"

if ${MATCHED_TEST2}; then
  pass "testing.md MATCHES '${TEST_FILE2}' (expected: load)"
else
  fail "testing.md does NOT match '${TEST_FILE2}' (expected: load)"
fi

# api-conventions.md should NOT match tests/order.test.ts
MATCHED_API2=false
while IFS= read -r pattern; do
  [[ -z "${pattern}" ]] && continue
  if python3 -c "
import pathlib
p = pathlib.PurePosixPath('${TEST_FILE2}')
result = p.match('${pattern}')
exit(0 if result else 1)
" 2>/dev/null; then
    MATCHED_API2=true
    break
  fi
done <<< "${API_PATTERNS}"

if ! ${MATCHED_API2}; then
  pass "api-conventions.md does NOT match '${TEST_FILE2}' (expected: no load)"
else
  fail "api-conventions.md MATCHES '${TEST_FILE2}' — unexpected scope leakage"
fi

echo ""
echo "─── Scenario: Editing README.md (no rules should load) ──"
README_FILE="README.md"
ANY_MATCHED=false
for rule in "${REQUIRED_RULES[@]}"; do
  rule_path="${RULES_DIR}/${rule}"
  [[ ! -f "${rule_path}" ]] && continue

  RULE_PATTERNS=$(python3 -c "
import re
content = open('${rule_path}').read()
match = re.search(r'paths:\s*\n(.*?)(?:\n---|\Z)', content, re.DOTALL)
if match:
    lines = [l.strip().lstrip('- ').strip('\"') for l in match.group(1).split('\n') if l.strip().startswith('-')]
    print('\n'.join(lines))
" 2>/dev/null || echo "")

  while IFS= read -r pattern; do
    [[ -z "${pattern}" ]] && continue
    if python3 -c "
import pathlib
p = pathlib.PurePosixPath('${README_FILE}')
result = p.match('${pattern}')
exit(0 if result else 1)
" 2>/dev/null; then
      ANY_MATCHED=true
      fail "${rule} matches '${README_FILE}' — global leakage detected"
      break
    fi
  done <<< "${RULE_PATTERNS}"
done

if ! ${ANY_MATCHED}; then
  pass "No scoped rules match 'README.md' (expected: no rules loaded)"
fi

echo ""
echo "───────────────────────────────────────────────────────"
echo " Results: ${PASS} passed, ${FAIL} failed"
echo "───────────────────────────────────────────────────────"

[[ "${FAIL}" -eq 0 ]] && exit 0 || exit 1
