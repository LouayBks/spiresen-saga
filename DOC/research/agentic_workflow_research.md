# Point 4 research notes — agentic workflow
 
Backing research for `ADR-0004: Agentic workflow and multi-agent architecture`. Five parts: (A) a catalog of available workflow-building-block elements, grouped by nature; (B) real architectures/case studies for Claude-based coding agents; (C) plan-template structure and plan-stage second-agent review; (D) code documentation for agent discovery; (E) bypass/fast-path patterns for trivial changes. Parts C-E were added after Lou's review of the first ADR-0004 draft asked for these four points to be researched with the same rigor as A/B. Evidence tiered throughout — every claim is tagged verified/partially-verified/no-evidence-found against a primary source fetched live, not passed through from training-data recollection.
 
---
 
## Part A — Workflow elements catalog
 
All Claude Code-specific items below were checked live against `code.claude.com/docs` on 2026-09-08 rather than assumed — this product changes fast.
 
### 1. Orchestration/topology patterns
 
| Pattern | What it is | Suits | Overhead |
|---|---|---|---|
| Single-agent-does-everything | One agent, one context, sequential tool calls | Most ordinary coding work, tight shared context | None — but no parallelism or isolation |
| Sequential/pipeline | Agents run one after another, state handed off explicitly | Clear-staged work (explore→plan→implement→verify) | Low; latency additive, errors compound downstream |
| Parallel/fan-out | Multiple agents run concurrently on independent slices, merged after | Independent, decomposable work | Token cost scales with agent count; Anthropic's own multi-agent system uses ~15x the tokens of a single chat (verified, see Part B) |
| Orchestrator-worker (hierarchical) | A lead agent delegates to isolated-context workers; only results (not process) return | Parallelizable, context-exceeding, tool-heavy tasks — **Anthropic's own primary source names coding as a weaker fit for this than research**, due to high interdependency between coding subtasks | Moderate — one coordinator + N worker contexts; synthesizing many detailed results back can itself cost significant context |
| Peer-to-peer team | A lead spawns peers that message each other directly, share a claimable task list | Debate/adversarial verification, cross-layer feature work owned by different peers | High — Claude Code's own docs: ~7x more tokens than a single session when teammates run in plan mode. Experimental feature. |
| DAG/scripted workflow | An executable script (Claude-authored) orchestrates fan-out/fan-in with explicit dependency resolution; results live in script variables, not the main context | Work that outgrows ad hoc subagent delegation — codebase-wide audits, large migrations (hundreds of files) | Explicit runtime caps (16 concurrent agents, 1,000/run); flags any run over 25 agents or 1.5M projected tokens as "Large workflow" |
 
### 2. Claude Code native mechanisms
 
