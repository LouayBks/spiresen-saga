# Saga

**Saga** is a portfolio web app — and, at the same time, a public case study in how to plan AI-assisted software development so it costs less before a single line of code runs.

This README explains both halves: what the app is, and why the way it's being built is the actual point of the repository.

---

## 1. Context

This repository is being built end-to-end with [Claude Code](https://claude.com/claude-code) as the primary development tool. Rather than jumping straight to implementation, every foundational decision — how the code is organized, what "clean code" means for this stack, how testing is structured, how the AI agent workflow itself is designed — is made *deliberately*, in writing, before development starts, and validated by a human reviewer at each step.

That process is documented as a series of **Architecture Decision Records (ADRs)**, each one comparing real alternatives against explicit, evidence-backed criteria. This repo is both the app that results from that process and the record of the process itself.

## 2. Objective: pre-dev FinOps for AI-assisted development

[FinOps for AI](https://www.finops.org/framework/domains/) — the FinOps Foundation's current framework — focuses on managing AI cost *once systems are running*: usage tracking, unit economics, inference cost allocation, optimization of live workloads. The Foundation has itself flagged a gap here: there is not yet an equivalent standard for reducing cost **before** operations even begin — during the planning and build phase of AI-assisted development itself.

This project is a working implementation of that missing piece. The idea is simple: rework, wasted tokens, technical debt, and low-quality AI-generated code are all costs, and most of them are cheaper to avoid at design time than to fix at run time. So before writing application code, this project runs a structured, criteria-driven decision process for the things that most determine whether AI-generated code stays cheap and correct as it accumulates:

- **How the codebase is organized** — does the AI agent's context cost stay low as the project grows?
- **What clean-code discipline is enforced, and how** — mechanically (linters, type-checkers) vs. by prose instruction, and what that trade-off costs in tokens and correctness.
- **What testing strategy is used, and how the AI verifies its own work** — grounded execution vs. self-review, and when the extra cost of a second reviewing pass is actually worth it.
- **How the agentic workflow itself is structured** — single-agent vs. multi-agent, when to parallelize, when review needs a fresh context, and how that translates into the actual tool configuration (plugins, GitHub integration, cloud credentials, permission scopes) Claude Code runs under.

Each of these decisions is scored against explicit criteria, backed by cited evidence (research papers, official framework documentation, vendor guidance) rather than intuition alone, and stopped for human review before being finalized. The goal is a repeatable *pre-run* standard — a way to cut AI-development cost and risk before operations, extending what FinOps for AI currently leaves at the run-time stage.

## 3. The app itself

Setting the methodology aside, **Saga** is a real product: a place to store and present articles, papers, presentations, and designs, organized as a drag-and-drop canvas of nested "boxes" you can rearrange and fill.

- **Multi-tenant** — each user gets one or more *Sagas*, their own named collection. Sagas can later be shared/collaborative.
- **Box-canvas core** — boxes can contain other boxes, or content items (articles, presentations, designs), arranged via drag-and-drop.
- **Part of the Spiresen umbrella** (`spiresen.com`) — the first product to live on a subdomain of that root domain, built so the same infrastructure patterns can be reused by future sibling projects.

**Stack:**

| Layer | Choice |
|---|---|
| Frontend | Angular (standalone components, Angular CDK drag-drop) |
| Backend | FastAPI on AWS Lambda (via Mangum), behind API Gateway |
| Data | DynamoDB, single-table design |
| Files/media | S3 |
| Delivery | CloudFront + Route 53 + ACM |
| Auth | Cognito with Google SSO |
| IaC | Terraform, modularized (`dns`, `static-site`, `api`) |
| CI/CD | GitHub Actions, via the Claude Code GitHub Action |

Full reasoning behind the stack and data model lives in [`draft/ARCHITECTURE.md`](draft/ARCHITECTURE.md).

## 4. How the strategy is created

The planning process runs as a sequence of **points**, each one producing an ADR and, once accepted, a concrete rules document. Every point follows the same shape:

1. **Research** the space (real alternatives, existing evidence, stack-specific findings) into a research document.
2. **Draft an ADR** that scores each option against a set of lettered, sourced decision criteria — not vibes, a table.
3. **Stop for human review.** The ADR is not final until explicitly accepted.
4. **Produce the final rules document**, translating the accepted decision into concrete, per-rule guidance — including *how* each rule should be enforced (a blocking CI hook, a lint config, a short prose rule, a review skill, or how an agent's task gets framed).

Each point also explicitly carries forward anything it couldn't fully resolve, so later points close earlier gaps instead of re-litigating them:

| Point | Decision | Status |
|---|---|---|
| 1 — Codebase architecture | Vertical-slice / feature-based organization, scored against 10 criteria vs. layered, DDD, and hexagonal alternatives | Accepted — [ADR-001](ADR/ADR-001-software_architecture.md) |
| 2 — Clean-code rules | Hybrid enforcement (mechanical core + a short, curated prose residual), resolved into 33 rules | Accepted — [ADR-002](ADR/ADR-002-clean_code.md) / [rules](.CLAUDE/clean_coderules.md) |
| 3 — Testing strategy | Testing Trophy shape + 6 agentic verification policies, resolved into 19 rules | Accepted — [ADR-003](ADR/ADR-003-testing-strategy.md) / [strategy](.CLAUDE/testing_strategy.md) |
| 4 — Agent/workflow definition | Single-agent-by-default topology (git-worktree parallelism for independent work, subagent delegation reserved for writer/reviewer roles); concrete dev, deployment, and review workflows; plan template, documentation strategy, trivial-change bypass, and a two-tier detection mechanism gating all of it — resolved into 20 rules | Accepted — [ADR-004](ADR/ADR-004-agentic_workflow.md) / [processes](.CLAUDE/agentic_workflow_processes.md) |

A fifth document, [`claude-code-setup.md`](.CLAUDE/claude_code_setup.md), isn't an ADR — it's where point 4's decisions become literal tool configuration: which plugins and MCP servers to install, how the GitHub App/Action is scoped, how AWS credentials and IAM roles are provisioned for Claude (including the two-role split — a scoped deploy role vs. a read-only log-scan role — that Part 3/8 of ADR-004 calls for), and the `.claude/settings.json`/hooks wiring itself. It's the step between "the workflow is decided" and "Claude Code can actually be pointed at this repo."

A full narrative of this process is kept in [`DOCUMENTATION/strategy_creation_timeline.md`](DOCUMENTATION/strategy_creation_timeline.md), including the two places the process caught its own gaps: after Point 2 was accepted, an audit for silently-dropped research findings surfaced three missing rules, added before the rules document was finalized; and Point 4's ADR went through a review-and-revise cycle — trimmed for duplication, and extended to add an explicit detection mechanism and a log-based (not just synthetic-smoke-test) deployment health check — before acceptance. Neither correction was silent; both are part of the record. The process is meant to be checked, not just followed.

## 5. Documentation index

**Decisions (ADRs)** — the *why*, with scored alternatives and cited evidence:
- [ADR-001 — Codebase architecture](ADR/ADR-001-software_architecture.md)
- [ADR-002 — Clean-code strategy](ADR/ADR-002-clean_code.md)
- [ADR-003 — Testing strategy](ADR/ADR-003-testing-strategy.md)
- [ADR-004 — Agentic workflow and multi-agent architecture](ADR/ADR-004-agentic_workflow.md)

**Final rules** — the *what*, concrete and enforceable:
- [Clean-code rules (33 rules, CC-1 to CC-33)](.CLAUDE/clean_coderules.md)
- [Testing strategy (19 rules, TS-1 to TS-19)](.CLAUDE/testing_strategy.md)
- [Agentic workflow processes (20 rules, AW-1 to AW-20)](.CLAUDE/agentic_workflow_processes.md)

**Setup reference** — the *how*, concrete tool and credential configuration:
- [Claude Code setup](.CLAUDE/claude_code_setup.md) — plugins/MCP servers, GitHub App and Action scope, AWS credential and IAM setup, `.claude/settings.json` and hooks

**Supporting research and process docs:**
- [Clean-code research](DOCUMENTATION/clean_code_research.md) — the evidence base behind ADR-002
- [Testing strategy research](DOCUMENTATION/testing_strategy_research.md) — the evidence base behind ADR-003
- [Agentic workflow research](DOCUMENTATION/agentic_workflow_research.md) — the evidence base behind ADR-004, including verification of every cited claim against primary sources
- [Strategy creation timeline](DOCUMENTATION/strategy_creation_timeline.md) — the full narrative of how each point was researched, decided, and validated

**Product planning (pre-code scaffold):**
- [`draft/ARCHITECTURE.md`](draft/ARCHITECTURE.md) — stack, data model, and infra decisions for the app itself
- [`draft/HANDOFF.md`](draft/HANDOFF.md) — implementation task list for the current multi-tenancy (Saga) build-out

---

*This project is built and documented with [Claude Code](https://claude.com/claude-code).*