# Agentic units — what exists, what's active, and when to use it

Companion to `CLAUDE.md`, `DOC/architecture/agentic_workflow_processes.md`, and
`DOC/architecture/branching_strategy.md`: those are the rule source of truth (AW-1..26, TS-1..19),
this is the practical "which unit fires when, and how do I invoke the parts that don't fire on
their own" reference. Issue #6 built the first four units — coding, testing, review, maintenance;
Unit 5 (branching & governance) was added in a later session, per AW-21..26.

## Unit 1 — Coding (active, every session)

Fires automatically, with no manual step, on every dev-loop session.

| Artifact | Path | Rule |
|---|---|---|
| Root `CLAUDE.md` | `CLAUDE.md` | AW-14 |
| Plan template | `DOC/templates/plan_template.md` | AW-5 |
| Risk-path config | `.claude/risk-paths.json` | AW-6 |
| High-risk detection Hook | `.claude/hooks/detect-high-risk.py` | AW-6 tier 1 |
| Plan-review subagent | `.claude/agents/plan-reviewer.md` | AW-4 |
| Risk-classifier subagent | `.claude/agents/risk-classifier.md` | AW-6 tier 2 |
| Hard-deny list | `.claude/settings.json` (`permissions.deny`) | AW-22 |

**When it fires, concretely:** the Hook runs on every touched file automatically (PreToolUse) —
no one invokes it. It escalates to `risk-classifier` only when the mechanical path/import match
against `risk-paths.json` is ambiguous; `risk-classifier` in turn routes to `plan-reviewer` (plan
stage) or a pre-commit `/code-review` pass (past plan stage) only on a `HIGH-RISK` verdict. On a
low-risk, single-file, no-logic-change edit, Plan Mode itself can be skipped per AW-1 — everything
past that (Hooks, TS-17) still runs unconditionally.

## Unit 2 — Testing (active, folds into Unit 1's mechanism)

No separate artifact — TS-16/18/19's Hook-free rules live as prose in `CLAUDE.md`'s Dev workflow
section, and TS-17 (writer/reviewer separation for high-risk logic) is satisfied by Unit 1's same
risk-path Hook → classifier → review chain, not a second one.

**When it applies:** every coding session, same trigger points as Unit 1 — no invocation needed.
Blocked-pending-real-test-runner items (TS-1/7/12/15/19's Hook halves — pytest/Vitest CI gates,
order-randomization, retry bounds) don't apply yet; wire them the moment app code lands beyond
`draft/`. TS-13 (no numeric coverage gate) is a permanent, deliberate absence, not a blocked item.

## Unit 3 — Review (created, not enabled)

| Artifact | Path | Rule |
|---|---|---|
| Review workflow | `.github/workflows/claude-review.yml` | AW-11/12/13 |

**When it fires:** automatically, on `opened`/`synchronize`/`reopened`/`ready_for_review` — not
literally every `pull_request` event, and a draft PR is skipped until it's marked ready (a
deliberate cost trade-off, not an oversight) — the workflow itself isn't opt-in otherwise.
"Not enabled" means something narrower: it is **not** a required status check in branch
protection on `main`, so a red or absent run never blocks a merge, and its own check-run
conclusion is hardcoded neutral regardless of findings (AW-13) — merge authority stays fully
human. Turning this "on" in the fuller sense (making it gate merges) is a separate, deliberate
step, not something this workflow file does by existing.

