# Relay sessions — how to use them (trial)

A relay builds one sub-branch as a chain of short sessions instead of one long one. Each session ("hop") does **one item** of a static reference doc, verifies it, commits it, and ends with a short **hop message**. The next session starts fresh from that message. Nothing else is passed between sessions: git and the tests hold the state, and the reference doc holds the plan.

**Status: trial.** Built on `dev/louay/relay-sessions` and not adopted yet. Every existing rule still applies inside a hop: hooks, AW-6/AW-4/TS-17 escalation, WS-1..9, CM-1..7. If the trial (section 6) shows a real saving at equal quality, it becomes an ADR-004 amendment and an AW rule. Until then this guide is the only place it's described.

## Why

Every turn re-reads the whole conversation, so a session's cost grows with the square of its length. In the 57 sessions logged from 13 Sep to 14 Oct, 66% of the cost came after turn 100. Replaying those sessions as if they had hopped to a fresh context every ~60 calls cut the cost of carrying context to about half. That figure is an **upper bound**: it assumes nothing is lost between hops. Measuring what is actually lost is what the trial is for.

It also moves model routing to one place. The reference doc gives each item a model and an effort, chosen once while planning. Nothing switches models in the middle of a session, and nothing guesses a tier from the prompt.

## When to use it, and when not

| Use it for | Don't use it for |
|---|---|
| Implementing a sub-branch (WS-2) that has a written plan | Design or spec conversations, where the reasoning is the deliverable |
| Work that splits into items you can verify one by one | Deep debugging, where 30 turns of observations are the working state. Keep that in one session |
| | AW-1 bypass changes. A hop's fixed start-up cost is larger than the work |

## The pieces

| Piece | Path | Role |
|---|---|---|
| Reference doc template | `DOC/templates/relay_reference_template.md` | The plan floor plus numbered items, each with its model, effort and "Done when" |
| Reference docs | `DOC/relay/<issue>-<slug>.md` | One per sub-branch. Committed before the relay starts, never edited during it |
| `/relay` skill | `.claude/skills/relay/SKILL.md` | The hop rules and the hop message format. Used by both manual and scripted hops |
| Driver | `.claude/skills/relay/relay.sh` | Runs the hops without you, one headless session per item |
| Hop log | `~/.claude/relay-logs/<branch>.tsv` | One row per scripted hop (session, model, turns, cost). For measurement only; no hop reads it |

The hop message (the skill holds the exact rules):

```relay
RELAY DOC/relay/57-maps-backend.md @ 3f9c2a1
DONE  T3 @ a1b2c3d
NEXT  T4
DEAD  - tried a GSI on owner_id for the listing; violates CON-12, don't retry
OPEN  -
FAILS T4: 0
```

The `RELAY` line names the doc and the start of its git blob hash. A hop refuses to start if the doc changed.

## 1. Write the reference doc

1. In a session on Opus, in Plan Mode, write the doc from the template for one sub-branch. The plan floor comes first, then the items.
2. AW-6 and AW-4 apply to this doc as to any plan. If it's flagged high-risk, `plan-reviewer` reviews it **before** the relay starts.
3. Size each item at roughly 20–60 turns of work, with its own "Done when" check. Choose its model: `opus` for tricky or planning-heavy items, `sonnet` for well-specified implementation, `haiku` for mechanical work.
4. Commit it on the sub-branch, then check that it parses:

   ```bash
   .claude/skills/relay/relay.sh DOC/relay/<issue>-<slug>.md --dry-run
   ```

   This lists each item with its model and effort, and prints the first hop message. It makes no model call.

## 2. Run it by hand, in VS Code

1. Open a **new conversation**. Set the model picker to the first item's model, then send:
   `/relay start DOC/relay/<issue>-<slug>.md`