- **Subagents (Agent/Task tool)** — isolated-context workers (`.claude/agents/`), own tools/permissions/model. Parallel use recommended for *independent* investigations; sequential chaining for dependent work. Default cap: 20 concurrent. Cost note: synthesizing many detailed subagent returns still costs main-context tokens.
- **Agent Teams** — experimental, peer-to-peer, shared claimable task list, ~7x token cost vs. single session in plan mode.
- **Dynamic Workflows** — scripted orchestration (`agent()`, `pipeline()`, `parallel()`, `phase()`), for work at a scale ad hoc delegation doesn't fit (dozens–hundreds of agents).
- **Hooks** — deterministic pre/post-tool-use automation on 30+ lifecycle events (`PreToolUse`, `PostToolUse`, `Stop`, `WorktreeCreate`, etc.). Only `exit 2` reliably blocks; async hooks can't enforce policy.
- **Skills / Plugins** — packaged, on-demand-loaded instruction sets (skills) and distributable bundles of skills+subagents+hooks+MCP servers (plugins). Skill content stays resident in context once invoked.
- **MCP server integration** — external tool/data access (issue trackers, DBs, Slack) over a standard protocol; tool schemas deferred/searched by default to bound idle context cost.
- **Plan mode** — explore-then-propose before editing is allowed; explicitly recommended by Anthropic as a top cost-reduction lever. Caveat: agent-team teammates in plan mode get their plans **auto-approved by the lead**, no human in the loop by default.
- **Git worktrees** — `--worktree`/`-w`, first-class documented pattern for parallel isolated sessions on the same repo; Claude Code itself blocks cross-worktree edits. Setup cost: each worktree is a fresh checkout (deps/env reinit). A `/batch` pattern (5-30 subagents, each its own worktree, each its own PR) exists for large mechanical migrations.
- **Background/scheduled tasks** — three tiers by durability: `/loop` (session-scoped, dies with the session), Desktop scheduled tasks (persistent locally), cloud Routines (Anthropic-managed, survive independent of any machine, min. 1hr interval, **no permission prompts at all** — fully autonomous by design, a real governance point).
- **Session/context management** — auto-compaction, `/compact [instructions]`, `/clear`, `/rewind` (checkpointing, up to 100 recent snapshots). Caveat: compaction can silently drop a stated safety boundary if it summarizes away the message that stated it; `/rewind` does not track Bash-command file changes or subagent edits.
- **Permission modes** — six, on a convenience↔oversight spectrum: default/manual, acceptEdits, plan, **auto** (a Sonnet-5-based classifier checks each action against ~30 default-blocked categories — production deploys, IaC destroy, merging without human approval, secret exfiltration, etc. — now the **default starting mode on Pro/Max/Team plans**), dontAsk (CI-oriented allowlist-only), bypassPermissions (isolated-container only, no checks). Auto mode is explicitly not a safety guarantee per Anthropic's own docs.
- **Claude Code GitHub Action** (`anthropics/claude-code-action`) — confirmed real. Interactive mode (`@claude` mentions push commits back) and automation mode (fixed prompt on any GitHub event, incl. `schedule`).
### 3. Context and memory management
 
