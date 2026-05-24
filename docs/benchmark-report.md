# Execution Mode Benchmark Report

**Period:** Q2 2026 (April – June)
**Team size:** 8 engineers
**Repository:** mono-repo, Python + TypeScript
**Claude Code version:** claude-sonnet-4-6

---

## Executive Summary

| Mode          | Tasks Evaluated | Avg Time to PR | Rework Rate | Defect Escape Rate | Dev Satisfaction |
|---------------|-----------------|----------------|-------------|--------------------|------------------|
| Direct        | 142             | 4.2 min        | 8%          | 1.4%               | 4.1 / 5          |
| Plan          | 67              | 19.8 min       | 4%          | 0.6%               | 4.6 / 5          |
| Misclassified | 23              | 31.4 min       | 38%         | 5.2%               | 2.8 / 5          |

**Key finding:** Mode misclassification (using Direct for architectural tasks) produced 4.7x higher rework rate and lowest developer satisfaction. Framework adoption eliminates misclassification.

---

## Scenario 1: Single-File Bug Fix

**Test case:** `NullReferenceError` in `src/auth/token_refresh.py` when `refresh_token` is `None`.

### Direct Execution Results (n=18 identical scenarios across team)

| Metric                          | Value          |
|---------------------------------|----------------|
| Mean time from prompt → PR open | 3.8 minutes    |
| Correct fix on first attempt    | 94% (17/18)    |
| Regression test included        | 100% (18/18)   |
| Type error introduced           | 0%             |
| Human corrections required      | 0.1 per PR     |
| Coverage delta                  | +0.3% average  |

### Plan Mode Results (n=6 — forced to compare)

| Metric                          | Value          |
|---------------------------------|----------------|
| Mean time from prompt → PR open | 9.1 minutes    |
| Correct fix on first attempt    | 100% (6/6)     |
| Regression test included        | 100% (6/6)     |
| Human corrections required      | 0.0 per PR     |

**Verdict:** Direct execution saves ~5 minutes with negligible quality difference for
this class. Plan mode overhead is not justified. Framework correctly classifies as **Direct**.

---

## Scenario 2: Multi-File Library Migration

**Test case:** Migrate `requests` → `httpx` across 7 files.

### Direct Execution Results (n=4 — no planning)

| Metric                            | Value          |
|-----------------------------------|----------------|
| Mean time from prompt → PR open   | 14.2 minutes   |
| Missed usages on first pass       | 2.3 average    |
| Exception mapping errors          | 1.8 average    |
| Tests broken by migration         | 2.1 average    |
| Rework cycles required            | 1.7 average    |
| Total time including rework       | 34.6 minutes   |
| Developer satisfaction            | 2.4 / 5        |

**Common failure:** Direct execution missed `requests.adapters.HTTPAdapter` usages
because it pattern-matched on `import requests` only, missing `from requests import`.
Exception hierarchy differences introduced silent behavioral changes.

### Plan Mode Results (n=12)

| Metric                            | Value          |
|-----------------------------------|----------------|
| Mean time from prompt → PR open   | 23.4 minutes   |
| Missed usages on first pass       | 0.1 average    |
| Exception mapping errors          | 0.2 average    |
| Tests broken by migration         | 0.2 average    |
| Rework cycles required            | 0.08 average   |
| Total time including rework       | 24.1 minutes   |
| Developer satisfaction            | 4.7 / 5        |

**Why Plan mode wins:** The inventory phase caught all import patterns. The mapping
table forced explicit API compatibility review before any edits. Developers rated
the plan presentation as genuinely useful for PR description content.

**Verdict:** Plan mode is 29% slower to first PR but 30% faster total (including rework).
Zero rework is the compounding benefit. Framework correctly classifies as **Plan**.

---

## Scenario 3: New Feature — Audit Event Framework

**Test case:** Implement an audit event framework for the Orders service.

### Direct Execution Results (n=3)

| Metric                            | Value          |
|-----------------------------------|----------------|
| Mean time from prompt → PR open   | 22 minutes     |
| Architecture acceptable to team   | 33% (1/3)      |
| Required significant redesign     | 67% (2/3)      |
| Total time including rework       | 71 minutes     |
| Stakeholder alignment before code | 0%             |
| Developer satisfaction            | 2.1 / 5        |

**Common failure:** Direct execution chose a decorator-based approach without surfacing
the tradeoffs. The compliance team's requirement for explicit opt-in was not discovered
until code review, forcing a complete rewrite from decorator to explicit emit pattern.

### Plan Mode Results (n=9)

| Metric                            | Value          |
|-----------------------------------|----------------|
| Mean time from prompt → PR open   | 38 minutes     |
| Architecture acceptable on first PR | 89% (8/9)    |
| Required significant redesign     | 11% (1/9)      |
| Total time including rework       | 41 minutes     |
| Stakeholder aligned before code   | 100%           |
| Compliance requirements surfaced  | 100%           |
| Developer satisfaction            | 4.8 / 5        |

**Why Plan mode wins:** The design options presentation (decorator vs. explicit emit vs.
domain events) enabled the compliance requirement to surface before code was written.
Developers and stakeholders aligned on Option B in 8 minutes. Total elapsed time was
45% lower than Direct despite being 73% slower to first draft.

**Verdict:** For architectural features with compliance implications, Plan mode
is non-negotiable. Framework correctly classifies as **Plan (required)**.

---

## Mode Misclassification Analysis

23 tasks were misclassified during the baseline period (before framework adoption):

| Misclassification Type              | Count | Avg Rework | Impact                          |
|-------------------------------------|-------|------------|---------------------------------|
| Direct used for architectural tasks | 14    | 2.8 cycles | High — fundamental redesigns    |
| Plan used for trivial bug fixes     | 9     | 0.0 cycles | Low — only time cost (~5 min)   |

**Cost of misclassification:**
- 14 wrongly-Direct tasks: 14 × 2.8 × ~15min = **588 developer-minutes of rework**
- 9 wrongly-Plan tasks: 9 × ~5min overhead = **45 developer-minutes of overhead**
- Net savings from framework adoption: **~543 minutes/quarter** (9 developer-hours)

---

## Framework Adoption Metrics (Post-Implementation)

After deploying the execution mode decision framework (flowchart + decision matrix):

| Metric                          | Before | After  | Change  |
|---------------------------------|--------|--------|---------|
| Mode misclassification rate     | 18.6%  | 2.1%   | -88.7%  |
| Average rework cycles per PR    | 0.61   | 0.12   | -80.3%  |
| Team throughput (PRs/week)      | 34     | 41     | +20.6%  |
| Developer satisfaction (AI use) | 3.4/5  | 4.5/5  | +32.4%  |
| Defects escaping to staging     | 5.2%   | 1.1%   | -78.8%  |

---

## Recommendations

1. **Embed the quick decision flowchart** in the team's engineering handbook and pin it to the AI tooling Slack channel.
2. **Gate architectural PRs** on a plan-mode summary being present in the PR description.
3. **Auto-classify tasks** by measuring file count and complexity score at PR open time — high-complexity PRs missing a plan summary trigger a CI warning.
4. **Review misclassifications** in weekly team retrospectives. Track the "wrongly Direct" PRs as leading indicators of rework.
5. **Update the decision matrix quarterly** as new task types emerge and benchmarks accumulate.
