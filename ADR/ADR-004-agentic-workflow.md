ADR-0004: Agentic workflow and multi-agent architecture for the portfolio app

Status: Accepted. Date: 2026-09-08 Scope: eight bundled decisions — (1) topology principles, (2) dev workflow role/gate assignment, (3) deployment workflow role/gate assignment, (4) review workflow role/gate assignment, (5) plan template structure and plan-stage second-agent review, (6) code documentation strategy for agent discovery, (7) bypass path for trivial changes, (8) detection mechanism for the triggers in (3)/(5)/(7)/TS-17.

This ADR states decisions and their reasoning only — the same split ADR-0002/0003 use against clean-code-rules.md/testing-strategy.md. Concrete flow diagrams, the literal plan template, exact hook/script mechanics, and worked examples all belong in the step-4 deliverable, agentic-workflow-processes.md — not duplicated here. Full research backing every decision lives in agentic-workflow-research.md, cited by reference throughout.

Context and objective

Points 1-3 each left something for this point to close: TS-17 (ADR-0003) assumed a writer/reviewer role split without defining how it's wired; point 1's seed content (root CLAUDE.md hygiene, .claude/rules/, LSP-over-grep, scratchpad/subagent discipline) has been waiting for this point's workflow to attach to.

Objective: decide what agent topology to use, for which use case, and the business-logic succession for dev, deployment, and review — covering parallel multi-issue dev work — under the same FinOps lens as points 1-3.

Part 1 — Topology decision principles

