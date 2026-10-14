# Project update: how we're building this, what it's costing, and what we're still figuring out

## Where this picks up

The prior deck (*Past the AI Layer*) argued that FinOps for AI stops too early — it manages cost after a system is deployed, when most real cost is decided earlier, in the architecture and process decisions made before a single feature is built. This update is that argument taken from theory into practice: what we actually decided going in, what it's cost us so far, what we've learned from watching it run, and what we're still testing.

Four parts: what we built and when, what we decided and why, what the numbers taught us, and what we're actively trying to improve.

## 1. What we did — by phase

Every piece of work is tracked against a ticket. On top of that, we group tickets into five broader phases for reporting, so where investment is going is visible at a glance:

| Phase | What it means |
|---|---|
| Standards | Deciding how work will be done, before any feature exists |
| Planning | Setting the project's overall scope, priorities, and initial technical scaffold |
| Design | Specifying what a feature should do and how, before any code is written for it |
| Development | Building something for the first time |
| Maintenance | Fixing or adapting something already built and live |

**Standards came first, before any feature work began.** We made four foundational decisions up front: how the codebase is organized, how code quality is enforced, how work is tested, and how the AI agents doing the work are structured. Section 2 covers each.

**Planning set the project's initial scope and scaffold** — the backlog and the technical starting point, before individual features were defined.

**Design is where individual features got specified before being built** — naming conventions, box-sizing, content authoring, alternate views, accounts and auth, each worked out ahead of implementation. This phase includes our two most expensive single sessions, where real architecture decisions were tested against real constraints and, in a couple of cases, reversed and redone before anything shipped — expensive in the moment, but the kind of correction we'd rather pay for before code exists than after.

**Development has just begun**, concentrated so far in infrastructure and deployment work. Some of it has already blurred into genuine Maintenance — real fixes to environments already live — though we can't yet cleanly separate that dollar cost from new-build work in the same sessions.

**Maintenance is effectively zero so far.** Development and Maintenance are tracked as separate phases rather than one combined "operations" bucket — placing a new bet and paying to fix something already shipped carry different risk, and combining them would hide which one spend is actually going toward. Maintenance being near-zero right now simply reflects that Development has only just started; it's the comparison we're set up to watch as it happens — does the upstream investment in Standards and Design actually show up as less Maintenance cost later.

## 2. What we've decided, and why

Before any feature work started, we made four foundational decisions about how this project would be built — covering the codebase's structure, how quality gets enforced, how work gets tested, and how the AI agents themselves are organized. These are what the standards, at the end of this process, turn into a concrete, checkable rule list.

### Codebase structure

**What we chose:** organize the code by feature — each feature's routing, logic, and data access live together in one place — rather than by technical layer, or a heavier pattern like domain-driven design or ports-and-adapters.

**Why:**
- Related code stays physically together, so a change to one feature doesn't require touching many unrelated files.
- A feature can be traced end-to-end quickly — important for both a person and an AI agent working in the code.
- It costs very little setup ceremony, which matters at this project's size.

**Tradeoff:** heavier patterns would have given us strict enforced boundaries between parts of the app, and a built-in way to test pieces in isolation, for free. We gave both up deliberately, and compensate for them elsewhere — in how we test, and in how we review high-risk work — rather than building them into the architecture itself.

### Code quality enforcement

**What we chose:** a two-layer system.
- **Automated checks** — formatting, type-checking, linting — run on every commit and block it automatically when something fails. This covers anything a machine can actually verify.
- **A short set of written guidelines** covers the few things no tool can check: does a name actually make sense, is a comment telling the truth, is a function trying to do too much. The two layers together are meant to be one complete system — the written layer exists specifically to cover what the automated layer structurally can't, not because the automated layer fell short.

**Why:**
- Automated checks are fast, reliable, and don't compete for the AI's attention the way written instructions do.
- A long list of written rules, on its own, tends to get silently ignored past a certain length — keeping that layer short and reserving it for genuine judgment calls avoids that.
- Splitting the two lets each do what it's actually good at.

**Tradeoff:** the automated layer costs setup time once and then runs for free — but it needs upkeep as tooling evolves, and a check that's too strict can block legitimate work, adding friction rather than catching a real problem. The written layer carries a different, ongoing risk: it can drift or get skipped over a long working session, and it only stays useful if it's kept genuinely short — left to grow, it risks becoming exactly the kind of ignored, over-long instruction set the automated layer was meant to avoid.

### Testing and verification

**What we chose:** we test how features actually behave together, not just in isolation — most tests exercise real code paths end-to-end rather than faking out everything around the piece being tested. A change isn't "done" until its tests actually run and pass, not because the code merely looks correct. A second, independent review pass is required only for the highest-risk logic, not for everything.

**Why:**
- This app's core feature (drag-and-drop, nested boxes) breaks specifically when pieces interact — which testing small pieces in isolation is bad at catching.
- An AI agent reviewing its own work is measurably less reliable than even a cheap, independent second look.
- Spending the extra review step only on high-risk work keeps its cost proportional to the actual risk.

**Tradeoff:** end-to-end-style tests cost more to run than narrow, isolated tests, and a second review pass costs more than a single pass. We spend both deliberately, only where the risk justifies it, rather than applying either one everywhere by default.

### How the AI agents are structured

**What we chose:** one agent handles one feature's work by itself, start to finish, rather than splitting a single feature across multiple coordinating agents. Separate, independent features run in parallel as separate, ordinary sessions — not as one orchestrated multi-agent system. A second, independent pass on a plan or on code is reserved for genuinely high-risk work, decided by a deliberate check rather than left to an agent's own opinion about whether it needs a second look.

