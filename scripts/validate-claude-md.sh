#!/usr/bin/env bash
# Test 1: CLAUDE.md Enforcement Validation
# Verifies that CLAUDE.md exists and contains all required sections.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CLAUDE_MD="${PROJECT_ROOT}/CLAUDE.md"

PASS=0
FAIL=0

pass() { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }

echo ""
echo "═══════════════════════════════════════════════════════"
echo " TEST 1: CLAUDE.md Governance Enforcement"
echo "═══════════════════════════════════════════════════════"

# 1.1 File exists
if [[ -f "${CLAUDE_MD}" ]]; then
  pass "CLAUDE.md exists at project root"
else
  fail "CLAUDE.md not found at ${CLAUDE_MD}"
  exit 1
fi

# 1.2 Required sections present
declare -a REQUIRED_SECTIONS=(
  "Coding Standards"
  "Naming Conventions"
  "Architecture Guidelines"
  "Testing Standards"
  "Error Handling Standards"
  "Logging Standards"
  "Security Standards"
  "Dependency Management"
  "Documentation Standards"
  "PR Quality Expectations"
)

for section in "${REQUIRED_SECTIONS[@]}"; do
  if grep -q "${section}" "${CLAUDE_MD}"; then
    pass "Section found: ${section}"
  else
    fail "Missing section: ${section}"
  fi
done

# 1.3 Security keywords present
declare -a SECURITY_KEYWORDS=(
  "hardcoded"
  "environment variable"
  "input validation"
  "parameterized"
)

for keyword in "${SECURITY_KEYWORDS[@]}"; do
  if grep -qi "${keyword}" "${CLAUDE_MD}"; then
    pass "Security rule present: '${keyword}'"
  else
    fail "Missing security rule for: '${keyword}'"
  fi
done

# 1.4 Coverage threshold defined
if grep -q "85%" "${CLAUDE_MD}"; then
  pass "Coverage threshold (85%) defined"
else
  fail "Coverage threshold not defined in CLAUDE.md"
fi

# 1.5 AI contributor section
if grep -q "AI Contributor" "${CLAUDE_MD}"; then
  pass "AI contributor expectations section present"
else
  fail "Missing AI contributor expectations section"
fi

# 1.6 File size sanity (should be substantial)
LINE_COUNT=$(wc -l < "${CLAUDE_MD}")
if [[ "${LINE_COUNT}" -gt 50 ]]; then
  pass "CLAUDE.md has substantial content (${LINE_COUNT} lines)"
else
  fail "CLAUDE.md appears too short (${LINE_COUNT} lines — expected > 50)"
fi

echo ""
echo "───────────────────────────────────────────────────────"
echo " Results: ${PASS} passed, ${FAIL} failed"
echo "───────────────────────────────────────────────────────"

[[ "${FAIL}" -eq 0 ]] && exit 0 || exit 1
