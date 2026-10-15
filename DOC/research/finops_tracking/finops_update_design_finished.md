# Project update: what our AI-assisted work actually costs, and why

## Where this picks up

The prior deck (*Past the AI Layer*) argued that FinOps for AI stops too early — it manages cost after a system is deployed, when most real cost is decided earlier, in the architecture and process decisions made before a single feature is built. It proposed shifting cost discipline upstream, using our own project as the proof it's possible.

This update is that proof taking shape: a full accounting of what our AI-assisted work has cost so far, broken down by where the spend went and why — not general argument, our own numbers.

## The four stages of cost we track

| Stage | Definition |
|---|---|
| Standards | Deciding how work will be done, before any feature exists |
| Planning | Deciding the shape of the whole project |
| Design | Deciding what one specific piece of work should do, before building it |
| Development | Building something for the first time |
| Maintenance | Fixing or adapting something already built and live |

Development and Maintenance are kept as separate stages, not one combined "operations" bucket — a bet on something new and the bill for fixing something already shipped carry different risk, and lumping them together would hide which one spend is actually going toward.

## The numbers, by stage

All AI-assisted work sessions on this project are logged with their token usage and cost. As of this update: **40 sessions, $167.47 total.**

| Stage | Sessions | Cost | Share |
|---|---|---|---|
| Design | 8 | $66.88 | 40% |
| Development | 5 | $43.43 | 26% |
| Standards | 21 | $41.99 | 25% |
| Planning | 5 | $14.95 | 9% |
| Maintenance | — | — | 0% |
| Unaccounted (billed, no matching record) | 1 | $0.22 | <1% |

Within stages:

| Stage | Work group | Sessions | Cost |
|---|---|---|---|
| Design | Feature design (first batch) | 2 | $40.27 |
| Design | Data-layer design | 5 | $16.84 |
| Design | Feature design (accounts/auth) | 1 | $9.77 |
| Development | Infrastructure and deployment | 5 | $43.43 |
| Standards | Process rules, templates, agent setup | 15 | $36.59 |
| Standards | Internal cost-tracking work itself | 5 | $2.95 |
| Standards | Tooling setup | 1 | $2.45 |
| Planning | Initial project scaffold | 2 | $12.53 |
| Planning | Backlog prioritization | 1 | $2.16 |
| Planning | Early backlog/issue planning | 2 | $0.26 |

**One caveat on the Development row:** it isn't purely new-build work. Session notes for the infrastructure group describe real fixes made to environments that were already live and serving traffic — the closest thing to genuine Maintenance work in the log so far. That work is mixed into the same sessions as new-build work, at a level of detail we can't cleanly separate into two dollar figures without re-reading that group's sessions individually. So the true Maintenance share is not zero, just not yet separable from Development in the numbers above — flagged here rather than guessed at.

## Findings

### 1 — A small but real share of spend sits outside any ticket

| | |
|---|---|
| **Observation** | About 2% of total spend ($3.43) has no ticket at all: internal cost-tracking work, early backlog planning done before any ticket existed, and one billed session with no matching record found. |
| **Risk** | If tracking stayed ticket-based only, this spend would be invisible — not wrong, just unmeasured. A measurement system that can't see all its own cost can't be trusted to size the picture correctly, even when the missing piece is small. |
| **Implication** | Track by session first, ticket second — a session doesn't need a ticket to be counted. |

### 2 — Group-level totals are distorted by single sessions, not by the nature of the work

| | |
|---|---|
| **Observation** | One group's cost more than doubled between our last review and this one — not because more work was done, but because a single session ($18.28) was reassigned into it. That one session accounts for 95% of the group's increase. |
| **Risk** | Comparing groups (or tickets) by total cost can rank them by which one happened to contain one long session, not by which kind of work is actually more expensive. |
| **Implication** | Any comparison across groups needs to control for session concentration, not just compare totals. |

### 3 — The specific, avoidable trigger behind expensive sessions is now identified: idle-gap cache resets

| | |
|---|---|
| **Observation** | Detailed review of two sessions found that letting a session sit idle for more than 60 minutes forces the AI's entire working context to be rebuilt from scratch at the next message, at a materially higher rate than a normal reused-context turn. In one session, two such resets accounted for 43% of that session's most expensive token category. |
| **Risk** | This is a concrete, avoidable cost — not an inherent property of long or complex work, but a specific side effect of how a session is paced. |
| **Implication** | Avoid leaving a session idle past the 60-minute mark; wrapping up and starting fresh costs less than resuming a stale one. This is confirmed on two sessions so far — treated as a working rule, not yet a proven pattern across the full log. |

### 4 — Corrective work (redoing something) is a small, distinct share of spend — separate from planned review

| | |
|---|---|
| **Observation** | Reviewing session content directly (not just titles), a small minority of sessions show a genuine redo — a decision reversed or a bug fixed on our own earlier work. A separate, larger set of sessions are planned quality checks against our own standards — that is not the same thing, and counting it as "rework" would overstate the problem. |
| **Risk** | Corrective work is the specific cost this whole effort is meant to reduce. Conflating it with planned review would hide the real, smaller signal underneath a larger, healthy one. |
| **Implication** | Track corrective work as its own category, distinct from review. Right now it's a minority of spend — worth watching as a trend, not yet a problem. |

## What happens next

| Step | What it does |
|---|---|
| Track every session, ticketed or not | Closes the ~2% blind spot in Finding 1 |
| Flag single-session concentration before comparing groups | Prevents Finding 2's distortion from repeating |
| Watch session idle time as a cost lever | Tests Finding 3 as a rule across more sessions, not just two |
| Keep corrective work counted separately from review | Turns Finding 4 into a trend we can actually watch |

## Bottom line

The prior deck argued, from outside evidence, that upstream investment should reduce downstream cost. We now have a full accounting of $167.47 in spend, with four concrete, evidenced findings about where that money goes and what's avoidable in it. Development spend has begun (26% of the total), but Maintenance — the actual bill for keeping something already-shipped running — is still effectively zero and mixed unseparated into Development's numbers. That's the comparison this tracking still needs to catch as it happens.