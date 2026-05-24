#!/usr/bin/env bash
# Tests 4 & 5: Skill Isolation and Tool Restriction Enforcement
# Verifies skill files are correctly structured with fork context and tool restrictions.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SKILLS_DIR="${PROJECT_ROOT}/.claude/skills"

PASS=0
FAIL=0

pass() { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }

echo ""
echo "═══════════════════════════════════════════════════════"
echo " TEST 4: Skill Isolation — Context and Structure"
echo "═══════════════════════════════════════════════════════"

# 4.1 Skills directory exists
if [[ -d "${SKILLS_DIR}" ]]; then
  pass "Skills directory exists: .claude/skills/"
else
  fail "Skills directory not found: ${SKILLS_DIR}"
  exit 1
fi

# 4.2 Find all skill.md files
SKILL_FILES=$(find "${SKILLS_DIR}" -name "skill.md" 2>/dev/null)
SKILL_COUNT=$(echo "${SKILL_FILES}" | grep -c "skill.md" || true)

if [[ "${SKILL_COUNT}" -gt 0 ]]; then
  pass "Found ${SKILL_COUNT} skill(s) in .claude/skills/"
else
  fail "No skill.md files found under ${SKILLS_DIR}"
  exit 1
fi

# 4.3 Each skill must declare context: fork
echo ""
echo "─── Isolation Context Validation ───────────────────────"
while IFS= read -r skill_file; do
  skill_name=$(basename "$(dirname "${skill_file}")")

  if grep -q "context: fork" "${skill_file}"; then
    pass "${skill_name}/skill.md: declares 'context: fork' (isolated execution)"
  else
    fail "${skill_name}/skill.md: missing 'context: fork' — skill may pollute parent context"
  fi
done <<< "${SKILL_FILES}"

# 4.4 Each skill must declare allowed-tools
echo ""
echo "─── Tool Restriction Declaration ───────────────────────"
while IFS= read -r skill_file; do
  skill_name=$(basename "$(dirname "${skill_file}")")

  if grep -q "allowed-tools:" "${skill_file}"; then
    pass "${skill_name}/skill.md: declares allowed-tools restriction"
  else
    fail "${skill_name}/skill.md: missing allowed-tools — unrestricted tool access"
  fi
done <<< "${SKILL_FILES}"

echo ""
echo "═══════════════════════════════════════════════════════"
echo " TEST 5: Tool Restriction — Permitted vs Forbidden"
echo "═══════════════════════════════════════════════════════"

# 5.1 library-migration skill tool restrictions
LM_SKILL="${SKILLS_DIR}/library-migration/skill.md"
if [[ -f "${LM_SKILL}" ]]; then

  # Permitted tools
  declare -a PERMITTED_TOOLS=("Read" "Grep" "Edit" "Bash")
  for tool in "${PERMITTED_TOOLS[@]}"; do
    if grep -q "${tool}" "${LM_SKILL}"; then
      pass "library-migration: '${tool}' is in allowed-tools (permitted)"
    else
      fail "library-migration: '${tool}' not found in allowed-tools (unexpected)"
    fi
  done

  # Forbidden tools (should NOT appear in allowed-tools)
  declare -a FORBIDDEN_TOOLS=("Write" "WebFetch" "WebSearch" "Agent")
  for tool in "${FORBIDDEN_TOOLS[@]}"; do
    # Extract just the allowed-tools section to check
    ALLOWED_SECTION=$(python3 -c "
import re, sys
content = open(sys.argv[1]).read()
match = re.search(r'allowed-tools:(.*?)(?:\n---|\Z)', content, re.DOTALL)
if match:
    print(match.group(1))
" "${LM_SKILL}" 2>/dev/null || echo "")

    if echo "${ALLOWED_SECTION}" | grep -q "^\s*-\s*${tool}$"; then
      fail "library-migration: '${tool}' found in allowed-tools — should be restricted"
    else
      pass "library-migration: '${tool}' NOT in allowed-tools (correctly restricted)"
    fi
  done

  # 5.2 Verify skill has guardrail language for context isolation
  if grep -q "forked context\|fork context\|parent conversation\|context bleed\|no parent" "${LM_SKILL}"; then
    pass "library-migration: has explicit isolation guardrails in skill body"
  else
    fail "library-migration: missing isolation guardrails (skill should warn against parent context use)"
  fi

  # 5.3 Verify phased execution (plan before action)
  if grep -q "Wait for\|approval\|before.*execut\|before.*proceeding\|before.*implement" "${LM_SKILL}"; then
    pass "library-migration: requires explicit approval gate before execution"
  else
    fail "library-migration: missing approval gate — skill may execute without review"
  fi

else
  fail "library-migration/skill.md not found — cannot validate tool restrictions"
fi

echo ""
echo "─── Cross-Skill Isolation Test ─────────────────────────"

# 5.4 Verify skills do not share state directives
# Each skill should explicitly state it runs in forked context
ISOLATION_DECLARATIONS=0
while IFS= read -r skill_file; do
  if grep -q "forked context\|fork\|isolated\|parent conversation" "${skill_file}"; then
    ISOLATION_DECLARATIONS=$((ISOLATION_DECLARATIONS + 1))
  fi
done <<< "${SKILL_FILES}"

if [[ "${ISOLATION_DECLARATIONS}" -ge "${SKILL_COUNT}" ]]; then
  pass "All ${SKILL_COUNT} skills declare isolation behavior (no cross-skill state)"
else
  fail "Only ${ISOLATION_DECLARATIONS}/${SKILL_COUNT} skills declare isolation — potential context bleed"
fi

# 5.5 Verify no skill allows Write+Bash+WebFetch combined (maximum blast radius)
echo ""
echo "─── Maximum Blast Radius Check ──────────────────────────"
while IFS= read -r skill_file; do
  skill_name=$(basename "$(dirname "${skill_file}")")
  has_write=$(grep -c "^\s*-\s*Write" "${skill_file}" || true)
  has_bash=$(grep -c "^\s*-\s*Bash" "${skill_file}" || true)
  has_webfetch=$(grep -c "^\s*-\s*WebFetch" "${skill_file}" || true)

  if [[ "${has_write}" -gt 0 && "${has_bash}" -gt 0 && "${has_webfetch}" -gt 0 ]]; then
    fail "${skill_name}: grants Write+Bash+WebFetch simultaneously — maximum blast radius, review required"
  else
    pass "${skill_name}: does not combine Write+Bash+WebFetch (acceptable blast radius)"
  fi
done <<< "${SKILL_FILES}"

echo ""
echo "───────────────────────────────────────────────────────"
echo " Results: ${PASS} passed, ${FAIL} failed"
echo "───────────────────────────────────────────────────────"

[[ "${FAIL}" -eq 0 ]] && exit 0 || exit 1