2. The session does that one item and ends with a ```` ```relay ```` block. Copy it.
3. Open another **new conversation**. Set the model to the next item's model, then send `/relay` followed by the pasted block.
4. Repeat until the block says `NEXT  END`.

Rules for manual mode:
- **Never continue in the same conversation after a block.** Starting fresh is the whole point.
- **You set the model.** The skill can't change it for you, so read the item's `Model:` line before each hop.
- **To leave mid-item** (a meeting, or more than an hour away): send `/relay hop`. The session stashes or commits and prints the block. A session left idle for over an hour pays a full cache rebuild when you come back.

## 3. Run it headless

From the root of the worktree that holds the sub-branch:

```bash
.claude/skills/relay/relay.sh DOC/relay/<issue>-<slug>.md            # from the first item
.claude/skills/relay/relay.sh DOC/relay/<issue>-<slug>.md --from T4  # from a given item
```

Options: `--max-turns N` per hop (default 60), `--max-hops N` (default 20). Environment: `RELAY_PERMISSION_MODE` (default `auto`) and `RELAY_LOG_DIR`.

What to know:
- **Each hop is a fresh `claude -p` session** on the item's pinned model (`claude-opus-5-5`, `claude-sonnet-5-5`, `claude-haiku-5-5`). The bare `haiku` alias resolves to Haiku 4.5, which in auto mode has every tool call denied when run headless. That's why the driver pins model IDs.
- **Commits are Claude's (AW-26).** A headless hop runs unattended, so the driver sets the git author and committer to the hop's model (`Claude Sonnet 5.5 <noreply@anthropic.com>`). Hops you run by hand keep your identity, as any interactive session does.
- **Approval gates still hold.** `.claude/settings.json`'s deny list applies in auto mode, so a hop can't push, merge, delete branches or run `terraform apply`. The relay always ends before anything needs your approval.
- **Each hop has a fixed start-up cost.** The ~35k-token starting context is paid on every hop: a trivial Haiku hop cost $0.10–0.26 in the smoke test. That's why items shouldn't be tiny.

## 4. When it stops

The driver exits with `0` at `END` and with `2` whenever it needs you. In both cases it prints the last hop message, so you can carry on by hand with `/relay`.

| Message | Meaning | What you do |
|---|---|---|
| `END — all items done` | Every item is committed | Go to section 5 |
| `hop N raised an open question` | The doc is wrong or missing a decision | Decide. If the doc changes, commit it and restart with `--from <item>`. Otherwise answer by continuing by hand |
| `<item> failed on two hops` | The same item failed twice | Read `DEAD` and the stashes (`git stash list`, named `relay <item> attempt <n>`). Usually the item is too big or underspecified: split it in the doc and restart |
| `<doc> changed during the relay` | Someone edited the reference doc mid-relay | Commit the doc deliberately, then restart from the right item |
| `ended without a hop message` | The hop hit `--max-turns`, or crashed | Look at it with `claude --resume <session>`, then finish it by hand or restart the item |
| `names unknown item` | The hop message is malformed | Fix the block by hand and continue by hand |

## 5. After `END`

Same as without a relay (`using_coding_agents.md`):
- **High-risk sub-branch:** TS-17 `/code-review`, unless the doc's last item already did it.
- **Merge:** the sub-branch into the feature branch with `--no-ff` (WS-2).
- **Push and PR:** respect WS-4 when pushing, and open the PR into `int`.

To see what each hop did: `git log --format='%h %s %(trailers:key=Relay-Item,valueonly)'`.

## 6. The trial: build the same feature several ways, in parallel

The goal is to measure, on a real feature, whether relaying saves money at equal quality, and whether choosing models per item adds anything on top.

### Variants

| Variant | Procedure | What it isolates |
|---|---|---|
| **A** (baseline) | Today's flow (`using_coding_agents.md`): one session per sub-branch, with the reference doc as its plan | Nothing. It's the comparison point |
| **B** | Relay by hand in VS Code, models as in the doc | The effect of relaying, with you in the loop |
| **C** | Headless relay with the driver, models as in the doc | Relaying plus unattended hops |
| **D** (optional) | Headless relay, every item set to `sonnet` | Whether choosing models per item matters, compared with C |

### Setup

1. **Same starting point for everyone.** Write and commit the reference doc first. Every variant branches from that commit, so all of them get the same plan.
2. **One worktree and branch per variant:**
   ```bash
   git worktree add .claude/worktrees/<issue>-a -b dev/louay/<issue>-<slug>-a <doc-commit>
   git worktree add .claude/worktrees/<issue>-b -b dev/louay/<issue>-<slug>-b <doc-commit>
   git worktree add .claude/worktrees/<issue>-c -b dev/louay/<issue>-<slug>-c <doc-commit>
   ```
   For D, copy the doc with every item set to `sonnet`, commit it on D's branch, and use that.
3. **Don't push variant branches.** Any `dev/**` push that touches `infra/`, `backend/` or `frontend/` deploys to the one shared dev environment, and the last push wins (WS-4). Parallel variants would overwrite each other's deployments. Verify locally, and push only the variant you keep. If an item's "Done when" needs the real dev environment, run those items one variant at a time and note that in the results.
4. **Mind the caps.** Variants count toward WS-9's three-worktree cap. On this machine (WSL, a OneDrive-synced folder, shared RAM), variants running at the same time slow each other down. Compare cost and quality across variants, but not elapsed time.
5. **Keep conditions even.** Don't leave any variant idle for more than an hour in the middle of an item (`/relay hop` first). For A, run each sub-branch session straight through.

### What to record for each variant

| Measure | Where it comes from |
|---|---|
| Sessions | C and D: the hop log. A and B: open the variant's worktree folder as its own VS Code window, so every session launched there gets its own transcript folder (`~/.claude/projects/…-claude-worktrees-<issue>-<x>/`); the file names are the session ids |
| Cost and tokens | `python3 DOC/usage/session_tokens.py --since <start date>`, then filter by those session ids. Worktree sessions are attributed to this repo |
| Quality | Does the end-to-end verification pass? How many findings does `/code-review` return on the variant's final diff (run it the same way for every variant)? How long does your review take? |
| Rework | FAILS counts and stashes (B–D); fix-up commits that rewrite lines an earlier commit just wrote (all variants); OPEN stops |
| Your time | Minutes you spent driving it. Manual variants cost your attention, and that belongs in the comparison too |

Put the results in a table and log the sessions in the FinOps log with their `trigger` and `rework-of` fields:

| Variant | Sessions | Cost (API-eq.) | Verification | Review findings | Rework events | Your minutes |
|---|---|---|---|---|---|---|
| A | | | | | | |
| B | | | | | | |
| C | | | | | | |
| D | | | | | | |

**What counts as a win:** lower cost with the same verification result and no more review findings. A cheaper variant with more findings has moved cost into review and rework, not removed it.

## Known limits

- **Dead ends survive only if each hop passes them on.** A dead end that matters for the whole feature means the doc is missing something, so add it to the doc between relays.
- **Manual mode depends on you** setting the model and starting a fresh conversation every time.
- **The saving is simulated, not yet measured.** The ~50% figure assumes no loss between hops, and section 6 exists to replace it with a measured number.
- **Haiku hops are only as safe as their item is specific.** Keep `haiku` for mechanical items with an exact "Done when" check.
