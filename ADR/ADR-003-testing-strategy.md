# ADR-0003: Testing strategy for the portfolio app

**Status:** Proposed — awaiting review. Per instruction, this ADR is the stopping point for point 3; the final testing strategy document (step 4) is not defined until this decision is approved.
**Date:** 2026-09-08
**Scope:** two bundled decisions — (1) test-level shape and stack tooling, (2) agentic verification policy (how Claude's own testing behavior should be constrained/guided). Step 4 will turn the accepted policies into concrete, per-rule guidance the way `clean-code-rules.md` did for point 2 — not defined here.

## Context and objective

ADR-0001 and ADR-0002 both left something open for this point. ADR-0001 named vertical-slice's weakest criterion as E (no free verifiability seam) and flagged it as a real tradeoff to compensate for. ADR-0002 flagged that a few clean-code rules (fail-fast behavior, CC-16–CC-19; verifiability at the module boundary) only mean anything once something tests them, and deferred that to this point. This ADR resolves both.

Full research backing this decision — test-pyramid theory, stack-specific tooling for FastAPI/Lambda/DynamoDB and Angular 22, and Claude/LLM-specific testing-correctness research — lives in `testing-strategy-research.md`, cited by reference below.

Objective: decide (1) what shape and depth of testing is proportionate for this app, with concrete tooling, and (2) what policies govern how Claude verifies its own work during coding — balancing measured correctness benefit against token/cost burden, the same lens ADR-0002 used.

## Part 1 — Test-level shape and tooling

### Decision drivers (criteria)

| ID | Criterion | Question it answers | Source |
|---|---|---|---|
| A | Confidence-per-cost | Does this shape catch real bugs relative to the effort spent writing/maintaining it? | Dodds' "confidence quotient"; Fowler's conditional-pyramid footnote |
| B | Fit to this app's actual risk profile | Is the investment proportionate to a low-traffic, small-blast-radius personal app? | **Reasoned inference, not a sourced finding** — no canonical risk-to-depth formula exists (see `testing-strategy-research.md` Part A §1) |
| C | Coverage of box-canvas drag-drop interaction bugs | Does this shape catch bugs that only appear when components actually interact? | Dodds — isolated unit tests with mocked collaborators miss exactly this class of bug |
| D | Coverage of DynamoDB single-table access-pattern bugs | Does this shape exercise real query patterns, not just mocked-out repository logic? | `moto`'s documented GSI-pagination gap (GitHub #7725) — a residual risk regardless of shape, but some shapes exercise more of the real path than others |
| E | Test-suite reliability (flakiness) | Is the suite itself hermetic, or does it introduce non-determinism? | Google SWE book (hermeticity, ~1% flakiness value-loss threshold); Google's flaky-tests post |
| F | Compatible with ADR-0002's Hook surface | Can this run as a fast, deterministic blocking gate, per ADR-0002's enforcement taxonomy? | ADR-0002 |
| G | Setup/maintenance burden | How much one-time and ongoing tooling effort? | FastAPI/Angular official docs (idiomatic vs. bespoke effort) |

### Considered options

1. **Classic Pyramid** — unit-heavy, heavy mocking of collaborators (DynamoDB, Cognito), Google-style 80/15/5 shape scaled down.
2. **Testing Trophy** (Dodds) — integration-heavy: FastAPI `TestClient` + `Depends()`-overrides hitting real slice code end-to-end, Angular `TestBed` host-wrapper tests through real component composition, a thin e2e layer on top.
3. **Ice-cream cone** — mostly end-to-end tests, thin unit/integration layers. Named anti-pattern, included as comparison.
4. **Minimal/smoke-only** — a handful of smoke checks, no dedicated suite; rely on ADR-0002's mechanical linting/typing plus Claude's own judgment. Zero-cost comparison point, not a serious candidate.

### Evaluation

Scores use a 1–3 scale (1 = Weak, 2 = Moderate, 3 = Strong; N/A where a criterion doesn't apply).

**Option 1 — Classic Pyramid**

| A | B | C | D | E | F | G |
|---|---|---|---|---|---|---|
| 2 | 2 | 1 | 2 | 3 | 3 | 2 |

Contested: **C is 1** — heavy mocking of collaborators is the exact failure mode Dodds names (a component passes isolated while breaking on real composition), and this app's core feature (nested drag-drop) lives almost entirely in inter-component behavior.

**Option 2 — Testing Trophy**

| A | B | C | D | E | F | G |
|---|---|---|---|---|---|---|
| 3 | 3 | 3 | 3 | 2 | 2 | 2 |

Contested: **E and F are 2, not 3** — integration tests through `moto`/`TestBed` are still hermetic and fast enough to gate, just slightly slower/less isolated than pure mocked-unit tests; a real but small cost for winning A/B/C/D outright.

**Option 3 — Ice-cream cone**

| A | B | C | D | E | F | G |
|---|---|---|---|---|---|---|
| 1 | 1 | 2 | 2 | 1 | 1 | 1 |

Contested: **C and D are 2, not 1** — real e2e tests against a real dev DynamoDB table and real drag events would genuinely catch these bug classes, including the moto GSI gap — the option isn't wrong about *what* it catches, it's wrong about the *cost* of catching it this way (E, F, G all Weak).

**Option 4 — Minimal/smoke-only**

| A | B | C | D | E | F | G |
|---|---|---|---|---|---|---|
| 1 | 2 | 1 | 1 | 3 | 3 | 3 |

Contested: **B is 2, not 3** — could look proportionate for a trivial project, but the README itself names correctness-critical logic (fractional ordering, auth allowlist) that this app actually has, so "minimal" isn't as safely scaled-down as it looks.

### Full comparison table

| ID | Pyramid | Trophy | Ice-cream cone | Minimal |
|---|---|---|---|---|
| A | 2 | 3 | 1 | 1 |
| B | 2 | 3 | 1 | 2 |
| C | 1 | 3 | 2 | 1 |
| D | 2 | 3 | 2 | 1 |
| E | 3 | 2 | 1 | 3 |
| F | 3 | 2 | 1 | 3 |
| G | 2 | 2 | 1 | 3 |

### Decision

**Testing Trophy**, on the strength of A, B, C, D — the criteria that measure whether bugs actually get caught — accepting a small, deliberate cost on E/F relative to Pyramid and Minimal.

**Concrete tooling:**
- Backend: `pytest` + FastAPI `TestClient` + `Depends()`-overrides as the primary layer (integration-level, hitting real slice code); `moto` for DynamoDB, accepting its documented GSI-pagination gap as a residual risk; a small number of pure-function "small"-tier (Google taxonomy) unit tests for logic with no I/O at all (fractional-order calculation, box-nesting validation).
- Frontend: **Vitest** (Angular 22 CLI's current default, not Jasmine/Karma) with `TestBed` host-wrapper components for the box-canvas, asserting on simulated pointer/drag events and resulting DOM/state rather than internals.
- E2E: a thin **Playwright** layer (chosen over Cypress for auto-waiting and native drag/OAuth-redirect handling — a reasoned tooling choice, not something Angular's own docs recommend, since Angular stays neutral) covering only the critical path, not exhaustive scenarios.
- No numeric coverage gate in CI — coverage tools stay diagnostic (find untested areas), never a pass/fail threshold.

## Part 2 — Agentic verification policy

Not a scored comparison — these are additive policies, each adopted or rejected against direct evidence, governing how Claude verifies its own work.

| Policy | Verdict | Evidence |
|---|---|---|
| Grounded execution (tests actually run) is the primary correctness signal; Claude's self-review is not sufficient alone | **Adopted** | Self-repair bottlenecked by self-feedback quality, human feedback 1.58x better (Olausson et al.); even Claude-4-Sonnet only 79.93% agreement with execution ground truth as a judge (CodeJudgeBench); judge approval reversed 6 real metric regressions (LLM-as-a-Judge Is Not an Oracle) |
| Rigid test-first-before-code is **not** mandated | **Rejected as a hard rule** | Test-first alone gives only +1-3pp (TDD-Agent ablation); most "TDD failures" were interpretation mismatches, not bugs (WebApp1K); no discernible quality difference but 3-8.5x more tokens in an informal trial (Fowler). Iterative execution access matters more than write-order. |
| Writer/reviewer separation for high-risk logic specifically (the README's named risks: fractional ordering, auth allowlist; anything touching ADR-0001's criteria D/E) | **Adopted, scoped — not universal** | A separate critic model killed 78% of mutants the original model's own tests missed; cross-provider separation was both more effective and 6.4x cheaper per kill (adversarial test-hardening study); matches Anthropic's own explicit guidance ("have one Claude write tests, then another write code to pass them... a fresh context improves code review") |
| Scoped/targeted test execution by default, not full-suite every inner-loop iteration | **Adopted** | Prohibiting execution cost only 1.25pp resolve-rate (not significant) while cutting 56-62% of tokens (`To Run or Not to Run`); impact-scoped testing cut regressions ~70% relative, while a generic "do TDD" instruction *without* scoping made regressions worse (TDAD) |
| No numeric coverage target as a gate | **Adopted** | Converging Fowler + Google SWE book guidance (coverage becomes a ceiling, not a floor); SpecBench shows the validation-metric-vs-true-performance gap grows ~28pp per 10x LOC — exactly the dynamic a coverage target invites gaming toward |
| Flaky-test handling requires execution-based re-run evidence before concluding "flaky, not a bug" | **Adopted, calibration deferred to step 4** | 58% of real E2E flaky failures aren't diagnosable from code/logs alone; code-based flaky classifiers collapse to near-useless under honest evaluation (flaky-detection-limits study). No agentic-loop-specific research exists to calibrate exact retry counts — flagged as an open gap, not invented |

## Consequences and limitations

**This closes the loop both prior ADRs left open.** ADR-0001's criterion E (verifiability seam) is answered concretely: FastAPI's `Depends()`-override mechanism, not a re-architecture. ADR-0002's fail-fast rules (CC-16–CC-19) now have an enforcement path: the Trophy's integration tests are what actually exercise those failure branches.

Risks and limitations, stated generally:

- **`moto`'s GSI-pagination gap is not eliminated by this decision, only partially mitigated.** No test shape chosen here removes the need to be aware that a moto-only suite can pass while a real query-pattern bug ships. Treat as a residual, named risk, not a solved problem.
- **Criterion B (risk-proportionate depth) is reasoned judgment, not evidence** — flagged explicitly in the grid, same as ADR-0001's criterion I. Don't let it silently gain authority in a future re-scoring.
- **The flaky-test retry policy is adopted in principle but not calibrated.** "Rerun before concluding flaky" is directionally supported by evidence; the specific retry count/timeout is a step-4 decision with no research to anchor it precisely.
- **Writer/reviewer separation has a real cost** (running two models/contexts instead of one) and is deliberately scoped to high-risk logic rather than applied universally — step 4 will need to name exactly which logic qualifies, not leave it to per-task judgment alone.
- **The "optimize cheap, deploy strong" 5.6-54x cost figure is cited as an architectural analogy, not a code-testing-specific number** — its domain (evolutionary prompt optimization) differs from this project's use case; don't restate it in step 4 as if it were measured for code testing.