Not a single scored grid — the research says the right answer differs by use case (Anthropic's own primary source: coding is a weaker fit for its own orchestrator-worker pattern than research is, due to high interdependency). These principles are applied per use case in Parts 2-4.

Principle 1 — Default to single-agent for any single coherent unit of work. Anthropic's multi-agent research-system post names coding's high interdependency as the reason its own orchestrator-worker topology doesn't transfer well to coding. The DeepMind/MIT capability-saturation study (Nature Machine Intelligence, 2026) reinforces this: added agents help below a ~45% single-agent-baseline-accuracy threshold and hurt or plateau above it — a capable model on a small CRUD-slice task is very likely already above that line.

Principle 2 — Parallelize across independent units, not within one, via git worktrees + separate ordinary sessions, not subagents/Agent Teams. Worktrees pay ordinary per-session token cost, not the 15x multiplier Anthropic measured for multi-agent systems. Vertical-slice architecture (ADR-0001) already draws the independence boundaries this needs.

Principle 3 — Reserve subagent/isolated-context delegation for naturally parallelizable, low-interdependency roles — research/exploration (point 1), and the writer/reviewer split: a separate critic model killed 78% of mutants the original model's own tests missed (ADR-0003 research), and /code-review delivers this — a fresh-context background subagent — with no custom orchestration. Part 5 extends this same logic to the planning stage.

Principle 4 — Agent Teams and Dynamic Workflows are explicitly rejected as over-scaled for this app, on the same ceremony-to-complexity-fit logic ADR-0001 applied to DDD/hexagonal. Neither matches a personal, low-traffic, ~2-domain app. Revisit only under ADR-0001's own named trigger: a genuinely new, independent domain being added.

Part 2 — Dev workflow: role and gate assignment

Single-issue. Single agent throughout (Principle 1): explore → plan, conditionally (Part 7) → implement within one vertical slice → mechanical checks (Hooks, ADR-0002) → tests (TS-15/TS-16). The one deliberate context-split is review (Principle 3): high-risk logic (TS-17) routes to /code-review before commit; everything else commits once TS-15 passes. Part 5 adds a matching conditional gate before implementation: high-risk-logic plans also get a fresh-context plan review before code is written.

Multi-issue (parallel). Each ready issue gets its own worktree + ordinary session (Principle 2), running the single-issue flow independently — no token multiplier beyond N concurrent ordinary sessions. Cross-session coordination is the exception path, used only when issues genuinely share a boundary — expected rare, since vertical-slice architecture was chosen partly to keep slices low-coupling.

Part 3 — Deployment workflow: role and gate assignment

No established Anthropic pattern or credible case study exists for AI-driven post-deployment operational verification — flagged plainly as this ADR's least evidence-backed part, composed from primitives rather than a known-good template.

Claude's role is prepare (plan, review destructive-change diffs) and verify (post-deploy health check) — not autonomous production apply by default. Destructive/prod-scope changes require a human approval gate, matching the auto-mode classifier's own default-deny posture; routine changes may apply directly. Post-apply health checking uses two signals, not one: a synthetic smoke test, and a log-based error scan (CloudWatch, for this Mangum/Lambda backend) — the smoke test alone would miss cold-starts, async-invocation failures, and errors on paths it doesn't exercise. Either signal failing flags unhealthy; rollback is a human decision, never autonomous.

Any detected issue — from this post-deploy check or from a separate scheduled monitoring routine at any other time — is flagged, never silently logged and never auto-applied to main. Claude investigates and opens a draft PR with a proposed fix on its own branch; a human reviews before merge. This is not a bespoke design — it mirrors Claude Code's own documented Routines "alert-triage" pattern verbatim: a monitoring trigger fires a routine that investigates the alert, correlates it with recent commits, and "opens a draft pull request with a proposed fix and a link back to the alert," so "on-call reviews the PR instead of starting from a blank terminal." (Confirmed primary source; the one detail not documented by Anthropic is an intermediate GitHub-issue-creation step — their examples go straight from alert to PR, so this project follows that same shape rather than inserting an extra issue-first hop.)

Part 4 — Review workflow ("gh claude"): role and gate assignment

Every PR routes through the Claude Code GitHub Action. Review depth depends on plan tier: managed Code Review service (Team/Enterprise) where available, local /code-review (free, fresh-context background subagent) otherwise — degrading gracefully since plan-tier availability for this account is unconfirmed. Both surfaces are advisory-only by design — check-run always neutral, never auto-blocking — matching the same default-deny-on-unapproved-merge posture as Part 3; merge authority stays human. Either surface satisfies TS-17 by construction for logic that reaches this stage.

Part 5 — Plan template structure and plan-stage second-agent review

Plan template. Anthropic's Plan Mode prescribes no fixed schema — a template is this project's own addition. Decision: a tiered template — a fixed floor on every plan (Anthropic's own minimum-viable recipe: affected files/interfaces, an explicit out-of-scope boundary, an end-to-end verification step), plus conditional sections that only apply when the change is multi-file, touches unfamiliar code, or has an uncertain approach (consistent with Part 7's bypass criterion). The literal field-by-field template belongs in the step-4 document. Named gap: no quantified plan-detail-vs-rework-cost tradeoff exists for AI agents — the tiered design follows Anthropic's qualitative overhead-scaling guidance, not a measured curve.

Plan-stage second-agent review. Decision: extend TS-17's writer/reviewer pattern to the planning stage, scoped identically — a fresh-context pass on the plan itself, required only when it touches TS-17's named high-risk logic. The self-critique-collapse-vs-external-verification-gain literature argues for this fresh-context design, not against plan review generally, but direct support is narrower than TS-17's own coding-domain evidence: one Anthropic case study (a three-role harness negotiating a "sprint contract" before code is written) plus one non-coding-domain paper. Scoping to high-risk logic only, rather than every plan, is itself evidenced — the same Anthropic harness cost roughly 20x a solo run. Named gap: no coding-domain, controlled study of plan-stage review exists yet.

Part 6 — Code documentation strategy for agent discovery

Decision: keep the discovery strategy Anthropic's tooling already documents, add one periodic-hygiene check, and don't add infrastructure the evidence doesn't support at this scale. Root CLAUDE.md stays lean with per-slice files (point 1, reconfirmed, per Anthropic's include/exclude table and "drifts into noise" guidance); LSP over grep for symbol lookup (point 1, reconfirmed) — with actual LSP usage checked periodically rather than assumed, since at least one practitioner survey found these integrations go under-used despite being installed. No standalone ARCHITECTURE.md by default — vertical-slice's own directory structure already is the map. No embedding/semantic-search infrastructure — disproportionate at this scale, same logic as Principle 4's Agent Teams rejection; Anthropic's only stated position is "expose an existing index as an MCP tool if you have one," not "build one." A periodic doc-freshness check (a Skill, matching TS-5's pattern) is added because agent-facing config files measurably rot — roughly a quarter of a large sampled repo set had at least one stale code-element reference.