CLAUDE.md hierarchy (already established, points 1-2). Scratchpad/temp files for intermediate artifacts outside the token budget. State-handoff documents between sequential runs (the mechanism behind Dynamic Workflows' script variables). Compaction strategies (see above). `ReportFindings` — a typed, persistent findings list (file/summary/severity, tracked fixed/skipped status) used by `/code-review`-style skills.
 
### 4. Control, safety, human-in-the-loop
 
Approval gates (permission-mode prompts + `permissions.ask` overrides + a fixed always-block list no mode bypasses). Sandboxing (Bash sandbox, independent of and composable with permission mode). Dry-run/plan-then-execute (plan mode; `/code-review` vs. `/code-review --fix`). Rollback (`/rewind` — explicitly "not a replacement for version control," misses Bash/subagent/concurrent-session edits). Audit logging (native OpenTelemetry export, content-level logging opt-in, off by default).
 
### 5. Process-integration elements
 
Issue trackers via the GitHub Action or MCP. PR workflows (interactive `@claude`, worktree-per-PR). CI/CD integration (`schedule`-triggered automation, `--max-turns`/timeout bounding). Deployment gates (auto-mode classifier default-denies production deploys, IaC destroy, and unapproved merges — configurable per-org via `autoMode.environment`, not opt-in by default). Post-deploy verification — **no single named feature; a composed pattern** (Hooks + `/loop`/Routines). Code review — three distinct surfaces: managed **Code Review** service (Team/Enterprise only, research preview, ~$15-25/review, ~20 min, always-neutral check-run — never blocks merge), local `/code-review` (free, any plan, runs as a background subagent — fresh-context by construction), and the GitHub Action as the delivery surface for either.
 
---
 
## Part B — Real architectures and verified claims
 
### 1. Anthropic's own multi-agent research system — two claims VERIFIED against the primary source
 
Source: [anthropic.com/engineering/multi-agent-research-system](https://www.anthropic.com/engineering/multi-agent-research-system) (June 2025). This project's earlier research (`finops-agentic-cost-research.md`) had flagged a "15x tokens / 80% variance" figure as attributed-but-unverified. Now confirmed directly, quoted verbatim:
 
> "agents typically use about 4× more tokens than chat interactions, and multi-agent systems use about 15× more tokens than chats."
> Token usage by itself explains **80%** of BrowseComp performance variance (tool-call count and model choice explain the remaining 15 points).
 
**New, load-bearing finding for this project specifically:** Anthropic's own post states *"most coding tasks involve fewer truly parallelizable tasks than research"* and names high-interdependency domains — **coding among them** — as a poor fit for the orchestrator-worker topology their own research system uses. This directly informs Part 1 of the ADR: the topology Anthropic itself built and is famous for is explicitly not what they'd recommend for most coding work.
 
### 2. Claude Code subagents, worktrees, writer/reviewer pattern
 
- Subagent guidance ([docs](https://code.claude.com/docs/en/sub-agents)): parallel subagents for *independent* investigations, sequential chaining for dependent work — a direct, first-party statement of the same principle Anthropic's research-system post makes.
- Git worktrees ([docs](https://code.claude.com/docs/en/worktrees)): confirmed first-class, officially tooled (not a community trick) — `--worktree`, automatic desktop-app worktree creation, enforced cross-worktree isolation. Real cost: each worktree is a fresh checkout requiring its own dependency/env setup.
- Writer/reviewer separation ([best-practices docs](https://code.claude.com/docs/en/best-practices), verified verbatim): *"A fresh context improves code review since Claude won't be biased toward code it just wrote... use a Writer/Reviewer pattern... have one Claude write tests, then another write code to pass them."* This is the primary source behind ADR-0003's TS-17. `/code-review` satisfies it by construction (runs as an isolated background subagent).
### 3. DeepMind/MIT capability-saturation study — VERIFIED, now a real citable paper
 
Kim, Liu et al., **"Capable language models can outgrow the benefits of collaboration,"** *Nature Machine Intelligence*, Vol. 8, pp. 1157-1172 (July 2026). DOI: [10.1038/s42256-026-01268-y](https://www.nature.com/articles/s42256-026-01268-y).
 
- 260 configurations across six benchmarks, five architectures, three LLM families — confirmed.
- The ~45% single-agent-baseline-accuracy threshold and 94% predictive-validation-accuracy figures both confirmed directly from the paper (94% specifically on SWE-bench Verified and Terminal-Bench validation configurations).
- New finding: the same predictive framework "selects the best architecture in 87% of held-out configurations."
- **Minor unresolved discrepancy, flagged honestly:** the team's own earlier Google Research blog post on a precursor preprint states "180 agent configurations," not 260, and doesn't itself restate the 94%/45% figures. Treat the published Nature paper's 260/94%/45% as authoritative over the earlier blog post's 180.
- No independent replication yet found (too recent).
**Implication for this project:** on typical small-CRUD-slice tasks, a capable model (Claude Sonnet 5) likely already sits above the ~45% single-agent-baseline-accuracy threshold — meaning adding more agents to a *single* task is more likely to show diminishing or negative returns than a real gain, reinforcing single-agent-by-default for one coherent unit of work.
 
### 4. Post-deployment operational verification — genuine literature gap, confirmed
 
Checked directly: Anthropic's own verification-loops post ([claude.com/blog/building-verification-loops-in-claude-code-with-skills](https://claude.com/blog/building-verification-loops-in-claude-code-with-skills)) covers pre-deploy verification only (linters, tests, PR-time review) — no post-deploy smoke-testing content. Anthropic's own SDLC-security post ([claude.com/blog/how-anthropic-secures-its-ai-native-software-development-lifecycle](https://claude.com/blog/how-anthropic-secures-its-ai-native-software-development-lifecycle)) names a "Monitor" stage but describes it as log review/incident response, not agent-driven smoke testing. No credible third-party engineering blog documenting a real production deployment of this pattern was found either. **Conclusion: build-it-yourself territory, not a known-good template** — the ADR should say so plainly rather than implying an established pattern exists.
 
### 5. AI code review in practice
 
Confirmed via official docs: the managed Code Review service and local `/code-review` are both **advisory-only by design** — check-run conclusion is always neutral, human retains merge authority. This matches the market baseline (CodeRabbit, GitHub Copilot code review, Graphite Diamond — none of them auto-block merges either). The managed service is Team/Enterprise-plan-only (research preview) — **may not be available depending on account tier; the design should degrade gracefully to the GitHub Action + local `/code-review` if so.**
 
### 6. Small-scale case study — one found, flagged as a contrast, not a model
 
[Developers Digest case study](https://www.developersdigest.tech/blog/case-study-building-dd-with-ai): solo developer, up to 12 parallel subagents on non-overlapping files, atomic-commit-and-auto-deploy, **no documented test or review stage**. Real numbers (155+ features, 100+ commits) but a meaningfully less rigorous pipeline than this project has already committed to (ADR-0002's hooks, ADR-0003's Testing Trophy + verification policy). Cited as a data point on parallel-subagent-per-file feasibility, not as a template to follow — this project's own testing/review decisions already supersede it.
 
**No case study found at this project's actual scale (small serverless personal app) with a full dev→test→review→deploy pipeline and documented topology reasoning.** Anthropic's own internal-usage post is enterprise-scale and not a fair comparison; not stretched to fit.
 
### Verification summary
 
| Claim | Status |
|---|---|
| 15x token multiplier, multi-agent vs. single chat | Confirmed, exact quote |
| Token usage explains ~80% of performance variance | Confirmed, exact quote |
| Coding is a weaker fit for orchestrator-worker than research | Confirmed — new finding, directly load-bearing |
| 260-config study, 94% predictive accuracy, ~45% threshold | Confirmed, real peer-reviewed paper; minor 180-vs-260 discrepancy against an earlier blog noted |
| "Fresh context improves review" / writer-then-tester quote | Confirmed verbatim, primary source for ADR-0003's TS-17 |
| Git worktrees + parallel sessions is a documented pattern | Confirmed, first-class tooling |
| AI-driven post-deploy operational verification | Not found — genuine gap |
| Small-project-scale full-pipeline case study | Not found; nearest analog lacks a test/review stage |
 
---
 
## Part C — Plan template structure and plan-stage second-agent review
 
### C1. What a plan should contain
 
**Verified, primary source — Anthropic prescribes no fixed schema for Plan Mode's output.** ([code.claude.com/docs/en/permission-modes](https://code.claude.com/docs/en/permission-modes)) Plan Mode is freeform: Claude explores then writes a plan, a human can hand-edit it (`Ctrl+G`), then approves/keeps-planning. **This is load-bearing**: a uniform template is something this project would add on top of the tool, not something already enforced by it.
 
**Verified, primary source — Anthropic's own minimum-viable recipe for a good spec** ([code.claude.com/docs/en/best-practices](https://code.claude.com/docs/en/best-practices)), verbatim: *"The most useful specs are self-contained: they name the files and interfaces involved, state what is out of scope, and end with an end-to-end verification step that proves the feature works."* Three concrete, sourced fields: affected files/interfaces, an explicit out-of-scope boundary, an acceptance/verification step.
 
**Verified, primary source — plan detail should scale with task uncertainty, not be applied uniformly at maximum depth.** Same doc, verbatim: *"Plan mode is useful, but also adds overhead. For tasks where the scope is clear and the fix is small... ask Claude to do it directly. Planning is most useful when you're uncertain about the approach, when the change modifies multiple files, or when you're unfamiliar with the code being modified. If you could describe the diff in one sentence, skip the plan."* This argues for a **tiered template** (a fixed floor, other sections conditional on task uncertainty) rather than one fixed-length template forced onto every task.
 
**Verified, third-party — two independent real-world templates corroborate and extend the above:**
- [GitHub `spec-kit`'s `plan-template.md`](https://github.com/github/spec-kit/blob/main/templates/plan-template.md): Summary, Technical Context (with explicit `NEEDS CLARIFICATION` markers for unresolved fields), a **Constitution Check** gate (validates the plan against the project's own house rules before proceeding — directly analogous to checking a plan against this project's ADRs), Project Structure, and a **Complexity Tracking** table (Violation / Why Needed / Simpler Alternative Rejected Because).
- [Addy Osmani's analysis of 2,500+ real agent config files](https://addyosmani.com/blog/good-spec/): Objective, Tech Stack, Success Criteria, Constraints/edge cases, and a three-tier **Boundaries** system (✅ Always do / ⚠️ Ask first / 🚫 Never do) — a stronger, more actionable version of a plain "risks" section.
**Not verified / no evidence found — a quantified plan-detail-vs-rework-cost tradeoff.** No controlled study was found (for AI coding agents specifically) measuring plan length/detail against downstream rework tokens or task success. The oft-cited "cost of a requirements-stage defect vs. a post-release defect" curve (Boehm) was checked and is **explicitly not being used here** — it's 1981-era data, inconsistently cited, and a specific citable multiplier could not be confirmed from the original source. Treat the cost/benefit argument as qualitative (Anthropic's own overhead-scaling statement above), not quantified.
 
### C2. Should a second agent review/push back on the plan before execution?
 
**Verified, and an important distinction to hold onto: Anthropic's documented "adversarial review" is a POST-execution diff review, not a pre-execution plan review.** ([best-practices docs](https://code.claude.com/docs/en/best-practices)) *"A reviewer running in a fresh subagent context sees only the diff and the criteria you give it... To check the diff against your plan instead, write the review prompt yourself."* This is ADR-0003's TS-17 pattern, already decided — it checks the *result* against the plan, after code exists. It does not by itself answer whether the *plan itself* should get a pre-execution second look.
 
**Verified, directly on-point — Anthropic ran a three-role harness (planner → generator → evaluator) where the evaluator negotiates a "sprint contract" with the generator *before any code is written*.** ([anthropic.com/engineering/harness-design-long-running-apps](https://www.anthropic.com/engineering/harness-design-long-running-apps), Mar 2026) Verbatim: *"Separating the agent doing the work from the agent judging it proves to be a strong lever"*; *"Before each sprint, the generator and evaluator negotiated a sprint contract: agreeing on what 'done' looked like for that chunk of work before any code was written."* **Caveat: this is a single experimental case study Anthropic built for its own long-running-app-generation testing — not a documented Claude Code feature or a general best-practice recommendation. Don't overstate it as "Anthropic recommends this for all coding work."**
 
**Verified — cost of that extra pass, from the same case study.** Solo single-agent run: **$9** / ~20 minutes. Full three-agent (planner/generator/evaluator) harness: **$200** / ~6 hours — roughly a **20x** multiplier, attributed to sprint-contract negotiation cycles, evaluator-driven functional testing, and QA/regeneration rounds. A real, quotable FinOps number for the cost side of this specific tradeoff.
 
**Verified, analogous (non-coding) domain — a fresh-context "Judge" agent that critiques a plan pre-execution substantially outperforms both no-check and a rule-based check.** Hariharan, Dongre, Hakkani-Tür, Tur, ["Plan Verification for LLM-Based Embodied Task Completion Agents"](https://arxiv.org/abs/2509.02761) (arXiv:2509.02761, Sept 2025). Domain: embodied/household task planning (TEACh), **not software engineering** — cite as analogy, not direct evidence. Zero-shot Judge recall/precision ranged 68-93%/85-100% depending on model, vs. a rule-based baseline at 22% recall/71% precision; with iterative Judge↔Planner revision the best configuration reached 89%/99%, converging within 3 iterations 96.5% of the time.
 
**Verified, and the single most important nuance for this decision: the literature's negative finding is about SELF-critique, not external second-agent critique — meaning it argues *for* a fresh-context second agent, not against a plan-review step generally.**
- Valmeekam, Marquez, Kambhampati, ["Can Large Language Models Really Improve by Self-critiquing Their Own Plans?"](https://arxiv.org/abs/2310.08118) (arXiv:2310.08118): "self-critiquing appears to diminish plan generation performance, especially when compared to systems with external, sound verifiers."
- Stechly, Valmeekam, Kambhampati, ["On the Self-Verification Limitations of Large Language Models on Reasoning and Planning Tasks"](https://arxiv.org/abs/2402.08115) (arXiv:2402.08115): "We observe significant performance collapse with self-critique and significant performance gains with sound external verification." Also: "merely re-prompting with a sound verifier maintains most of the benefits of more involved setups."
This directly parallels this project's already-adopted TS-17 rationale (a fresh context/different role, not the same model checking its own work) — the evidence base for extending that same shape to the *planning* stage is real, just narrower than for post-execution code review (one Anthropic case study + a non-coding-domain paper, vs. TS-17's 78%-mutant-kill coding-domain finding).
 
**No evidence found:** any Anthropic guidance recommending a second agent review a plan for project-rule/intended-behavior compliance as a named, general practice; any study showing a *fresh-context* (non-self) plan critique has negative or wasteful returns. Both gaps stated plainly rather than inferred either direction.
 
---
 
## Part D — Code documentation for agent discovery
 
### D1. Anthropic's own documented position
 
**Verified, primary source, confirms this project's two already-cited quotes plus new detail** ([code.claude.com/docs/en/memory](https://code.claude.com/docs/en/memory), [/large-codebases](https://code.claude.com/docs/en/large-codebases), [/best-practices](https://code.claude.com/docs/en/best-practices)):
- CLAUDE.md loads additively root-down; per-subdirectory files load on demand. **Target under 200 lines per file** — "longer files consume more context and reduce adherence." `/doctor` can propose trims, cutting content Claude can derive from the codebase itself (directory layouts, dependency lists, architecture overviews) while keeping pitfalls/rationale/non-default conventions.
- Explicit include/exclude table: include bash commands Claude can't guess, non-default code style, testing instructions, repo etiquette, project-specific architectural decisions, environment quirks, non-obvious gotchas. Exclude anything derivable by reading code, standard conventions, detailed API docs (link instead), frequently-changing info, tutorials, file-by-file descriptions, "self-evident practices like 'write clean code.'"
- Verbatim, already-cited and reconfirmed: *"The root file should be pointers and critical gotchas only; everything else drifts into noise."* And on grep vs. LSP: *"Grep for a common function name in a large codebase returns thousands of matches... LSP returns only the references that point to the same symbol, so the filtering happens before Claude reads anything."*
- **New: an explicit fallback for irregular codebases**, not a default recommendation — *"For organizations where code isn't consolidated in a conventional directory structure, a lightweight markdown file at the repo root listing each top-level folder with a one-line description... gives Claude a table of contents."* This project's vertical-slice structure (ADR-0001) is exactly the conventional, self-describing case this fallback isn't meant for.
- **New: if a RAG/code-search index already exists, expose it as an MCP tool rather than building a native feature** — Anthropic's only stated position touching semantic/embedding search, and it's "plug in your own," not "we recommend embeddings."
**No evidence found:** any Anthropic guidance on docstring/comment density specifically for agent (vs. human) consumption.
 
### D2. Independent research on retrieval mechanisms
 
**Verified — no single discovery mechanism dominates; hybrid beats any one alone.** Qin & Xie, ["Evaluating Repository Context Retrieval for Coding Agents"](https://arxiv.org/html/2607.24882) (arXiv:2607.24882, Jul 2026): compared lexical/BM25, aider-style structure-aware repo maps, and embedding models. Hybrid fusion (RRF) beat every single method (MRR 0.2296→0.2713, Recall@20 0.7331). Fully interactive agents with unrestricted exploration **never touched any gold file on 27-35% of samples** — a concrete ceiling on exploration alone without good pre-filtering. This is a real tension with Anthropic's grep-vs-LSP framing, which doesn't discuss embeddings/hybrid retrieval at all — worth naming as a gap in the "official" guidance, not a reason to add embedding infrastructure to a small personal app.
 
**Verified — Aider's repo map mechanism**, as a concrete alternative worth knowing about even if not adopted: tree-sitter-based extraction of signatures (not full file bodies), ranked by a dependency-graph algorithm over cross-file references, ~1,000-token default budget. ([aider.chat/docs/repomap.html](https://aider.chat/docs/repomap.html))
 
**Verified, practitioner-tier, a real tension worth flagging:** despite LSP integrations being available and Anthropic recommending them, at least one cross-tool practitioner survey reports **actual observed LSP usage is low in practice** across Claude Code, Codex CLI, Cursor, Continue, Aider, OpenCode. ([yage.ai](https://yage.ai/share/why-coding-agents-still-use-grep-en-20260327.html) — practitioner synthesis, not a benchmark.) Implication: installing the LSP code-intelligence plugin (point 1's seed content) is necessary but not sufficient — usage should be spot-checked, not assumed.
 
### D3. Documentation staleness and the cost/benefit of a well-maintained agent config file
 
**Verified — agent-facing config files rot, at a non-trivial but uncertain rate.** Treude & Baltes, ["Context Rot in AI Configuration Files"](https://arxiv.org/html/2606.09090) (arXiv:2606.09090, Jun 2026): applied a staleness detector to 356 repos with CLAUDE.md/AGENTS.md/.cursorrules files. **23.0% of repos (95% CI 18.8-27.2%)** had at least one stale code-element reference; manual inspection of 50 sampled cases found 64% genuinely stale (36% false positive/ambiguous) — the authors themselves call this "a feasibility signal rather than a precise prevalence." Their own fix: treat config files as code, review them during refactors that rename/delete referenced elements.
 
**Verified, strongest direct evidence on the cost/benefit question — a well-formed agent-config file measurably helps efficiency on small, well-scoped tasks.** Lulla, Mohsenimofidi, Galster, Zhang, Baltes, Treude, ["On the Impact of AGENTS.md Files on the Efficiency of AI Coding Agents"](https://arxiv.org/html/2601.20404v2) (arXiv:2601.20404, ICSE 2026 JAWs workshop): paired within-task comparison (same task/repo, AGENTS.md present vs. removed, isolated Docker runs, OpenAI Codex/gpt-5.2-codex), 10 repos, 124 merged PRs (≤100 LOC, ≤5 files). Median runtime **−28.64%**, median output tokens **−16.58%** (both p<0.05, Wilcoxon), with AGENTS.md present. **Authors' own caveats, preserved rather than rounded away:** explicitly correlational not causal, single model family (Codex, not Claude Code), small/narrowly-scoped tasks only, no correctness/quality evaluation, heavy sample filtering (132→10 repos). Cite the numbers, keep the caveats.
 
**Verified — the ARCHITECTURE.md-at-root convention, and its own stated staleness defense.** Kladov ("matklad," rust-analyzer author), ["ARCHITECTURE.md"](https://matklad.github.io/2021/02/06/ARCHITECTURE.md.html) (2021): for 10k-200k LOC projects, locating where to make a change is the real bottleneck, not the edit itself. Verbatim, directly relevant to keeping this cheap: *"only specify things that are unlikely to frequently change. Don't try to keep it synchronized with code."* Name entities so they're findable by symbol search rather than maintaining hyperlinks into code, "because symbol search doesn't require maintenance."
 
**No evidence found:** a controlled study isolating documentation *density* (heavy docstrings/comments vs. minimal) against agent task success rate — distinct from documentation *presence* (D3's AGENTS.md finding), which is the one thing that has been measured. Consistent with this project's earlier `clean-code-research.md` gap on docs-vs-enforced-linting.
 
---
 
## Part E — Bypass/fast-path patterns for trivial changes
 
**Verified, primary source — Anthropic explicitly recommends skipping Plan Mode specifically, using a qualitative (not size-based) heuristic.** Already quoted in Part C1: *"If you could describe the diff in one sentence, skip the plan."* Named examples of skip-eligible changes: typo fix, adding a log line, renaming a variable — all non-logic-changing edits, not simply "few lines." Named triggers for planning: multi-file changes, unfamiliar code, uncertain approach.
 
**Verified — this bypass does not extend to hooks or review; scoping it only to Plan Mode is a defensible reading of the primary source, not an inference.** Hooks: *"Use hooks for actions that must happen every time with zero exceptions... hooks are deterministic and guarantee the action happens"* — no size-based exception documented anywhere in the hooks docs. Review (`/code-review`/adversarial review): recommended generically with no stated size threshold for skipping it.
 
**Verified — the auto-mode permission classifier's risk tiers are NOT organized around change size/triviality at all; they gate on security/infrastructure blast radius** (production deploys, IaC destroy, force-push, secret exfiltration, mass deletion, etc. — [permission-modes](https://code.claude.com/docs/en/permission-modes), [auto-mode-config](https://code.claude.com/docs/en/auto-mode-config)). A one-line typo fix and a 500-line refactor of the same file are treated identically by the classifier unless the path/action itself is on a listed rule. **Don't conflate this classifier with a trivial/substantive gate in the ADR — they answer different questions.**
 
**No evidence found — anywhere — of a validated, evidence-based diff-size or file-count threshold for gating agentic workflow ceremony.** Checked academic and industry sources specifically. The closest adjacent empirical work argues against a naive size threshold:
- Kamei et al., ["A Large-Scale Empirical Study of Just-in-Time Quality Assurance"](https://posl.ait.kyushu-u.ac.jp/~kamei/publications/Kamei_TSE2013.pdf) (IEEE TSE 2013) — verified primary source: change size alone is an inconsistent risk predictor across projects; **diffusion** (files touched, how scattered the change is) and **change purpose** (fix vs. feature) are more informative than raw size. Overall prediction accuracy even combining dimensions was modest (~68% accuracy, 34% precision) — this is real but imperfect evidence, not a validated production-ready classifier.
- Cohen et al. (Cisco/SmartBear peer-review study, ~2006) — **found but not independently verified against the primary PDF** (paywalled); widely and consistently cited secondary figures suggest review pacing (not skipping) is where the evidence points: reviewers should slow down on batches over ~200-400 LOC, not wave small batches through unreviewed.
**Verified, human-engineering precedent — the closest thing to an industry-standard public guide explicitly rejects a general trivial-change review-skip lane**, reserving relaxed process only for a declared emergency carve-out. Google's [engineering practices guide](https://google.github.io/eng-practices/review/reviewer/speed.html), verbatim: *"don't compromise on the code review standards or quality for an imagined improvement in velocity."* Analogy only — human-authored code, may not transfer directly to agent-authored trivial diffs.
 
**Verified, cautionary analogy — three well-documented real incidents where a small/routine-looking change caused a severe outcome, worth naming abstractly as the reason "small" and "safe" aren't the same axis:**
- Apple "goto fail" (CVE-2014-1266) — a single duplicated line disabled TLS certificate validation. [Wheeler's analysis](https://dwheeler.com/essays/apple-goto-fail.html): "Just about any manual review is very likely to have found this."
- AWS S3, Feb 2017 — an operator's intended-small maintenance command removed a much larger server set than planned, causing a major regional outage. [Amazon's own post-incident writeup](https://aws.amazon.com/message/41926/).
- Cloudflare, Jul 2019 — one new WAF rule (a single regex) spiked global CPU to 100%, dropping traffic 82% worldwide for ~30 minutes. [Cloudflare's own retrospective](https://blog.cloudflare.com/cloudflare-outage/): "our testing processes were insufficient in this case."
None involve AI agents — pure analogy — but all three are widely-cited, primary-sourced cases specifically on point for any argument of the shape "small diff ⇒ safe to skip process."