# spiresen-saga

Multi-tenant box-canvas app (Angular + FastAPI/Mangum/Lambda + DynamoDB). This file is pointers and gotchas only — decisions and reasoning live in `ADR/` and `DOC/architecture/`, not here (AW-14).

## Source of truth

- `ADR/ADR-001..004` — accepted decisions (architecture, clean code, testing, agentic workflow) and why.
- `DOC/architecture/application_architecture.md` — stack, schema, current open items.
- `DOC/architecture/clean_code_rules.md` (CC-1..33), `testing_strategy.md` (TS-1..19), `agentic_workflow_processes.md` (AW-1..20) — the concrete, rule-tagged specs.
- `DOC/templates/plan_template.md` — the plan template referenced below.

(A consolidated `DOC/architecture/agentic_fleet.md` — how the artifacts below fit together and how to invoke them — is planned but not yet written; this section will point to it once it exists, not before.)

## Dev workflow

Full mechanics are in `agentic_workflow_processes.md` — don't restate them here, just the pointers:

- **AW-1** — Plan Mode bypass criterion. **AW-2/AW-3** — worktree-per-issue, cross-session coordination only at real shared boundaries.
- **AW-6/TS-17** — two-tier high-risk detection (`.claude/hooks/detect-high-risk.py` against `.claude/risk-paths.json`, falling back to the `risk-classifier` subagent). Never the primary agent's own unassisted call.
- **AW-4** — high-risk plans get a fresh-context review via the `plan-reviewer` subagent before implementation starts.
- **TS-16/18/19** — no rigid test-first ordering; scoped test execution in the inner loop; flag (don't silently retry) a test that flips across 2 runs.

## Code navigation

AW-16: LSP over grep for symbol navigation, once the plugin is installed for this stack — not yet done (`agentic_workflow_processes.md` section E).

## Structure

Vertical-slice architecture (ADR-001) — no standalone `ARCHITECTURE.md`, the directory structure is the map (AW-18). Per-slice `CLAUDE.md` files get added as slices are built (AW-15); none exist yet since the app is still in `draft/`.
