# spiresen-saga

Multi-tenant box-canvas app (Angular + FastAPI/Mangum/Lambda + DynamoDB). This file is pointers and gotchas only — decisions and reasoning live in `ADR/` and `DOC/architecture/`, not here (AW-14).

## Source of truth

- `ADR/ADR-001..004` — accepted decisions (architecture, clean code, testing, agentic workflow) and why.
- `DOC/architecture/application_architecture.md` — stack, schema, current open items.
- `DOC/architecture/clean_code_rules.md` (CC-1..33), `testing_strategy.md` (TS-1..19), `agentic_workflow_processes.md` (AW-1..20) — the concrete, rule-tagged specs.
- `DOC/architecture/branching_strategy.md` (AW-21..26) — branch taxonomy, actor permissions (human vs. Claude), deploy trigger contract, and an enforcement-surface ladder (prose/Skill → Hook → GitHub-side config) for picking a control's strength by consequence severity. Claude may only push to `dev/claude/*` branches and reach `main`/`int` via human-approved PR — never delete a branch, never apply infra, never edit agentic-definition files autonomously.
- `DOC/templates/plan_template.md` — the plan template referenced below.
- `DOC/frontend/` — product/UI specs (e.g. `boxes-plan.md`) for the box-canvas surface. These describe *what to build*; any new data-model entity or field they introduce must be reconciled back into `application_architecture.md` (the schema source of truth), not left to live only here.

(A consolidated `DOC/architecture/agentic_fleet.md` — how the artifacts below fit together and how to invoke them — is planned but not yet written; this section will point to it once it exists, not before.)

## Dev workflow

Full mechanics are in `agentic_workflow_processes.md` — don't restate them here, just the pointers:

- **AW-1** — Plan Mode bypass criterion. **AW-2/AW-3** — worktree-per-issue, cross-session coordination only at real shared boundaries.
- **AW-6/TS-17** — two-tier high-risk detection (`.claude/hooks/detect-high-risk.py` against `.claude/risk-paths.json`, falling back to the `risk-classifier` subagent). Never the primary agent's own unassisted call.
- **AW-4** — high-risk plans get a fresh-context review via the `plan-reviewer` subagent before implementation starts.
- **TS-16/18/19** — no rigid test-first ordering; scoped test execution in the inner loop; flag (don't silently retry) a test that flips across 2 runs.
- **TS-1/7/12/15/19's Hook halves** (pytest/Vitest CI gates, order-randomization, retry bounds) — blocked, not skipped: no real test runner exists yet beyond `draft/`. Wire these the moment app code lands in a real slice.
- **TS-13** — no numeric coverage gate in CI, deliberately and permanently (not blocked-pending-tooling like the row above): coverage stays diagnostic-only unless a future decision explicitly revisits this.

## Code navigation

AW-16: LSP over grep for symbol navigation, once the plugin is installed for this stack — not yet done (`agentic_workflow_processes.md` section E).

## Structure

Vertical-slice architecture (ADR-001) — no standalone `ARCHITECTURE.md`, the directory structure is the map (AW-18). Per-slice `CLAUDE.md` files get added as slices are built (AW-15); none exist yet since the app is still in `draft/`.