**Plan-tier fallback, current status:** the workflow always runs the local `/code-review` path
today, as a fresh-context background subagent — there is no real managed-service integration
wired yet, so "tries the managed Code Review service first" (AW-12) describes the target shape,
not what `claude-review.yml` actually does right now. This degrades gracefully either way, so it
didn't need to wait on confirming this account's plan tier — but the managed branch itself is
still a TODO (issue #19), not a silently-assumed-done feature.

## Unit 4 — Maintenance (created, not enabled)

| Artifact | Path | Rule |
|---|---|---|
| LSP-usage check | `.claude/skills/lsp-usage-check/SKILL.md` | AW-17 |
| Doc-freshness check | `.claude/skills/doc-freshness-check/SKILL.md` | AW-20 |

**When to invoke:** manually, on demand — `/lsp-usage-check` or `/doc-freshness-check`, or via the
Skill tool by name. Neither is wired to a cron/Routine trigger; each SKILL.md carries a TODO
noting that scheduling is a deliberate later step (same "no live infra yet" reasoning as AW-7/8's
deferral), so nothing here fires without a person or session asking for it.

- Run `lsp-usage-check` periodically once AW-16 (LSP plugin install) is done, to catch the
  "installed ≠ used" drift the research behind AW-17 named — e.g. after a run of sessions that did
  a lot of symbol navigation, to spot-check whether LSP calls or grep fallback actually happened.
- Run `doc-freshness-check` periodically against `CLAUDE.md` files (root, and per-slice ones once
  AW-15 files exist) — e.g. after a batch of renames/deletions, or before trusting an old
  `CLAUDE.md` pointer in a fresh session.

## Unit 5 — Branching & governance (created, partially enabled)

| Artifact | Path | Rule |
|---|---|---|
| Branching strategy doc | `DOC/architecture/branching_strategy.md` | AW-21..26 |
| Hard-deny list | `.claude/settings.json` (`permissions.deny`) | AW-22 (Tier 1) |
| Code ownership | `CODEOWNERS` | AW-23 (Tier 2) |
| GitHub branch protection on `main`/`int` | GitHub repo settings, not a file | AW-22/AW-25 |

**When it fires:** the hard-deny list and `CODEOWNERS` are live now — no invocation needed, same
as Unit 1's Hook. Branch protection is a manual GitHub Settings step, walked through in chat
rather than applied via `gh api` at the user's request; not yet confirmed done as of this
writing. AW-26 (commit attribution) is deliberately **not** active yet — the doc scopes it to
kick in only once an autonomous/unattended Claude action exists in this repo; until then the
existing `Co-Authored-By` trailer plus direct human review is judged sufficient.

**What's still open:** tracked in issue #19 — a distinct Claude GitHub identity (App for CI, a
machine-user account for local sessions), the ADR-004 Part 3 amendment (its "routine changes may
apply directly" text now conflicts with AW-24's stricter "never applies infra"), and the two
mechanical Hooks (AW-23's autonomous-file-lock, AW-26's commit-attribution) that need
autonomous-session infra which doesn't exist yet to be built against.

## Quick reference: what needs a person to do something

| Unit | Fires on its own? | Manual step, if any |
|---|---|---|
| 1 — Coding | Yes, every session | None — AW-1 bypass is the only opt-out, and only for Plan Mode |
| 2 — Testing | Yes, rides Unit 1 | None |
| 3 — Review | Yes, every PR | None to *run* it; adding it to branch protection is a separate, unmade decision |
| 4 — Maintenance | No | Invoke `/lsp-usage-check` or `/doc-freshness-check` by name |
| 5 — Branching & governance | Partially — deny-list/CODEOWNERS yes, branch protection no | Apply GitHub branch protection manually (steps given in chat, issue #19 tracks the rest) |

## Deferred entirely (not built this pass)

AW-7/8/9/10 (deployment monitoring/rollback) and AW-9's `autoMode.environment` allowlist have no
artifacts yet — no deployed infra exists to monitor. AW-12's plan-tier confirmation and AW-9's
allowlist are both named in ADR-004 as decisions for Lou, not something a file resolves on its
own. See `DOC/architecture/agentic_workflow_processes.md` section F for the full AW-1..20
checklist against what's built vs. deferred, and issue #19 for Unit 5's own deferred items
(Claude identity, ADR-004 amendment, the two mechanical Hooks).
