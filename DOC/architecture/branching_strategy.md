# Branching strategy and actor permissions

Companion to `agentic_workflow_processes.md` (AW-1..20) and ADR-004 Parts 2/3/8 — this defines
*who* (human vs. Claude) may do *what* to *which branch*, and how that's enforced. Rule IDs
continue that document's `AW-` sequence (AW-21..26) rather than starting a new namespace.

**Open item, flagged not silently resolved:** AW-24 below (Claude never applies infra, ever)
is stricter than ADR-004 Part 3's accepted text ("routine changes may apply directly"). This
doc encodes the stricter rule per direct instruction; ADR-004 itself needs a short amendment to
stop contradicting it — that amendment is not yet written.

## Enforcement-surface ladder

Before assigning a control to any rule below (or any future rule elsewhere in this project),
pick the rung by what a miss actually costs, not by what's convenient to write. This extends
ADR-002's existing implementation-surface taxonomy and its criterion B ("does the rule actually
get followed, or is it advisory only?") into an explicit ranking — each rung fails against a
different kind of bypass, and a rule only needs to sit as high as its consequence requires:

1. **CLAUDE.md / ADR prose** — advisory only. A wrong judgment call, or a session that never
   loaded that context, defeats it silently. Right for rationale and genuine judgment calls;
   wrong for anything where a miss has a real cost.
2. **Skill** — same advisory ceiling as prose, packaged as an on-demand procedure instead of
   always-loaded context. For judgment-based-but-repeatable checks that don't need to run every
   turn.
3. **Agent/task definition** — enforced architecturally: a subagent scoped to a role literally
   has no tool to exceed it. Stronger than prose because the *capability* is absent, not just
   discouraged.
4. **Hook / Claude Code's `permissions.deny`** — deterministic, can deny a tool call before it
   executes. The first rung that's real enforcement rather than a suggestion the model could
   second-guess — but it only binds inside Claude Code's own process. A raw command run outside a
   Claude Code session, or the config being edited away, isn't stopped.
5. **GitHub-side config (branch protection, required PR review, CODEOWNERS) + credential/IAM
   scoping** — enforced by a system entirely outside Claude Code's process, and the only rung
   that can bind to *who is acting*, not just *what action*. Required once a miss is irreversible,
   costly, or crosses a trust boundary — rungs 1-4 all share the weakness of being enforced by the
   same system they're constraining.

**Worked example, this session:** commit attribution (AW-26 below) sat on rung 1 — "always add
the trailer" — and a `git log` check on this very branch found it silently unfollowed on 2 of the
last 3 commits. That's not a hypothetical failure mode; it's why rung 1 is never sufficient once
a rule needs to be *relied on*, not just *hoped for*.

## Branch taxonomy

| Branch | Owner | Purpose | Deploys? |
|---|---|---|---|
| `main` | Human-merge-only | Production. Sole trigger for the deploy workflow (AW-24). | Yes — on push, human-merged only |
| `int` | Shared integration | Where issue branches land before promotion to `main`. Not itself a deploy target (no environment backs it yet — `environments/` under Terraform currently has only `prod`; a staging env is an open item in `application_architecture.md`, not assumed here). | No |
| `dev/<actor>/<issue>-<slug>` | One actor | Per-issue work, per the existing convention already in use (e.g. `dev/louay/4-setup-ai`). `<actor>` is either a human username or literally `claude`. | No |

This doesn't invent a new naming scheme — it formalizes the `dev/<actor>/<slug>` pattern
already visible in git history, and adds the actor-based rules below on top of it.

## AW-21 — Branch provenance

Claude may create a `dev/claude/<issue>-<slug>` branch, and only that shape. It must branch
from `int` or from an existing `dev/<human>/<slug>` branch — never directly from `main`, and
never as a fresh top-level integration branch. Claude never creates or renames `int` or `main`.

## AW-22 — No deletion, by anyone acting as Claude

