# ADR-008: Work slicing and sequencing — full-stack feature PRs, infra-first sub-branches

**Status:** Proposed (owner to accept on merge of `dev/louay/22-prioritization`).
**Date:** 2026-09-20
**Scope:** how a backlog is cut into tickets and PRs, and in what order they are built. Applies to every ticket after the Stage-A/B design phase (#22). The current backlog's concrete order is in `DOC/architecture/delivery_sequence.md`; this ADR holds the reasoning so the next backlog can be cut the same way.

## Context

Stage A (specs) and Stage B's design pass (#36) finished with eleven planned tickets, cut by *surface*: infra (#53, #56), one backend ticket for the whole API (#57), and one frontend ticket per screen (#37–#41, #55). Cut that way, the API is one large PR nothing can be tried against, the frontends are built against mocks, and the work totals 19 PRs. The repo's own constraints then shaped a better cut:

- **Vertical slices are the architecture** (ADR-001, CC-27). Ticketing by feature matches how the code is organised; ticketing by surface fights it.
- **A worktree and session per ready issue** (AW-2), branches named `dev/<actor>/<issue>-<slug>` — so every unit of work needs its own issue number.
- **The human merges everything into `int`** (AW-25). Reviewer attention is the scarce resource, not agent throughput.
- **Every push to `dev/**` auto-applies that branch's Terraform to the one shared `dev` environment**, with no plan step (`infra-deploy-dev.yml`, "last-push-wins"). A branch whose checkout lacks another branch's unmerged infra plans to destroy it. Pushes to `int` auto-apply to `int`; only `prod` is reviewer-gated.
- **Token cost tracks turn count and idle gaps more than change size** (`DOC/usage/notes.md`): short, continuous sessions are cheaper than long or resumed ones.

## Decision

| ID | Rule |
|---|---|
| WS-1 | **The unit of delivery is one full-stack feature: one issue, one PR into `int`.** A feature carries its infra, backend and frontend together, so it can be exercised end to end through the real UI. |
| WS-2 | **Sequence work inside a feature with sub-branches**, cut from the feature branch and merged back with `git merge --no-ff`, in the order **infra → backend → frontend**. Sub-branches are the unit of a session and of the plan (AW-1..5). AW-4 plan review and TS-17 code review run **per sub-branch**, before the merge into the feature branch; only the human PR review is per feature. |
| WS-3 | **A feature owns the infra it first needs.** The first feature to need a resource creates it; later features only append (an index, an IAM statement, an env var). Shared infra is not ticketed on its own. Each feature keeps its Terraform in its own files and IAM policy resources so parallel branches don't edit the same lines. |
| WS-4 | **Protect the shared `dev` environment.** While a feature branch with unmerged infra is pushed, every other `dev/**` push must include that infra (branch from it) or wait; sub-branches are cut *after* the infra sub-branch merges so pushing them is idempotent. At most one infra-bearing feature branch is pushed unmerged at a time. |
| WS-5 | **Escape hatch: split a feature into more than one PR** only when (a) it has no user-facing surface yet (the foundation), or (b) it carries infra that sibling features in flight would otherwise revert — then the infra lands first as a small sub-PR. |
| WS-6 | **Order by dependency, then by fan-out.** Do the prerequisite everything else needs first (foundation, then sign-in), then the hub the most features build on (the canvas), then run the independent features in parallel, and last the feature that carries a release gate (public exposure, held for the moderation decision). |
| WS-7 | **Reuse existing issue numbers when documents cite them.** Specs and ADRs reference tickets by number; renumbering breaks those links. Retitle and re-scope the surviving issue, absorb the tasks of the issues it replaces, and close the replaced issues as superseded with a comment mapping each old task to its new home. |
| WS-8 | **A feature issue's body is the plan's fixed floor** (`plan_template.md`): objective, sub-branch checklist (infra → backend → frontend), affected slices, out-of-scope, end-to-end verification, real-environment gates, and blocked-by. |
| WS-9 | **Cap concurrency by reviewer capacity, not by agent capacity.** Default: no more than three feature worktrees in flight at once. The cap is a tunable, revisited against the token log. |

## Options considered

1. **Cut by surface** (status quo: infra tickets, one backend ticket, one frontend ticket per screen). Rejected: the backend PR cannot be tried, frontends are built on mocks (contract drift found late), 19 PRs to review, and infra tickets have no feature to justify them.
2. **Cut by backend module, frontend separate** (per-slice API PRs, then UI PRs). Rejected: it fixes the size of the backend PR but keeps the end-to-end blind spot and still needs ~19 PRs.
3. **Full-stack feature PRs with sub-branches.** Chosen. Trades bigger PRs for fewer review round-trips and an API verified through its real consumer.
4. **One infra ticket per resource, ahead of features** (the original #53/#56). Rejected by WS-3: the resource is created before anything uses it, so its real needs (for example the IAM actions a transaction requires) are guessed instead of discovered.

## Consequences

- **Fewer, larger PRs.** 19 becomes 8 for the current backlog. Reviewing one PR commit-by-commit along the `--no-ff` boundaries is the intended reading order. The automatic review (AW-11) sees the whole feature diff at once, which is a known limit on its depth.
- **Foundation and sign-in are still their own PRs** (WS-5a), and Content/Public may need an infra sub-PR (WS-5b).
- **The canvas is a serial bottleneck** for four features (WS-6); that is a property of the product's dependency graph, not of this decision, and the sequencing makes it explicit.
- **A rule the pipeline cannot enforce.** WS-4 depends on the owner's discipline. If it is violated the cost is a broken or reverted dev environment, not a data loss in `int`/`prod`. A hook or workflow guard is a possible follow-up (`branching_strategy.md`'s enforcement ladder), not part of this decision.
- **FinOps hypothesis, to be tested — not yet evidenced.** Sub-branch sessions are meant to be short and continuous (fewer idle-gap cache rebuilds), and verifying against the real API should avoid rework tokens spent reconciling mocks with the API. The token log (`DOC/usage/token_usage_log.md`) is the measurement: log cost per feature, and compare it against the ~$40 planning sessions and the #8/#10–11 build sessions already recorded. If features cost materially more than the sum of their sub-branches would, revisit WS-2's session-per-sub-branch guidance.
- **Not decided here:** how to label the feature issues on GitHub, and whether WS-4 becomes a guard.
