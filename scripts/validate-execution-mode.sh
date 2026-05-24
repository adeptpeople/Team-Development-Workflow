#!/usr/bin/env bash
# Test 9: Execution Mode Framework Validation
# Verifies the decision framework document is complete and recommendations
# align with task complexity classifications.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
FRAMEWORK_DOC="${PROJECT_ROOT}/docs/execution-mode-framework.md"

PASS=0
FAIL=0

pass() { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }

echo ""
echo "═══════════════════════════════════════════════════════"
echo " TEST 9: Execution Mode Decision Framework"
echo "═══════════════════════════════════════════════════════"

# 9.1 Framework document exists
if [[ -f "${FRAMEWORK_DOC}" ]]; then
  pass "Execution mode framework document exists"
else
  fail "Framework document not found: docs/execution-mode-framework.md"
  exit 1
fi

# 9.2 Required sections
echo ""
echo "─── Required Section Check ─────────────────────────────"

check_section() {
  local label="$1"
  shift
  for pattern in "$@"; do
    if grep -qiE "${pattern}" "${FRAMEWORK_DOC}" 2>/dev/null; then
      pass "Section present: ${label}"
      return
    fi
  done
  fail "Missing section: ${label}"
}

check_section "Direct Execution"    "Direct Execution"
check_section "Plan Mode"           "Plan Mode"
check_section "Decision Matrix"     "Decision Matrix"
check_section "Scenarios"           "Scenario"
check_section "Quick Heuristics"    "Heuristic" "flowchart" "Flowchart" "Quick Decision"
check_section "Governance Rules"    "Governance" "Rules"
check_section "Metrics/Benchmarks"  "Metrics" "Benchmark" "rework rate"

# 9.3 Decision matrix alignment
echo ""
echo "─── Mode Recommendation Alignment ─────────────────────"

check_task_mode() {
  local description="$1"
  local expected_mode="$2"
  shift 2
  local patterns=("$@")

  local found=false
  for pattern in "${patterns[@]}"; do
    local context
    context=$(grep -A8 -B2 -iE "${pattern}" "${FRAMEWORK_DOC}" 2>/dev/null | head -30 || true)
    if [[ -n "${context}" ]] && echo "${context}" | grep -qiE "${expected_mode}"; then
      found=true
      break
    fi
  done

  if ${found}; then
    pass "Task '${description}' → mode '${expected_mode}' (documented)"
  else
    fail "Task '${description}' — mode '${expected_mode}' not clearly recommended"
  fi
}

check_task_mode "single-file bug fix"      "direct"   "bug fix" "null pointer" "single.file"
check_task_mode "library migration"        "plan"     "migration" "httpx" "requests"
check_task_mode "new feature / audit"      "plan"     "audit" "new feature" "implement"
check_task_mode "auth / security change"   "plan"     "auth" "security" "compliance"
check_task_mode "rename / refactor"        "direct"   "rename" "refactor"

# 9.4 Security/auth tasks must always recommend plan mode (mandatory)
echo ""
echo "─── Security Task → Plan Mode Enforcement ─────────────"
AUTH_SECTION=$(grep -A10 -iE "auth|security|compliance" "${FRAMEWORK_DOC}" 2>/dev/null | head -40 || true)

if echo "${AUTH_SECTION}" | grep -qiE "plan|required|always|mandatory"; then
  pass "Auth/security tasks have Plan Mode requirement stated"
else
  fail "Auth/security tasks missing mandatory Plan Mode requirement"
fi

# 9.5 Metrics defined
echo ""
echo "─── Metrics Coverage ───────────────────────────────────"

check_metric() {
  local label="$1"
  shift
  for pattern in "$@"; do
    if grep -qiE "${pattern}" "${FRAMEWORK_DOC}" 2>/dev/null; then
      pass "Metric defined: ${label}"
      return
    fi
  done
  fail "Missing metric: ${label}"
}

check_metric "rework rate"     "rework rate"
check_metric "latency"         "latency" "time to"
check_metric "defect rate"     "defect" "escape"
check_metric "test pass rate"  "test pass" "coverage"

# 9.6 Three scenarios present
echo ""
echo "─── Scenario Coverage ──────────────────────────────────"

check_scenario() {
  local label="$1"
  shift
  for pattern in "$@"; do
    if grep -qiE "${pattern}" "${FRAMEWORK_DOC}" 2>/dev/null; then
      pass "Scenario present: ${label}"
      return
    fi
  done
  fail "Missing scenario: ${label}"
}

check_scenario "Bug fix scenario"          "Scenario 1" "bug fix" "null pointer"
check_scenario "Migration scenario"        "Scenario 2" "migration" "httpx" "requests"
check_scenario "New feature scenario"      "Scenario 3" "new feature" "audit"

# 9.7 Benchmark comparison tables
if grep -qE "Time to PR|Rework rate|\| Metric" "${FRAMEWORK_DOC}" 2>/dev/null; then
  pass "Benchmark comparison tables present (Direct vs Plan metrics)"
else
  fail "Missing benchmark comparison tables"
fi

# 9.8 Quick decision flowchart
if grep -qiE "flowchart|Is the fix|Is the solution|Quick Decision" "${FRAMEWORK_DOC}" 2>/dev/null; then
  pass "Quick decision heuristics/flowchart present"
else
  fail "Missing quick decision heuristics or flowchart"
fi

echo ""
echo "───────────────────────────────────────────────────────"
echo " Results: ${PASS} passed, ${FAIL} failed"
echo "───────────────────────────────────────────────────────"

[[ "${FAIL}" -eq 0 ]] && exit 0 || exit 1