Claude never deletes a branch, local or remote (`git branch -D`, `git push --delete`,
`git push --force` to a shared ref), regardless of whose branch it is or which mode
(interactive or autonomous) it's running in. This is absolute — not scoped to
`main`/`int` only.

**Severity: catastrophic (irreversible).** Enforced at two independent rungs so one bypass
doesn't remove the control:

- **Rung 4, live**: `.claude/settings.json` → `permissions.deny` hard-blocks `git branch -D`,
  `git push --delete`/`--force`/`-f`, direct `git push origin main`/`int`, `gh pr merge`,
  `terraform apply`/`destroy` before they execute. Cheap and immediate, but only binds this
  harness.
- **Rung 5, pending identity**: GitHub branch protection on `main`/`int` — disallow deletion,
  disallow force-push, require PR + ≥1 approval from a CODEOWNER, administrators excluded from
  the restriction (keeps a human emergency bypass while Claude's identity never gets one). This
  is the real backstop — server-side, holds even if rung 4 is edited away or bypassed entirely —
  but it can't meaningfully exclude Claude until Claude has a GitHub identity distinct from the
  repo admin (see Identity setup below); applying it is a live change to the shared repo, done
  only on explicit go-ahead, separate from any plan approval.

## AW-23 — Agentic-definition files are locked in autonomous mode

When Claude is running unattended (a scheduled Routine, a cron-triggered session, anything
without a human actively driving/approving each step — as opposed to an interactive session
where a human is present turn-by-turn), it may not edit:

- `CLAUDE.md` (root or per-slice, once AW-15 files exist)
- `ADR/**`
- `DOC/architecture/**` (including this file)
- `.claude/**` (agents, hooks, skills, settings, risk-paths.json)
- `.github/workflows/**`

In an **interactive** session, editing these is allowed but still goes through the normal
dev-workflow gates (Plan Mode per AW-1, high-risk detection per AW-6) — AW-23 only removes the
autonomous path for these specific paths, it doesn't add a new restriction on top of interactive
work.

**Severity: high.** Two rungs, one live now, one pending the identity work:

- **`CODEOWNERS`** (rung 5, repo root, new file) maps these same paths to the human owner. With
  today's single-collaborator repo it doesn't add a second approver, but it makes GitHub visibly
  flag these paths on every PR diff, and gives the Hook below a canonical, greppable list instead
  of a duplicate one. Fully meaningful once a non-admin Claude identity exists and needs approval
  to merge a PR touching these paths.
- **Mechanical Hook (rung 4), not yet built:** a check with the same two-tier shape as AW-6 — a
  Hook comparing (a) session mode (autonomous vs. interactive) against (b) touched path against a
  maintained list (mirroring `.claude/risk-paths.json`'s structure), denying the edit outright
  rather than just flagging it. TODO, same status as TS-1/7/12/15/19's blocked Hook halves: no
  autonomous/Routine infra exists yet in this repo to wire this against, so it's documented here
  as the contract, not yet implemented.

## AW-24 — Claude never applies infrastructure changes

Claude's role in deployment is prepare and verify only (plan Terraform diffs, review them,
run post-deploy health checks) — never `apply`, never `destroy`, for any change, destructive or
routine. A human always executes the apply, either by merging to a deploy-target branch
(triggering CI/CD) or running Terraform locally. This supersedes ADR-004 Part 3's "routine
changes may apply directly" — see the open item at the top of this doc.

**Three deploy targets exist as of the third-environment work (2026-09-16/17):**
`infra-deploy.yml`/`frontend-deploy.yml` (**prod**, `athar.spiresen.com`) trigger only on push
to `main`, gated behind the "prod" GitHub Environment's required reviewer.
`infra-deploy-int.yml`/`frontend-deploy-int.yml` (**int**, `int.athar.spiresen.com` — renamed
from `dev.athar.spiresen.com` to free that hostname for the new `dev` target below) trigger
only on push to `int`, deliberately **not** reviewer-gated — int is the fast-iteration
environment, and a human still approves every merge into `int` via required PR review (AW-25),
so the deploy itself runs unattended the same way `backend-ci`/`frontend-ci` already do on
`int`. This is a deliberate widening of this rule's original text (which named only `main`, from
when a single deploy target existed) — not a loosening of it: **the constraint below is per
deploy target, not "main only."**