Part 7 — Bypass path for trivial changes

Decision: adopt Anthropic's own qualitative Plan-Mode-skip heuristic, scoped to Plan Mode only — not a diff-line-count threshold, and not extended to hooks or review. A change is eligible for direct execution when it touches one file, changes no logic/control-flow, and is describable in one sentence (Anthropic's own examples: typo, log line, variable rename); anything multi-file, unfamiliar, or uncertain still plans first. Explicitly not line-count-based — the nearest empirical evidence found raw size an inconsistent risk predictor, with file-scope and change-purpose more informative. The bypass applies to Plan Mode only: hooks run with zero exceptions per Anthropic's own framing, and TS-17's high-risk-logic trigger (plus its Part 5 extension) is unaffected by triviality — a one-line change to fractional-ordering still gets reviewed. Named risk, stated abstractly: size and risk are different axes — well-documented industry incidents show superficially small changes causing severe outcomes precisely because they looked small enough to wave through (detail in agentic-workflow-research.md Part E). This is why the bypass is scoped to the cheapest, most reversible stage to skip, and no further. Named gap: no validated, evidence-based trivial-change threshold exists in the literature for this purpose — this project adopts Anthropic's qualitative criterion as its own definition, not an industry standard.

Part 8 — Detection mechanism for the triggers in Parts 3/5/7 and TS-17

The decisions above name when the heavy path applies but not what evaluates that. Decision: two-tier detection — mechanical check first, cheap classifier second, never the primary implementing agent's own unprompted self-judgment as the sole gate.

Mechanical/deterministic check wherever the criterion allows it — TS-17's risk areas map onto real module boundaries in a vertical-slice architecture, checkable via file-path and import-boundary matching. Real precedent: a peer-reviewed 2026 study predicting high-maintenance PRs from file type and patch size alone (no LLM) reached AUC 0.96.
A cheap classifier call only where mechanical detection can't resolve it. Real precedent: Anthropic's own auto-mode permission system already gates escalation this way, and Anthropic has stated its internal SDLC "tiers codebase by risk and automates reviews based on that level" (mechanism undocumented). A vendor pattern converges independently on the same two-tier shape.
Never the primary agent's own unstructured self-judgment as the sole gate — extending this ADR's self-critique-vs-external-verification logic to the escalation decision itself. A general (non-code) study on LLM escalation calibration found self-estimated accuracy running well above actual accuracy — models are not reliably calibrated judges of whether their own work needs a second look.

Named gap: no research directly validates a code-specific triage classifier against ground truth for this application — this stitches together real but not directly-on-point precedents.

Consequences and limitations
Part 3 (deployment) is the weakest-evidenced part of this ADR — should get extra scrutiny and probably a smaller/cheaper first version before trusting it with anything real.
This ADR assumes points 1-3's decisions hold — vertical-slice's low cross-slice coupling is what makes Part 2's "cross-session collision is rare" claim credible; revisit Part 2 if a future architecture re-scoring changes that.
Two real decisions are surfaced but deliberately left to Lou, not resolved here: whether to allowlist any operations via autoMode.environment (Part 3), and whether the managed Code Review service is actually available on this account's plan tier (Part 4, degrades gracefully either way).
The 260-config Nature paper has a minor unresolved discrepancy (an earlier companion blog post states 180 configurations) — doesn't change the figures used here, flagged for honesty.
Every other named gap (Parts 5-8's evidence limits, the bypass criterion's non-standard status, LSP-usage verification, CloudWatch noise handling) is stated inline in its own Part above rather than repeated here — deliberately, to avoid this section duplicating what's already said once.