**Why:**
- The parts of a single feature are usually too interdependent to divide cleanly across multiple coordinating agents — splitting one feature's work that way tends to underperform. This is different from running separate, independent features in parallel, which we do, and which works well.
- Reserving extra review for genuinely high-risk work keeps its cost proportional to the risk, instead of paying it everywhere by default.

**Tradeoff:** this leans on the codebase-structure decision above actually holding up — running features in parallel safely depends on them not secretly depending on each other behind the scenes. If that assumption breaks down anywhere, this needs revisiting for that part of the app specifically.

## 3. What we've learned from the sessions so far

As of this update: **40 sessions, $167.47 total**, tracked across the phases in Section 1. Beyond the totals, watching the sessions themselves surfaced how cost actually gets driven — not just how much of it there is.

**Most of the cost is re-reading context, not writing new material.** Every message in a session re-sends everything said so far, and it gets re-read in full on every turn. Roughly two-thirds of total spend is that re-reading, not new output. That means a session's cost compounds through its own length almost regardless of how much genuinely new work happens in any one turn — a long, well-run session and a long session that goes in circles can end up costing about the same.

**The riskiest shape is a long session that drifts across multiple, loosely related pieces of work.** Our two most expensive sessions — together, roughly two-thirds of everything spent — are also our two longest single sittings, and both share the same pattern: they didn't stay on one task. Every additional unrelated topic folded into an already-long session inherits the full re-reading cost of everything that came before it, whether or not it actually needed that context.

*What to do about it:* when a session's focus is about to shift to something unrelated to what it started on, that's the moment to close it out and start fresh, rather than carrying an unrelated topic forward inside an already-long context.

**Leaving a session idle for over about an hour is a separate, avoidable cost.** It forces the entire working context to be rebuilt from scratch at the next message, at a materially higher rate than a normal turn. In one session we reviewed closely, two such idle-triggered rebuilds accounted for over 40% of that session's most expensive cost category by themselves.

*What to do about it:* don't leave a session open and idle past about an hour if you're planning to keep working in it — close it and start clean when you're back.

**Model choice is a real, mostly-untested lever.** A faster, cheaper model tier is available at roughly half the rate of what most sessions have defaulted to, across every pricing category. We don't have enough sessions on the cheaper tier yet to say how much it would actually save here, but the price gap is large enough that it's worth deliberately testing rather than leaving as an unexamined default — for lower-stakes, well-defined work specifically.

## 4. Trial and error — optimizing for Quality, Cost, and Time (QCT)

Quality, Cost, and Time behave like a three-way tradeoff, in the same spirit as the CAP theorem for distributed systems — you don't get to maximize all three independently. The goal isn't to push every piece of work toward maximum quality, minimum cost, and minimum time all at once; it's to choose where on that tradeoff each specific piece of work should sit, given what it actually needs. High-risk work is worth spending more time and cost to protect quality. Low-risk, well-understood work should be optimized hard for cost and time, because the downside of getting it slightly wrong is cheap to catch and fix.

This section is explicitly not settled the way Sections 1–3 are. It's what we're testing, not concluding — and it's what feeds back into revising the standards over time.

**Should a failed pipeline trigger a rapid review?** We've already built this pattern at deploy time: a failed health check after deployment automatically triggers investigation and a draft fix, never silent and never auto-merged. What's still open is whether a failed pipeline *during* development — not deployment — should trigger that same kind of automatic rapid review, or whether that's better left to the normal development loop. Worth trialing, not yet decided.

**Anticipating problems before they cascade.** We've already seen the expensive version of not doing this: our costliest sessions are also the ones where a decision got made, found wrong, and remade within the same session — solving one problem only to discover the next a few steps later. What we're testing now is strengthening the upfront planning step itself — forcing explicit boundaries and open questions onto the table before implementation starts, rather than discovering them mid-build. It's the same shift-left idea behind this whole tracking effort, applied one level down: a few extra minutes spent thinking through what could go wrong is cheaper than paying to discover it serially, inside an already-long session.

**A gap we've identified but haven't closed: inline comment length.** We have a rule that comments have to stay truthful to the code, but nothing about how long one should be. A long comment costs tokens every single time that file gets touched again, and it's a reasonable candidate for the same kind of mechanical length cap we already put on functions. Flagged here as a real gap, not yet a decided rule.

**An open question: does infrastructure work need different sequencing rules than feature work?** Our default is that independent pieces of work run in parallel, each in its own session. That holds up well for feature work, which is designed from the start to stay independent. Infrastructure work doesn't always follow the same rule — some of it genuinely has to happen in sequence, even when the feature tickets riding on top of it don't. We don't yet have a clear general rule for when infrastructure work should parallelize versus serialize, and getting that right matters directly for QCT — it's one of the concrete things we're still working out, not something we've solved.

**Being trialed: batching low-stakes maintenance work into a scheduled window.** Every new session pays a small fixed cost just to get oriented, and — per Section 3 — leaving a session idle for over an hour forces a costly context rebuild. One lever under test: batching routine, low-stakes maintenance-style work into a single deliberate window (for example, once a night) instead of triggering it ad hoc throughout the day. Fewer separate session starts, and the idle-gap cost becomes something we plan around instead of something we hit by accident.

## Bottom line

We went into this believing that upstream investment — the architecture, the clean-code discipline, the testing strategy, the way agents are orchestrated — would reduce downstream cost. We now have a real accounting of what that upstream investment itself has cost ($167.47 across 40 sessions), a concrete picture of how sessions actually get expensive once work is underway, and a working list of what we're still testing to get the balance right. Development spend has only just begun; Maintenance — the actual bill for keeping something already-shipped running — is still close to zero. That comparison is the one this whole effort exists to make, and it's just starting to become possible to observe.