For **prod and int**: no `workflow_dispatch` path that Claude can invoke, no deploy-on-PR, no
deploy from any `dev/*` branch — each target's auto-apply trigger is exactly the one branch
that owns it (`main`→prod, `int`→int), nothing else.

**`dev` (`dev.athar.spiresen.com`) is a deliberate, bounded exception to the "no deploy from
any `dev/*` branch" clause above, and only to that clause.** `infra-deploy-dev.yml`/
`frontend-deploy-dev.yml` trigger on a push to *any* `dev/**` branch — no PR gate, no
required-reviewer Environment protection, by design: `dev` exists specifically to surface real
OIDC/IAM/deploy failures before a developer ever opens the `int` PR, not to gate promotion (a
prior `int`-merge broke this exact way — a trust-policy gap that a PR's `plan` job couldn't
have caught, since `plan` and the real `apply` authenticate with structurally different OIDC
token shapes; see `infra_setup.md` step 4's "fifth gotcha"). This does not loosen `main` or
`int`'s rule: `workflow_dispatch` stays forbidden for all three targets, and `main`/`int` remain
each the sole trigger for their own target. `dev` is one shared, last-push-wins environment
(not per-branch/per-actor isolated) — a `concurrency:` group on both workflows queues
overlapping pushes from different `dev/*` branches rather than racing for the state lock or the
live hostname, but does not give any branch its own isolated deployment.

All three AWS environments currently share a single AWS account and one CI OIDC role
(differentiated only by resource naming and separate Terraform state, not by a credential
boundary) — fully separate per-environment AWS identity (a second account, its own OIDC trust
root) is a known future item, not yet built (see ADR-005).

## AW-25 — Claude's commits reach `main`/`int` only via human-approved PR

Claude may commit freely to its own `dev/claude/<slug>` branches and open PRs into `int` or a
`dev/human/<slug>` branch. No commit from Claude — regardless of how low-risk AW-1's bypass
judged it, and regardless of Unit 3's review outcome — merges into `int` or `main` without a
human accepting the PR. This is not a new mechanism: it's AW-13's existing "check-run always
neutral, merge authority stays human" rule, restated here as a branch rule so it's visible from
this doc rather than only from the review-workflow one.

**Severity: medium**, for the "PR-only" half — already covered by AW-22's rung-5 "require PR
before merge" setting on `main`/`int`, no separate mechanism needed. Branch-naming/provenance
(AW-21) is the same tier: a CI naming-lint check validating `dev/<actor>/<slug>` on PR is a named
future option (rung 4, GitHub Action config), not built — no workflow infra exists yet to hang it
on, and it would be advisory either way (matching `claude-review.yml`'s own neutral-conclusion
precedent). Two pre-existing branches, `dev-louay-12-branches` and `dev-louay-7-solution_design`,
predate this convention — grandfathered, not renamed.

**Bug tickets:** when autonomous investigation (AW-8's alert-triage path) turns up an issue,
Claude opens a bug ticket (`gh issue create`) describing it alongside the draft PR, falling back
to describing it in the PR body if issue creation isn't possible (permissions, `gh` unavailable)
— never silently fixing without a paper trail.

**Interaction with `dev` (AW-24):** this PR-gate guarantee covers `int`/`main` only. `dev` is
deliberately outside it — a human's *push* (not a review, not a merge) to any `dev/*` branch is
sufficient to trigger a real `apply` against the `dev` environment, regardless of whether the
pushed commits are Claude-authored. Claude's own capability is unchanged (no push access at
all, in any sandbox this project has used so far) — but before `dev` existed, "no Claude commit
reaches anything live without a human-approved PR merge" held for every deploy target, because
`int`/`main` were the only ones. That's no longer true project-wide, only true for `int`/`main`
specifically. Worth remembering when reasoning about what "reviewed before it's live" actually
covers.

## AW-26 — Claude's commits are attributed as Claude's, not the human's

Checked against this branch's own history: `git log` shows `Author: louay.belkhamsa` on every
recent commit regardless of who actually wrote the change, and the `Co-Authored-By: Claude`
trailer is missing from 2 of the last 3 — i.e. there is no reliable signal distinguishing a
Claude commit from a human one, purely from the message trailer. Author and Committer are commit
metadata, not push credentials, so overriding them doesn't depend on the GitHub-identity work
above — it's mechanically possible today.

**Severity: high once it matters** — a misattributed commit isn't itself dangerous while a human
is reviewing every session's work directly (as now); it becomes load-bearing once autonomous
agents are acting unattended (maintenance Routines, alert-triage per AW-8) and a human is relying
on `git log`/`git blame` after the fact to tell what Claude did without having watched it happen.

- **Deliberately not applied yet.** During interactive sessions with a human actively driving,
  the existing `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>` trailer (kept, best
  effort) plus the human's own review of every commit is judged sufficient — an Author/Committer
  override adds no real signal when the human already saw the work happen turn-by-turn.
- **Trigger to actually apply it:** the first autonomous/unattended Claude action in this repo —
  a maintenance Routine, an alert-triage draft PR (AW-8), or anything else run without a human
  present turn-by-turn. At that point, every commit such a session creates overrides Author *and*
  Committer explicitly (`git commit --author="Claude Sonnet 5 <noreply@anthropic.com>"` plus a
  `-c user.name=`/`-c user.email=` committer override) — a real field, visible in `git log`,
  `git shortlog -sn`, and GitHub's commit list, not text that can be silently dropped. Once the
  machine-user account below exists, this becomes that account's real identity instead of a
  placeholder.
- **Enforcement, once triggered:** rung 4 (a Hook rejecting or auto-injecting the override on
  `git commit` Bash calls, scoped to autonomous sessions) is the right eventual home — tracked in
  issue #19 alongside AW-23's mechanical Hook, not built yet since no autonomous-session infra
  exists to distinguish "autonomous" from "interactive" in the first place.

## Identity setup — human action items, not automatable by Claude

Neither piece below can be created by Claude — account creation and App registration are
inherently human/admin actions. Listed here as a checklist, not yet executed:

- **GitHub App** — register under the account, permissions limited to Contents (R/W), Pull
  requests (R/W), Issues (R/W), Metadata (R) — explicitly no Administration; install on this repo
  only; store App ID + private key as repo secrets. This is what `claude-review.yml` (and any
  future alert-triage Routine, AW-8) should authenticate as instead of today's implicit
  `GITHUB_TOKEN` — rewiring that workflow is a separate follow-up once the secrets exist, not done
  until then.
- **Machine-user account** — a second GitHub account, invited as a collaborator on this repo with
  **Write** role (not Admin/Maintain), with its own fine-grained PAT scoped to this repo and the
  same three permissions as above. This is what local interactive sessions should use for git
  identity once it exists; until then, sessions keep using the human's own credential for push —
  AW-26's override stays dormant regardless, since interactive sessions don't need it (see AW-26).
- Without either of these, rung 5 controls (branch protection's "require review from a CODEOWNER,"
  in particular) cannot meaningfully exclude Claude, because Claude and the approving admin would
  be the same account.

## Relationship to existing rules

| This doc | Extends |
|---|---|
| AW-21 | AW-2 (worktree-per-issue) — adds the actor-in-branch-name and provenance constraint AW-2 didn't specify |
| AW-22 | New — no prior rule covered branch deletion |
| AW-23 | AW-6's detection shape, applied to a new file set instead of TS-17's risk areas |
| AW-24 | Tightens ADR-004 Part 3 — flagged conflict above |
| AW-25 | Restates AW-13/AW-11 as a branch-level rule |
| AW-26 | New — no prior rule covered commit attribution |
