# ADR-0002: Clean-code rules and enforcement strategy for the portfolio app

**Status:** Accepted. Step 4 (final rule list) is defined in `clean-code-rules.md`.
**Date:** 2026-09-08
**Scope:** this ADR decides the enforcement *strategy* for clean code — how much discipline to layer on top of the point-1 architecture, and by what mechanism — balanced against quality/correctness benefit and token/cost burden. It does not enumerate the final rule list, tool configs, or lint-rule IDs; that's step 4, to follow only once this decision is approved.

## Context and objective

ADR-0001 (architecture) explicitly carried four concerns forward into this point because they're properties of code *within* a module, not of module boundaries: indirection tax on hallucination, machine-checkable contracts over documented conventions, resistance to volume-driven quality collapse, and fail-fast vs. fail-silent behavior. This ADR resolves how those get addressed.

Full best-practice research backing this decision — canonical style guides for Python/FastAPI and Angular/TypeScript, plus Claude/LLM-specific code-generation correctness research — lives in `clean-code-research.md` and is cited by reference below, not reproduced here.

Objective: decide how much clean-code enforcement to adopt and by what mechanism, balancing measured correctness/quality benefit against token/context cost and setup/maintenance burden — not to catalog every possible clean-code rule (that's step 4).

## Note on scope: clean code and testing overlap

Clean code is mostly about how code is written, but a few of its rules only mean anything if something exercises them: "errors should never pass silently" is unverifiable without a test that actually triggers the failure path, and "verifiability at the module boundary" (ADR-0001's criterion E, vertical-slice's weakest score) only becomes real once something tests through that boundary. This ADR names these coherence-dependent rules where they come up, but *how* they get tested (fixtures, coverage expectations, what's unit vs. integration) is point 3's decision, not this one — flagged here so it isn't lost, not resolved here.

## Decision drivers (criteria)

Only properties of the enforcement *strategy* — not the content of individual rules, which is step 4.

| ID | Criterion | Question it answers | Source |
|---|---|---|---|
| A | Correctness impact | Does this approach have real evidence of improving generated-code correctness? | Type-constrained decoding (arXiv:2504.09246); AI-Generated Smells (arXiv:2605.02741) |
| B | Determinism / enforcement reliability | Does the rule actually get followed, or is it advisory only? | Anthropic Claude Code docs — "hooks are deterministic... CLAUDE.md instructions are advisory" |
| C | Token/context cost per turn | How much ongoing context budget does this approach consume every session? | Anthropic Claude Code docs — "over-specified CLAUDE.md" causes ignored rules |
| D | Interaction with constraint-decay risk | Does adding this increase the accumulated-constraint burden shown to correlate with correctness loss — especially given FastAPI already scores worst-in-class partly from its own type-hint machinery? | Constraint Decay (arXiv:2605.06445) |
| E | Coverage breadth | Does it address what actually matters (naming, duplication, length, comments, error handling, type-consistency), or only a narrow slice? | AI-Generated Smells (naming/docs not caught by static analysis in that study — a real mechanical-coverage gap); *Clean Code* canon |
| F | Setup/maintenance burden | How much one-time and ongoing effort to configure and keep working? | Reasoned engineering judgment — not a specific study |
| G | Resistance to long-session drift | Does it hold up across a long agentic session without decaying? | ContextEcho persona-drift (arXiv:2605.24279) — validated for register drift, **not tested for code-style drift**; transfer is plausible, not proven |

## Considered options

1. **Prose-heavy** — write the full clean-code canon (naming, SRP, DRY, comments, error handling, plus every stack-specific style-guide rule) into CLAUDE.md/`.claude/rules/`, no automated enforcement.
2. **Mechanical-only** — a formatter, a strict type-checker (mypy/pyright, TypeScript `strict`), and a linter (ruff, ESLint+typescript-eslint) wired as hooks/CI gates; no prose beyond pointing at the toolchain.
3. **Hybrid** — the same mechanical core as option 2, plus a short, curated prose layer covering only what can't be mechanically checked (naming intent, SRP judgment calls, comment-explains-why, error-handling-not-silent).
4. **Baseline / none** — no dedicated clean-code layer; rely on the point-1 architecture and Claude's default behavior alone. Included as the zero-cost comparison point, not a serious candidate.

## Evaluation

Scores use a 1–3 scale (1 = Weak, 2 = Moderate, 3 = Strong; N/A where a criterion doesn't apply).

### Option 1 — Prose-heavy

| A | B | C | D | E | F | G |
|---|---|---|---|---|---|---|
| 1 | 1 | 1 | 1 | 3 | 2 | 1 |

Contested points:
- **E is 3, the option's one real strength** — prose can encode things no linter can (naming intent, SRP judgment, whether a comment is actually true) — the same reason it can't just be discarded, only downsized.
- **C and G are both 1** — this is exactly the failure mode Anthropic's own docs name directly: an over-long CLAUDE.md gets partially ignored, and nothing about prose survives context compaction any better than persona register does (per the drift paper, extrapolated).
- **D is 1, not clearly established** — the Constraint Decay paper measured framework/DB/architecture constraints, not CLAUDE.md prose volume specifically; scoring this Weak is an extrapolation from the same mechanism (accumulated explicit constraint load), not a directly-tested claim.

### Option 2 — Mechanical-only

| A | B | C | D | E | F | G |
|---|---|---|---|---|---|---|
| 2 | 3 | 3 | 2 | 1 | 2 | 3 |

Contested points:
- **A is 2, not 3** — the strongest evidence (type-constrained decoding) is for constraining generation *during* decoding, not for post-hoc type-checker/linter feedback; a hook-based check is the practical analogue but a weaker version of the studied intervention, and TYPYBENCH shows type hints alone don't guarantee cross-file consistency.
- **D is 2** — mechanical/ORM-style constraints were the cheapest in the Constraint Decay data (SQLAlchemy −1.5pp, Sequelize −0.6pp vs. Clean Architecture −9.1pp), so leaning on mechanical checks is the lower-risk lever, but it isn't risk-free (FastAPI's own type-hint machinery is already implicated in that paper).
- **E is 1, the real weakness** — nothing here catches naming intent, SRP boundaries, or a misleading comment; the AI-smells paper's own tooling had the same blind spot.

### Option 3 — Hybrid

| A | B | C | D | E | F | G |
|---|---|---|---|---|---|---|
| 3 | 2 | 2 | 2 | 3 | 2 | 3 |

Contested points:
- **A is 3** — combines the two evidenced levers (deterministic mechanical checks + a prose layer short enough to survive, per Anthropic's own "ruthlessly prune" fix) rather than relying on either alone.
- **B is 2, not 3** — most of the load-bearing rules are deterministic; the few prose ones stay advisory, they're just few enough not to get lost.
- **F is 2, same as option 2** — the hybrid's mechanical core needs identical setup; the added prose layer is marginal on top, not a second full effort, provided it's kept genuinely short.

### Option 4 — Baseline / none

| A | B | C | D | E | F | G |
|---|---|---|---|---|---|---|
| 1 | N/A | 3 | 3 | 1 | 3 | N/A |

Contested points:
- **A is 1, not N/A** — doing nothing doesn't neutrally opt out; it leaves the documented default tendencies in place (long methods scaling *up* with model capability, ρ=0.94 volume-quality decay), which is a real, evidenced cost, not an absence of one.
- **C and F are 3, the option's only genuine strengths** — zero added cost and zero added constraint by construction; useful as the comparison point, not as a serious candidate given what A and E cost in return.

## Full comparison table

| ID | Prose-heavy | Mechanical-only | Hybrid | Baseline/none |
|---|---|---|---|---|
| A | 1 | 2 | 3 | 1 |
| B | 1 | 3 | 2 | N/A |
| C | 1 | 3 | 2 | 3 |
| D | 1 | 2 | 2 | 3 |
| E | 3 | 1 | 3 | 1 |
| F | 2 | 2 | 2 | 3 |
| G | 1 | 3 | 3 | N/A |

## Decision

**Hybrid: a mechanical core (formatter, strict type-checker, linter, wired as hooks/CI gates) plus a short, curated prose layer for what can't be mechanically checked.** It wins A, E, and G outright, ties Mechanical-only on B/C/D close enough not to matter, and avoids Prose-heavy's C/D/G weaknesses and Mechanical-only's E weakness. Baseline is confirmed as the wrong call — its only wins (C, F) are cost-avoidance, not quality, and A/E show that cost is being paid for real, not phantom, risk.

## Consequences and limitations

**A tension to watch, not resolved by this ADR:** this project's stack (FastAPI, locked in via `ARCHITECTURE.md`) is the second-worst-scoring backend framework in the Constraint Decay benchmark, and that paper implicates FastAPI's own type-hint-driven validation as a contributor. ADR-0001 already planned to lean on typed contracts at slice boundaries to fix the README's named silent-fix risk (fractional ordering, auth allowlist), and this ADR's mechanical core leans on typing further still. Neither ADR is wrong to do this — but "add more types = strictly better" is not a safe assumption to carry forward unexamined; watch actual correctness outcomes rather than assuming the typed-contract strategy pays off by default.

Risks and limitations of the hybrid strategy itself, stated generally:

- **The mechanical core has a real, known blind spot (criterion E).** It cannot catch misleading names, wrong SRP boundaries, or a comment that lies about what the code does — that's what the prose layer exists for, and it only works if that layer stays genuinely short (per Anthropic's own "ruthlessly prune" guidance) rather than regrowing into option 1 over time.
- **Drift resistance for the prose half is inferred, not proven.** The persona-drift research (criterion G's source) validates that long-session drift is real and survives compaction, but it never tested whether a short CLAUDE.md rule survives better than a long one, or whether code-style adherence drifts the same way conversational register does. Treat the prose layer as the weaker half of this strategy for that reason, not as equally reliable to the mechanical half.
- **Setup burden is real and falls entirely on step 4.** This ADR decides the strategy, not the toolchain; choosing "hybrid" commits to actually configuring and wiring a formatter, type-checker, and linter as enforced hooks — that work doesn't happen automatically because this decision is made.
- **Mechanical checks catching a category (e.g., "types are enforced") doesn't mean any specific rule is automatically well-calibrated.** A strict linter/type-checker configuration can still be too aggressive (excess false-positive friction) or too permissive (rubber-stamping bad structure). This ADR doesn't leave that open-ended: step 4 resolves it per rule, not in the abstract — see below.

### How step 4 will close the calibration gap

The hybrid strategy says *mechanical core + curated prose*, but doesn't yet say which of the two, specifically, each individual rule belongs to. Step 4 closes that gap by giving every rule in the final list a **recommended implementation surface** — recommended, not mandated, since the actual wiring may turn out differently once it's tried. The candidate surfaces, in roughly the order this ADR's evidence favors them:

- **Hook** — a deterministic pre-tool-use/pre-commit gate (formatter, type-checker, linter run as a blocking check). The strongest lever per criterion B; reserved for rules that are fully mechanically checkable.
- **Lint/type-checker config** — a specific enabled rule ID (a ruff/eslint rule, a mypy/pyright strictness flag) rather than a bespoke hook script, when the existing toolchain already covers it.
- **Skill** — a packaged, on-demand-loaded checklist or procedure (e.g., invoked before a slice is considered done) for a rule that's judgment-based but routine enough to script as a repeatable review pass, without paying its context cost every turn the way permanent CLAUDE.md prose would.
- **Agent/task definition** — built into how a coding task or subagent role is framed in point 4's multi-agent workflow (e.g., a reviewer role whose task definition names the rule explicitly), for rules that are really about *how work gets scoped* rather than something checkable after the fact.
- **CLAUDE.md / `.claude/rules/` prose** — the smallest, most tightly pruned tier, reserved for the genuine residual (naming intent, SRP judgment, comment truthfulness) that criterion E already identified as mechanically uncoverable.

This taxonomy — not just "mechanical vs. prose" — is what step 4 will apply rule-by-rule, which is what turns "calibration is unresolved" into a per-rule, reviewable recommendation instead of a blanket open problem.