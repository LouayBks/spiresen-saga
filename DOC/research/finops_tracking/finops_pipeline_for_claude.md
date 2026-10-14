# Shift-left FinOps: session-tracking research pipeline (v1)

Next chapter in this project's FinOps trail — follows `finops-agentic-shift-left-brief.md` (thesis), `finops-agentic-cost-research.md` (domain survey), `finops-shift-left-slide-content.md` (external framing), and `spec-template-finops-research.md` (first applied test, on the spec template). That last doc ended by naming the move this doc now makes: turn a tier-3 literature gap ("nobody has measured rework→token cost for coding agents") into this project's own tier-1 evidence, using the token usage log as the instrument. This doc sets up the pipeline to do that on purpose, going into the dev cycle, rather than by after-the-fact narrative reading.

## 1. What we've already tackled, in FinOps terms

Four things are already load-bearing and shouldn't be re-derived:

1. **The gap claim.** Every FinOps-for-AI source checked — the Foundation's 2026 Framework, its AI-specific gap admissions, the five-week-old Tokenomics Foundation's own roadmap — scopes "AI cost" to the AI/agent layer's own spend (inference, orchestration, RAG, guardrails, observability, training) and to production-phase visibility/chargeback. None reach the architecture of the software project an agent is building, and none treat ideation/architecture/discovery as distinct phases with their own guidance. This is a documented gap, not an assumption (`finops-agentic-shift-left-brief.md`, `finops-shift-left-slide-content.md`).
2. **The evidence discipline.** Every claim in this project carries an explicit tier — validated on real systems, prescriptive-but-anecdotal, or aspirational/unvalidated — because the surrounding genre is saturated with unsourced or fabricated numbers. That discipline applies to this doc too: the token log is currently mostly tier-2/tier-3 material (self-reported prose, not structured measurement), and this pipeline exists to move it toward tier-1.
3. **The applied test already run once.** `spec-template-finops-research.md` checked whether spec-first work (EARS/RFC 2119, ADR-006) is justified as a cost lever. Verdict: justified on quality grounds with real numbers (Orchid benchmark: ambiguity drops Pass@1 by an average 7.22 points; structured prompting beats conversational clarification on both quality and token count), but the specific chain — ambiguous spec → rework → more agent tokens, for coding agents — is argued everywhere in 2026 commentary and measured nowhere. That doc's own conclusion (point 4) was to use this project's session log to close that gap ourselves, since nobody else has published it.
4. **Two live self-correction events already logged as informal proof-by-iteration** (the Point 2 rules audit; the Point 4 review-revise cycle) — cited in `finops-shift-left-slide-content.md` point 6 as evidence the process improves through use. This pipeline is the same idea, generalized and made deliberate instead of incidental.

Net position going in: we believe upstream investment (specs, ADRs, architecture decisions) reduces downstream cost, we have quality-side evidence for the first link in that chain, and we have zero measured evidence for the second link specific to this codebase or to coding agents generally. That's the open question this pipeline is built to answer honestly — including the possibility that it doesn't hold, or holds only for some kinds of upstream work.

## 2. Why now

Two things are ending and starting at the same time, and the log's own shape reflects it:

- **Stage-A spec design is closing.** Tickets #31–#35 (naming, box-sizing, content-authoring, alternate-views, accounts/auth) are the last upstream, pre-implementation spec work before #36 ("Data foundation") and real feature builds begin. These two tickets alone are 40% of all logged spend to date ($49.85 of $124.93) concentrated in two long sessions — the single best-documented stretch of "definition-phase" work this project will produce, and it's about to stop being generated.
- **Dev cycles are starting.** Once #36 and beyond begin, we get the other side of the ledger: implementation sessions that either consume these specs cleanly or don't, and — eventually — the first genuinely downstream sessions (a bug against merged code, an environment break, a refactor). Right now the downstream column is empty by definition; every session logged so far is pre-merge.

This is the only point in the project where both sides of the comparison are about to exist simultaneously and freshly. Waiting until dev cycles are further along would mean reconstructing intent from memory instead of tagging it as it happens — the exact problem that made the existing log's classification effortful and approximate in the first place (see §3). Starting the tracking discipline now, at the seam, is what makes the comparison possible at all.

