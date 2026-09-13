# spiresen-saga

Multi-tenant box-canvas app (Angular + FastAPI/Mangum/Lambda + DynamoDB). This file is pointers and gotchas only — decisions and reasoning live in `ADR/` and `DOC/architecture/`, not here (AW-14).

## Source of truth

- `ADR/ADR-001..004` — accepted decisions (architecture, clean code, testing, agentic workflow) and why.
- `DOC/architecture/application_architecture.md` — stack, schema, current open items.
- `DOC/architecture/clean_code_rules.md` (CC-1..33), `testing_strategy.md` (TS-1..19), `agentic_workflow_processes.md` (AW-1..20) — the concrete, rule-tagged specs.
- `DOC/templates/plan_template.md` — the plan template referenced below.

(A consolidated `DOC/architecture/agentic_fleet.md` — how the artifacts below fit together and how to invoke them — is planned but not yet written; this section will point to it once it exists, not before.)

## Dev workflow

**Bypass check (AW-1):** skip Plan Mode only when a change touches one file, changes no logic/control-flow, and is describable in one sentence (typo, log line, rename). Anything multi-file, unfamiliar, or uncertain plans first, using `DOC/templates/plan_template.md`.

**Parallel issues (AW-2/AW-3):** each ready issue gets its own git worktree + ordinary session — never a subagent or Agent Team for parallelization. Cross-session coordination happens only when two issues actually hit a shared boundary, flagged explicitly by whichever session finds it.

**High-risk logic (AW-6, TS-17):** fractional-order calculation, auth/allowlist checks, and cross-slice authorization boundaries are high-risk. Detection is never the primary agent's own unassisted call — it's two-tier:
1. Mechanical check against `.claude/risk-paths.json` (wired as a `PreToolUse` hook, `.claude/hooks/detect-high-risk.sh`).
2. If ambiguous, the `risk-classifier` subagent (`.claude/agents/risk-classifier.md`) decides.

A plan flagged high-risk gets a fresh-context review via the `plan-reviewer` subagent (`.claude/agents/plan-reviewer.md`) before implementation starts (AW-4). Code flagged high-risk gets a `/code-review` pass before commit, same detection mechanism (TS-17).

**Testing (TS-16/18/19):** no mandatory test-first ordering — tests and implementation may land in either order, but a task isn't done until both exist and pass. Run only the touched slice's tests in the inner loop; full-suite runs are for CI. A test whose result flips across 2 consecutive runs must be flagged as flaky, never silently retried.

## Code navigation

Prefer LSP-based lookups over grep for symbol navigation (AW-16) once the LSP plugin is installed for this stack (TypeScript/Python) — not yet done; see `agentic_workflow_processes.md` section E.

## Structure

Vertical-slice architecture (ADR-001) — no standalone `ARCHITECTURE.md`, the directory structure is the map (AW-18). Per-slice `CLAUDE.md` files get added as slices are built (AW-15); none exist yet since the app is still in `draft/`.
