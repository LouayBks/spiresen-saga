# General strategy creation timeline
Point 1 — Codebase architecture (ADR-0001, Accepted): Compared vertical-slice vs. DDD vs. hexagonal vs. layered/N-tier against 10 lettered criteria (A-J). Chose vertical-slice/feature-based organization. Consequence: per-slice CLAUDE.md files. Left open: verifiability seam (criterion E), dependency-direction discipline (criterion D) — both carried forward.

Point 2 — Clean code rules (ADR-0002 + clean-code-rules.md, Accepted): Compared prose-heavy vs. mechanical-only vs. hybrid enforcement against 7 criteria. Chose hybrid — mechanical core (ruff/pyright/ESLint/tsc as hooks) + a short curated CLAUDE.md prose residual. Resolved into 33 final CC-rules, each tagged with implementation surface. Closed point 1's four carried-forward items (hallucination resistance, machine-checkable contracts, volume-collapse resistance, fail-fast vs fail-silent) — though fail-fast rules were flagged as only meaningfully enforced once something tests them, deferred to point 3.

Point 3 — Testing strategy (ADR-0003 + testing-strategy.md, Accepted): Two bundled decisions. Part 1: test-shape/tooling, scored 4 options (Pyramid/Trophy/Ice-cream cone/Minimal) against 7 criteria — chose Testing Trophy (integration-first: FastAPI TestClient + Depends-overrides, Angular TestBed, thin Playwright e2e). Part 2: agentic verification policy — 6 additive policies adopted/rejected against direct evidence (grounded execution as primary signal, no rigid TDD mandate, scoped writer/reviewer separation for high-risk logic, scoped test execution, no coverage gate, flaky-handling requiring re-run evidence). Resolved into 19 TS-rules. Closed ADR-0001's criterion E concretely (via TS-3) and gave ADR-0002's fail-fast rules an enforcement path (TS-1/2/4). Carried forward TS-17 (writer/reviewer role split needs concrete wiring) into point 4.

Point 4 — Agent/workflow definition (ADR-0004, Proposed — currently at your review checkpoint): Research done in two steps — a workflow-elements catalog grouped by nature (agentic-workflow-research.md Part A), then verification of real Claude-agent architectures against primary sources (Part B — Anthropic's multi-agent research post, the DeepMind/MIT capability-saturation study, Claude Code's native mechanisms). ADR-0004 then bundles 4 decisions: topology principles (not a scored grid — evidence-based principles instead, since the right topology depends on use case), dev workflow (single-issue + multi-issue-parallel via git worktrees), deployment workflow (flagged as weakest-evidenced — no existing pattern to draw on), and review workflow (GitHub Action + /code-review or managed Code Review). This is deliberately stopped here per your instruction — awaiting your review/comments before step 4 (the final AI-assisted dev process doc) gets written.


# Incrementational work and steps
Point 1 — Codebase architecture

Research architecture patterns (vertical-slice, DDD, hexagonal, layered) and define decision criteria.
Draft ADR-0001: score each option against 10 lettered criteria, pick vertical-slice.
Validate with you → accepted.
Document the concrete consequence (per-slice CLAUDE.md convention) — no separate "final rules doc" needed since the decision itself was the deliverable.

Point 2 — Clean code rules

Research clean-code enforcement approaches + gather candidate rules (clean-code-research.md).
Draft ADR-0002: score prose-heavy vs. mechanical-only vs. hybrid against 7 criteria, pick hybrid.
Validate with you → accepted; you then asked whether any research rules got silently dropped, so I audited and closed 3 real gaps (CC-31/32/33) before finalizing.
Produce clean-code-rules.md — the final 33-rule list, each tagged with implementation surface.

Point 3 — Testing strategy

Research testing-shape theory + Claude/LLM-specific testing-correctness literature (testing-strategy-research.md).
Draft ADR-0003: score 4 test shapes against 7 criteria (→ Testing Trophy) plus 6 additive agentic-verification policies.
Validate with you → accepted (you said "go").
Produce testing-strategy.md — the final 19-rule list (TS-1 to TS-19), tagged with implementation surface.

Point 4 — Agent/workflow definition (your instructions here had explicit sub-steps, so it's a slightly longer chain)

Research all workflow-building-block elements, grouped by nature → agentic-workflow-research.md Part A.
Research real Claude-agent architectures (sequencing/parallel/orchestrator-worker use cases) → Part B, verified against primary sources.
Draft ADR-0004: define business-logic successions for dev/deployment/review as the ADR(s) → done, stopped here per your instruction — currently awaiting your validation/comments.
(not started) Produce the final AI-assisted dev process documentation, once you approve step 3.