## 3. The data we have, and preliminary conclusions

Source: `DOC/usage/token_usage_log.md`, 20 sessions across 6 tickets, `ccusage session` output plus free-text notes per session. Total logged spend: **$124.93**.

### 3.1 What the numbers say

| Ticket | Nature (by level) | Cost | Share |
|---|---|---|---|
| #5 | project setup | $2.45 | 2% |
| #6 | process-level (rules, agents, templates) + review sessions | $17.27 | 14% |
| #8 | project-level (stack scaffold) | $12.53 | 10% |
| #10–11 | project-level infra build, with rework inside it | $42.83 | 34% |
| #31–34 | feature-upstream (spec definition) | $40.08 | 32% |
| #35 | feature-upstream (spec definition) + unticketed CI fix | $9.77 | 8% |

- **Cost tracks output-token volume almost perfectly** (r ≈ 0.994 across the 20 sessions; $0.016–$0.109 per 1k output tokens). Cache reads are 97.3% of all tokens logged. This means raw session cost is currently a proxy for "how much got written or re-read," not a clean measure of efficiency or of upstream/downstream position — two sessions can cost the same for very different reasons.
- **Spend is heavily concentrated in a small number of long sessions.** The single largest session (`9a676ee3`, the #31–34 spec marathon) is 32% of all spend by itself. The top two sessions are 64%; top three are 73%. Eleven of twenty sessions are under $1 combined ($6.64 total).
- **The concentration is a session-boundary artifact as much as a real signal.** `9a676ee3` alone covers four tickets, two reverted architecture decisions (naming flipped twice; group-nesting reverted from a flattened exception back to real recursion), and three items that grew unplanned out of scope (#43–46). `afd16a72` (#10–11) similarly bundles an ADR amendment, two independent OIDC bugs, and three merged PRs into one row. If either had been split at its natural checkpoints, per-ticket totals wouldn't move, but every other view (per-session, per-day, "how much did this cost") would look different. This is the log's own stated limitation — its notes repeatedly say to update a row "at the next checkpoint rather than adding a duplicate," which is right for avoiding double-counting but wrong for isolating what a given piece of work cost.

### 3.2 Preliminary conclusions — stated with their evidence tier

1. **(Tier 1, directly observed) There is no downstream data yet.** Every session logged is pre-merge: spec drafting, scaffolding, infra build, or review-of-not-yet-merged-work. The upstream/downstream comparison this project wants to make cannot be run on the current log — only asserted from the prose narrative. This isn't a flaw in the log; it's simply where the project is in its lifecycle (§2).
2. **(Tier 1, directly observed) Rework is visible in the notes but not measurable from the numbers.** At least four of six tickets' notes describe pre-merge rework explicitly — the naming/entity-model flip, the group-nesting reversion, the #35 schema-scope rewrite after feedback, the OIDC trust-policy gap patched twice. None of this is tagged as a distinct line item, so its token/dollar cost cannot currently be isolated from first-time work done in the same session. This is the single biggest data gap relative to what the project actually wants to know.
3. **(Tier 2, inferred, not measured) The two long "marathon" sessions are consistent with — but do not prove — the idea that ambiguity resolved mid-session is cheaper than ambiguity resolved after merge.** Both #31–34 and #35 show real architecture corrections happening inside the spec-writing session itself, before anything shipped. That is directionally what "shift left" should look like. But without a comparable downstream data point (a spec ambiguity that instead surfaced after merge, with its own logged cost), this is a plausible reading, not a demonstrated saving — exactly the kind of claim `spec-template-finops-research.md` warned against overstating.
4. **(Tier 1, directly observed) The log's current schema cannot answer the question we're asking.** It answers "what did this ticket cost" well. It cannot currently answer "was this cost new work or rework," "was this cost triggered by something already merged," or "did the spec written in session A reduce cost in the implementation session that consumed it" — because none of trigger, rework-pointer, or cross-session linkage exist as fields. Sections 4–5 exist to fix this going forward, not to re-litigate the existing 20 sessions after the fact (retrofitting them is possible but secondary — see §5.4).

## 4. Direction, and the reasoning behind it

Decided in the prior conversation, restated here as the standing position:

**Track sessions, not features, as the primary unit — but keep ticket, level, and trigger as tags on each session rather than dropping them.** Feature/ticket as the sole grouping key can't distinguish "this session was expensive because the practice around it is bad" from "this session was expensive because the feature was genuinely large or ambiguous" — the #31–34 marathon is a case in point, since it is a session-shape event (one long unbroken sitting spanning four tickets) as much as it is a ticket-level cost. Dropping ticket/level entirely would make that indistinguishable going forward. Keeping them as tags, with session as the unit that actually gets measured, gives both views without conflating them.

**The metric that actually tests the FinOps thesis is rework, not raw cost.** Cost alone is dominated by output-token volume (§3.1) and says nothing about whether spend was productive. What "does upstream investment reduce downstream cost" cashes out to, concretely, is: does the rate of rework — redoing something because an earlier decision (in this session or a prior one) turned out wrong — go down as practices mature. That requires rework to be a first-class, pointer-based field, not a phrase buried in a paragraph.

**Improvements need to be an explicit, dated, named log of their own, separate from sessions.** "We got better at this" is currently a story told from reading notes in hindsight. Each ADR amendment, template rule addition, or CLAUDE.md change is a discrete, dateable event (the project already produces these — ADR-0002/0003/0004, the spec-template amendment after #35's schema-scope correction). Logging them as their own list, each with a short name, lets a later session's rework rate be compared against "before/after PRACTICE-004" instead of against an undifferentiated timeline.

**Session boundaries need a splitting rule, retroactively applied where cheap.** The two marathon sessions each contain multiple distinct problems addressed in sequence, and the prose already narrates the sub-episodes (session notes already write "corrected after direct feedback... amended ADR-006... retrofitted naming.md and alternate-views.md" as a distinguishable unit within a longer session). A session doesn't need to be re-run to be split — the existing notes can be re-cut into sub-rows sharing the parent session UUID, at least for the two sessions that currently carry most of the weight.

**This is a live-tracking problem now, going into dev cycles, which is why capture needs to move as close to automatic as possible.** Manually classifying finished prose after the fact (which is what produced §3's preliminary reading) is exactly the effortful, approximate process we want to stop doing per-session. Section 5 is the concrete mechanism for that.

## 5. Keeping up with it: toward automatic, granular capture

### 5.1 What needs to be captured, beyond what exists today

The current log has: ticket, session id, model(s), token breakdown, cost, free-text notes. Added fields, all at the session (or sub-session) grain:

| Field | Values / shape | Why |
|---|---|---|
| `level` | process / project / feature | Distinguishes practice-level cost from feature-size cost — needed so raw session cost doesn't get misread as a practice signal when it's really a scope signal. |
| `trigger` | new-scope / reaction | Reaction = the session exists because of something already merged or already decided. New-scope = net-new work. This is the upstream/downstream split in observable form, independent of "ticket." |
| `rework-of` | pointer to a prior session id or sub-row id, or null | The direct measure of the FinOps thesis. If this trends down as `improvements` (5.3) accumulate, that's the evidence spec-template-research asked for. |
| `caught-by` | self / user / CI / prod | A maturity signal independent of cost — self-caught-before-merge is what better upstream practice should produce more of over time. The existing notes already distinguish this in prose ("caught by direct user pushback rather than self-derived") — this just makes it a field. |
| `drift` | boolean + one line | Did the session stay on its originating ticket, or expand into unplanned scope (as both marathon sessions did)? Drift has its own cost independent of whether the drifted-into work was good, and conflating it with the origin ticket's cost is part of why those two sessions are hard to read today. |
| `outcome-size` | rough count: specs produced / ADRs amended / files changed / lines changed | A crude denominator so cost-per-outcome can be watched over time instead of raw cost, which (§3.1) mostly tracks token volume rather than value produced. |

### 5.2 Session-splitting rule

A session becomes multiple rows (sharing the parent session UUID) when it contains more than one **distinct problem addressed**, where "distinct" means: a different `trigger`, a different `level`, or a hand-off point the session's own notes already narrate as separate (e.g., "session continued past #35's merge into an unticketed CI fix" is already a self-declared boundary). Sessions that are one continuous problem stay one row, even if long. This is deliberately narrative-boundary-based, not time- or cost-based, because the existing notes already do this segmentation in prose — the rule just says when to promote that segmentation into rows.

### 5.3 The improvements log

A second, separate list, one row per practice or architecture change: date, short name (e.g. `PRACTICE-004`), one-line reason, and which ADR/template/CLAUDE.md it changed. This already has real entries waiting to be captured retroactively — the spec-template's testability-check addition after #35, ADR-006's amendment on spec-scope boundaries, the two self-correction events already cited in the slide-content doc. Going forward, any session whose notes describe changing a rule going forward should produce one line here at the same time.

### 5.4 Retrofit vs. going forward

Retrofitting the existing 20 sessions against this schema is worth doing once, cheaply, for the two marathon sessions specifically (since they're 64% of all spend and already narratively self-segmenting) — but it's secondary to instrumenting new sessions correctly, since the marathon sessions predate any `improvements` entries to compare against anyway. The real evidence starts accumulating once dev cycles begin and both a `trigger=reaction` session and an `improvements` entry it postdates both exist.

### 5.5 Toward automatic capture — what's realistic

The stated preference is for Claude Code itself to keep tabs on this as work happens, rather than a human filling in a table after the fact. What's realistic, in decreasing order of how much already exists versus needs building:

1. **The raw numbers are already automatic.** `ccusage session` already produces the token/cost columns without manual computation — the manual part today is exclusively the classification (level, trigger, rework, caught-by) and the prose summary. Automating capture doesn't mean re-deriving `ccusage`'s job; it means not losing the classification the way it currently gets lost until someone writes the paragraph.
2. **The closest existing precedent in this project is AW-17/AW-20** (ADR-0004): periodic, cost-proportionate self-checks implemented as a Skill, run on a schedule rather than gating every session. A session-classification skill — invoked at natural checkpoints (session end, or the hand-off points §5.2 already narrates) — fits the same shape: not a new mechanism, an application of one already decided on for this project.
3. **What a skill can plausibly do today**: at a checkpoint, read back the session's own transcript, propose `level`/`trigger`/`rework-of`/`caught-by`/`drift` values and a one-line summary, and append the row — with a human glancing at the classification rather than authoring it from scratch. This mirrors AW-6's own two-tier pattern (mechanical check first, cheap classifier second, never the primary agent's own unprompted self-judgment as the sole gate) — here, "mechanical" is `ccusage`'s numbers, and "classifier" is the skill's read of the transcript, with the human as the actual gate rather than the classifier's output being trusted blind.
4. **What's genuinely unresolved and shouldn't be asserted as solved**: whether `rework-of` linkage (pointing a session back to the specific prior session/decision it's redoing) can be inferred automatically with any reliability, versus needing to stay a human judgment call the skill merely prompts for. No literature this project has checked measures this for coding agents (this is the same tier-3 gap `spec-template-finops-research.md` named), and nothing in this project's own research trail suggests an agent can reliably self-attribute "I am redoing X" without being told. Treat automatic `rework-of` tagging as aspirational/unvalidated until tried, not as a designed feature.

## 6. What this pipeline is not claiming

Consistent with this project's standing discipline: this is not a claim that upstream investment already measurably reduces downstream cost on this codebase — that's exactly what's unmeasured (§3.2, point 1). It's not a claim that session-level tracking will make rework-cause attribution automatic and reliable — that's named as unresolved (§5.5, point 4). It is a concrete, falsifiable setup: instrument sessions going forward with the fields in §5.1, keep the improvements log in §5.3, and let the comparison this project has wanted to make since `finops-agentic-shift-left-brief.md`'s "Fact 1" become something we observe on our own codebase rather than something we cite from elsewhere.

## Status

Direction and schema set; no capture mechanism built yet. Next concrete step is deciding the checkpoint(s) at which the classification skill (§5.5.3) runs, and whether it's invoked manually per-session first (to validate the classification against known sessions) before any auto-trigger is added.