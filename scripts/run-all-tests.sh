#!/usr/bin/env bash
# Full Validation Suite — runs all 9 governance tests
# Usage: ./scripts/run-all-tests.sh [--verbose]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERBOSE="${1:-}"

TOTAL_PASS=0
TOTAL_FAIL=0
FAILED_SUITES=()

run_suite() {
  local name="$1"
  local script="$2"
  local output

  if output=$(bash "${SCRIPT_DIR}/${script}" 2>&1); then
    local suite_pass
    suite_pass=$(echo "${output}" | grep -c "\[PASS\]" || true)
    local suite_fail
    suite_fail=$(echo "${output}" | grep -c "\[FAIL\]" || true)
    TOTAL_PASS=$((TOTAL_PASS + suite_pass))
    TOTAL_FAIL=$((TOTAL_FAIL + suite_fail))
    echo "  ✓ ${name} — ${suite_pass} passed, ${suite_fail} failed"
    [[ "${VERBOSE}" == "--verbose" ]] && echo "${output}"
    return 0
  else
    local suite_pass
    suite_pass=$(echo "${output}" | grep -c "\[PASS\]" || true)
    local suite_fail
    suite_fail=$(echo "${output}" | grep -c "\[FAIL\]" || true)
    TOTAL_PASS=$((TOTAL_PASS + suite_pass))
    TOTAL_FAIL=$((TOTAL_FAIL + suite_fail))
    FAILED_SUITES+=("${name}")
    echo "  ✗ ${name} — ${suite_pass} passed, ${suite_fail} failed"
    if [[ "${VERBOSE}" == "--verbose" ]]; then
      echo "${output}"
    else
      # Show only failures in non-verbose mode
      echo "${output}" | grep "\[FAIL\]" | sed 's/^/    /'
    fi
    return 1
  fi
}

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║     Team AI Development Workflow — Validation Suite       ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "Running all governance validation tests..."
echo ""

OVERALL_PASS=true

run_suite "Test 1: CLAUDE.md Enforcement"         "validate-claude-md.sh"      || OVERALL_PASS=false
run_suite "Tests 2&3: Scoped Rules + Isolation"   "validate-scoped-rules.sh"   || OVERALL_PASS=false
run_suite "Tests 4&5: Skill Isolation + Tools"    "validate-skills.sh"         || OVERALL_PASS=false
run_suite "Tests 6,7,8: MCP + Credentials"        "validate-mcp.sh"            || OVERALL_PASS=false
run_suite "Test 9: Execution Mode Framework"       "validate-execution-mode.sh" || OVERALL_PASS=false

echo ""
echo "══════════════════════════════════════════════════════════"
echo ""

if ${OVERALL_PASS}; then
  echo "  RESULT: ALL TESTS PASSED"
  echo ""
  echo "  Total: ${TOTAL_PASS} checks passed, ${TOTAL_FAIL} failed"
  echo ""
  echo "  Governance status: COMPLIANT"
  echo "  Workflow is production-ready."
  echo ""
  exit 0
else
  echo "  RESULT: VALIDATION FAILED"
  echo ""
  echo "  Total: ${TOTAL_PASS} checks passed, ${TOTAL_FAIL} failed"
  echo ""
  echo "  Failed suites:"
  for suite in "${FAILED_SUITES[@]}"; do
    echo "    - ${suite}"
  done
  echo ""
  echo "  Run with --verbose for full output."
  echo "  Fix failures before deploying this workflow to a team."
  echo ""
  exit 1
fi
