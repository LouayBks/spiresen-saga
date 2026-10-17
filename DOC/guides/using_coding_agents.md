# Working on a ticket with Claude Code

This guide takes you from "I've been given a ticket" to "my PR is merged", using Claude Code. It assumes you know git and GitHub, but nothing about this project's rules or about Claude Code.

Read parts 1 and 2 once. Part 3 is the walkthrough you follow for every ticket. Part 5 explains the rule codes (`AW-1`, `WS-4`…) you'll see in other docs.

**The one thing to remember:** don't ask Claude to "implement issue #57". Claude would start writing code straight away, from its own reading of the ticket, skipping the plan and the review steps that catch mistakes early. Instead you go through these stages, each with its own conversation: **understand the ticket → plan the feature → plan the sub-branch → build → review**.

---

## Part 1 — Claude Code in five minutes

### What it is

Claude Code is an AI assistant that works directly in your copy of the repo. It reads files, edits them and runs commands (tests, git, `gh`). You talk to it in plain language, and it asks your permission before anything risky.

### Where you type

- **VS Code:** install the Claude Code extension, open the `spiresen-saga` folder, then open the Claude panel (the Claude icon in the sidebar). You type in the box at the bottom.
- **Terminal:** run `claude` from the repo folder. Everything below works the same way.

### Conversations

Each conversation (a "session") starts with no memory of earlier ones. When it starts, Claude reads `CLAUDE.md`, a short file at the root of the repo that points it to the project's docs.

**Keep conversations short and about one thing.** Every message makes Claude re-read the whole conversation so far, so a long conversation gets slower and more expensive with each message. Start a new conversation for each stage of the work: a plan, then a sub-branch build, then a review. In VS Code, use the "new conversation" button. In the terminal, type `/clear`.

### The settings you'll actually use

| Setting | What it does | How |
|---|---|---|
| **Model** | Which Claude does the work. **Opus** is the strongest and the most expensive: use it for planning, hard bugs and reviews. **Sonnet** is cheaper: use it for building from a clear plan. | The model picker in the panel, or type `/model` |
| **Plan Mode** | Claude can only read and propose. It changes nothing until you approve its plan. | The mode switch under the input box, or `Shift+Tab` in the terminal |
| **Normal mode** | Claude asks before each edit or command. | The same switch |
| **Auto-accept edits** | Claude edits files without asking each time (commands still ask). Only use it once you've approved a plan. | The same switch |

### Permission prompts

When Claude wants to run a command or edit a file, you get a prompt: allow once, always allow, or deny. Read it before you click: it shows the exact command. Some actions are **blocked for everyone in this repo**, whatever you click: deleting branches, force-pushing, pushing to `int` or `main`, merging PRs, and applying Terraform. A human does those.

### Pointing Claude at things

- **Files:** type `@` and a file name, for example `@DOC/specs/naming.md`, to make Claude read that file.
- **Slash commands:** a word starting with `/`. Here you'll use `/code-review` (a code review), `/model` and `/clear`.
- **Helper agents:** the repo defines two reviewers that start with a fresh mind, so they don't share the blind spots of the conversation that wrote the plan:
  - `plan-reviewer` reviews a plan before any code is written.
  - `risk-classifier` decides whether a change touches a sensitive area.

  You call them in plain words: *"Run the plan-reviewer agent on this plan."*

---

## Part 2 — How work is organised in this repo

### Tickets, features and PRs

- A **ticket** is a GitHub issue. Each feature issue describes one **feature**: a piece of the product that works end to end, for example "sign-in" or "the canvas". Its body lists what to build, what's out of scope, and how to prove it works.
- **One feature = one issue = one pull request into `int`.**
- A feature is built in **sub-branches**, one per layer, in this order: **infra** (cloud resources, Terraform in `infra/`) → **backend** (the API in `backend/`) → **frontend** (the app in `frontend/`). The issue lists them as a checklist. Each sub-branch gets its own plan and its own build conversation.
- The order of the features is in `DOC/architecture/delivery_sequence.md`.

### Specs and feature plans

Two kinds of documents decide what gets built. Keep them apart:

- **Specs** (`DOC/specs/`) say **what the product does**, one file per area of the product (Maps, Nodes and Links, accounts…). Each expected behaviour is one numbered row, such as "IF the owner requests a 4th View, THEN the backend SHALL reject the request". Each row says how to test it. Behaviour is defined **only** in specs.
- **A feature plan** (`DOC/features/<issue>-<slug>/`) is written once per feature, before any code. It has three files:
  - `manifest.md` lists **which** spec rows this feature delivers, and which sub-branch builds each one;
  - `design.md` says **how** it's built, layer by layer, with diagrams;
  - `tests.md` names the test that will prove each row.

Everything is linked by IDs, so you can always trace a piece of code back to the decision behind it:

- **Spec rows** are cited as `<spec>.<row>`, for example `alternate-views.BHV-2` (row numbers restart in each spec, so the spec name is needed).
- **Design elements** are numbered per feature and layer: `57-B3` is element 3 of #57's backend design (`I` for infra, `F` for frontend).
- **Code** names the design element it implements, in the docstring of each endpoint, repository function, top-level component or Terraform resource: `Implements: 57-B3`.
- **Tests** name the spec row they prove: `@pytest.mark.bhv("alternate-views.BHV-2")` in Python, or `[alternate-views.BHV-2]` at the start of the test title in the frontend.

### Branches

| Branch | What it is | Where it runs |
|---|---|---|
| `main` | Production | `saga.spiresen.com`, deployed after a human approves |
| `int` | Integration: every merged feature, before production | `int.saga.spiresen.com`, deployed on every merge |
| `dev/<you>/<issue>-<slug>` | Your feature branch, cut from `int`. Example: `dev/louay/57-foundation` | `dev.saga.spiresen.com` (see below) |
| `dev/<you>/<issue>-<slug>-<part>` | A sub-branch, cut from the feature branch. Example: `dev/louay/57-foundation-kernel` | — |

`<you>` is your own name when you're driving the work, even if Claude types the commits. It's `claude` only when Claude does a whole task on its own, or adds fixes to someone else's branch.

### The shared dev environment

There is **one** dev environment, and every push to a `dev/**` branch that changes `infra/` or `backend/` (or `frontend/`) deploys to it. The last push wins. So:

- **If someone has pushed a branch with infra changes that isn't merged yet, don't push your own dev branch**, unless yours was cut from theirs. Otherwise your push removes their infra from dev.
- Experiments you don't intend to keep stay local: don't push them.

### Where the knowledge lives

You don't need to read all of this up front. You'll point Claude at the right file when a step needs it.

| To know… | Read |
|---|---|
| What the product must do (behaviours, rules) | `DOC/specs/` — one file per area. A spec says *what*, never how it's stored |
| How data is stored (DynamoDB keys, access patterns, limits) | `DOC/architecture/data_cartography.md` |
| Which spec rows a feature delivers, and how it's designed | `DOC/features/<issue>-<slug>/` (templates: `DOC/templates/feature_*_template.md`) |
| What a sub-branch plan must contain | `DOC/templates/plan_template.md` |
| How to run and test the app locally | `DOC/guides/running_locally.md` |
| Commit message format | `DOC/architecture/commit_conventions.md` |
| Why a rule exists | `ADR/` (decision records) and `DOC/architecture/` |

### Sensitive areas

Three kinds of code get extra review, because a bug there leaks data or corrupts it:

1. **Access control:** who is signed in, who may read or edit a Map.
2. **Cross-Map checks:** finding which Map an item belongs to before allowing an action on it.
3. **Multi-item database writes:** transactions that keep counters, derived fields or uniqueness rules consistent (first-login setup, creating or deleting Nodes, Links and Maps).

When your work touches one of them, the design and the plan get reviewed by `plan-reviewer` before coding, and the code gets a `/code-review` before you merge the sub-branch. A hook (a script Claude Code runs automatically before each file edit) checks file paths against `.claude/risk-paths.json` to catch these areas. That list is still empty today, so for now **you** decide, and when unsure you ask Claude to run `risk-classifier`.

### Reviews and merging

- When you open a PR into `int`, a review bot (Claude on GitHub) comments on it automatically. Its comments are advice only: they never block the merge. Comment `/review` on the PR to run it again.
- **Only a human merges**, with "Create a merge commit" (squash and rebase are turned off).

---

## Part 3 — The walkthrough

The example is #57 (the foundation) and its first sub-branch, the kernel. Replace the numbers and names with your ticket's.

### Step 0 — One-time setup

1. Clone the repo and set up the backend and frontend as in `DOC/guides/running_locally.md`. Check that the tests pass before you change anything.
2. Install Claude Code (VS Code extension or CLI) and sign in.
3. Run `gh auth login`, so Claude can read issues and open PRs for you.

### Step 1 — Understand the ticket (Opus, Plan Mode)

New conversation, Opus, Plan Mode. Send:

```text
Read issue #57 with gh. Explain in plain words: what the feature is for, which
sub-branches it has and in what order, what is out of scope, and how it will be
verified. List the specs and architecture docs it depends on. Don't propose a
plan yet.
```

Read the answer. If something is unclear, ask in the same conversation. If the ticket itself is unclear, that's a question for the ticket owner, not for Claude to guess.

### Step 2 — Create the feature branch

In a terminal:

```bash
git switch int && git pull
git switch -c dev/louay/57-foundation
```

Or ask Claude to do it. It knows the naming from `CLAUDE.md`.

### Step 3 — Plan the feature (Opus, Plan Mode, once per feature)

Before any sub-branch, the feature gets its folder, `DOC/features/57-foundation/`. Do the three files in order. A new conversation for each is best, since each one reads the one before. In Plan Mode, Claude shows you the file it intends to write, and writes it once you approve.

**3a. The manifest: what the feature delivers.** Send:

```text
Using @DOC/templates/feature_manifest_template.md, write
DOC/features/57-foundation/manifest.md for issue #57. List every spec row
(cited as <spec>.BHV-n or <spec>.CON-n) and access pattern this feature
delivers, which sub-branch builds each, and the rows that belong to other
features. Don't write any behaviour text. If the feature needs something no
spec states, tell me instead of writing it.
```

**You** review the manifest: it decides the feature's scope. If Claude reports something missing from a spec, the spec is changed first, in its own commit, and the manifest then cites the new row.

**3b. The design: how it's built.** Send:

```text
Using @DOC/templates/feature_design_template.md, write
DOC/features/57-foundation/design.md for the layers this feature touches.
Give every element an ID (57-I1, 57-B1, 57-F1…) and its source, and draw
Mermaid diagrams: architecture for infra, module and sequence diagrams for the
backend, states and interactions for the frontend.
```

Read the diagrams before anything else. That's where mistakes are cheapest to fix. Look for:

- a module that does two jobs, or two modules doing one;
- a dependency that crosses a line it shouldn't;
- a loop of database calls where one query would do;
- a frontend call that doesn't match a backend element exactly;
- a permission granted "just in case".

If any element touches a sensitive area, send *"Run the plan-reviewer agent on design.md."*

**3c. The test plan: how each row is proven.** Send:

```text
Using @DOC/templates/feature_test_plan_template.md, write
DOC/features/57-foundation/tests.md: one planned test per behaviour in the
manifest, built from that spec row's testability check.
```

**Small features get a light version:** one layer and up to about 15 rows means the manifest, that layer's design and the test plan. Diagrams are then optional, except a sequence diagram for every write that changes several items at once.

Finally, ask Claude to commit the folder on the feature branch.

### Step 4 — Plan the sub-branch (Opus, Plan Mode)

Create the sub-branch from the feature branch:

```bash
git switch -c dev/louay/57-foundation-kernel
```

Start a **new** conversation (Opus, Plan Mode) and send:

```text
Plan the "kernel" sub-branch of issue #57, following
@DOC/templates/plan_template.md and @DOC/features/57-foundation/design.md.
Say which design elements it implements (by ID), which files you'll create or
change, what is out of scope, and how we'll prove it works end to end.
```

Claude answers with a plan. **Check it has the must-haves:**

- the design elements it implements;
- every file it will touch;
- what it will *not* do;
- a concrete check that proves it works (a test command, or a request against the dev environment).

The plan should decide nothing the design didn't. If it needs to, change `design.md` first.

If the plan touches a sensitive area, send:

```text
Run the plan-reviewer agent on this plan.
```

Fix what it finds, by telling Claude what to change, until you're happy. Then approve the plan.

**Skipping the plan** is fine only for a tiny change: one file, no logic, describable in one sentence (a typo, a log line, a rename). Anything else gets a plan.

### Step 5 — Build it (Sonnet is usually enough)

You can keep building in the conversation where you approved the plan. For a large sub-branch, start a new conversation instead (Sonnet or Opus), paste the approved plan, and say *"Implement this plan"*. Switch to auto-accept edits if you trust the plan.

While it works:

- **Ask it to run the tests** for what it changed, and read the result. A test that passes on one run and fails on the next is a problem to flag, not to retry until green. The commands are in `running_locally.md`. For the backend, run `.venv/bin/pytest`, `.venv/bin/ruff check .` and `.venv/bin/pyright` from `backend/`. For the frontend, run `npx ng test --watch=false` and `npx ng lint` from `frontend/`.
- **If it starts going in circles** (the same fix failing twice), stop it, ask it to sum up what it tried, and start a fresh conversation with that summary.
- **If it wants to change something outside the plan**, say no, or update the plan first.
- **Check the links are there:** each endpoint, repository function, top-level component or Terraform resource says `Implements: <design ID>`, and each test carries the spec row it proves (see Part 2, "Specs and feature plans").

### Step 6 — Review before merging the sub-branch (Opus, new conversation)

For a sub-branch that touches a sensitive area, this step is required. For others, it's recommended. A new conversation matters here: a reviewer that didn't write the code sees more.

```text
/code-review
```

With nothing after it, it reviews your current changes. You can also give it a branch or a PR number to review instead. Fix the findings that matter (see "Triaging review comments" below).

### Step 7 — Commit

Ask Claude:

```text
Commit this work following DOC/architecture/commit_conventions.md, and list
the design elements it implements in the message body.
```

Messages look like `feat(backend): add the id minting module`. Claude adds its own `Co-Authored-By` line.

### Step 8 — Merge the sub-branch into the feature branch

```bash
git switch dev/louay/57-foundation
git merge --no-ff dev/louay/57-foundation-kernel
```

Then check that the code still matches `design.md`: if it doesn't, fix the code, or record the difference in the design with its reason. Cut the next sub-branch from the feature branch and go back to Step 4 for it.

### Step 9 — Push and open the PR

1. **Check the shared dev environment first** (Part 2). If nobody has an unmerged infra branch pushed, push yours: `git push -u origin dev/louay/57-foundation`. If your feature has infra, it deploys to `dev.saga.spiresen.com`. Check the Actions tab on GitHub.
2. Ask Claude: *"Open a PR from this branch into int for issue #57, with a summary of what changed, the design elements and spec rows it covers, and how it was verified."*
3. The review bot comments on the PR. Go through its comments (below), push fixes, and **merge it yourself** with "Create a merge commit".

### Triaging review comments

Review comments can be endless. Sort each one into a tier:

| Tier | What it covers | What you do |
|---|---|---|
| **A — must fix** | Wrong results or lost data in normal use; a bug introduced by your last fix; docs that contradict the code; anything about security or infra | Fix before merging |
| **B — fix if cheap** | A real edge case that can happen here; a crash that is loud and harmless | Fix if it's a few lines in files the PR already touches; otherwise open an issue |
| **C — note and close** | Setups that don't exist here; speed with no measured problem; style; anything you checked and found doesn't happen | Reply in one line and resolve |

- **Check before arguing:** if a claim can be checked against real data in a minute, check it.
- **After the first round of fixes, only A items count**, and only on lines your fix changed.
- Every comment gets a one-line reply (the fix commit, or the reason it's not changed) and is then resolved.

The PR is ready to merge when no conversation is left open, no A item is left, and the checks are green.

### Step 10 — Record the token usage

When the ticket is done, refresh the token ledger: run `python3 DOC/usage/session_tokens.py --update DOC/usage/token_ledger.csv`, then commit the file. See `DOC/usage/README.md`.

---

## Part 4 — When something goes wrong

| What you see | What it means | What to do |
|---|---|---|
| A command is denied even though you clicked allow | It's on the repo's blocked list (`.claude/settings.json`) | Do it yourself if it's legitimate (push to your own branch, merge a PR on GitHub) |
| An edit is blocked with a message starting `AW-6:` | The file is in a sensitive area (the hook matched `.claude/risk-paths.json`) | Make sure the plan was reviewed by `plan-reviewer`. The hook can't yet let the edit through after that review, so ask the repo owner. This can't happen until the list of sensitive paths is filled in (#57) |
| Your dev deploy broke someone else's | Two dev branches with infra were pushed | Talk to them; the one whose branch includes the other's infra pushes again |
| A test fails, then passes when rerun | A flaky test | Note it in the PR; don't hide it by rerunning |
| The conversation feels slow or confused | It's grown too long | Ask for a summary of where things stand, start a new conversation, and paste it |
| You stepped away for over an hour | Claude has to rebuild its cache, which is paid in full | Before a long break, ask for a summary; resume in a new conversation |

---

## Part 5 — Rule codes, decoded

Other docs refer to rules by code. Here's what the common ones mean in practice. The full text is in `DOC/architecture/` and `ADR/`.

| Code | In plain words | Where it's defined |
|---|---|---|
| AW-1 | Skip the plan only for a one-file, no-logic, one-sentence change | `agentic_workflow_processes.md` |
| AW-4 | Sensitive plans get a review by `plan-reviewer` before coding | same |
| AW-5 | A sub-branch plan always lists the files touched, what's out of scope, and how it's verified, and cites the design elements it implements | `plan_template.md` |
| AW-6 | Sensitive areas are detected by a hook, then by `risk-classifier` when unclear, never by the coding conversation's own judgment | `agentic_workflow_processes.md` |
| TS-17 | Sensitive code gets a review by a different conversation from the one that wrote it | `testing_strategy.md` |
| TS-19 | A test that flips between runs is flagged, not retried until green | same |
| TS-20 | A test names the spec row it proves | same |
| CC-34 | Endpoints, repository functions, top-level components and Terraform resources name the design element they implement | `clean_code_rules.md` |
| AW-28 | A feature is planned (manifest, design, test plan) before its first sub-branch | `agentic_workflow_processes.md` |
| AW-29 | Review comments are sorted A/B/C; only A blocks the merge | same |
| FP-1..10 | How a feature is planned and linked to the specs | `ADR/ADR-009-feature-planning-and-traceability.md` |
| AW-21..27 | Branch names, who may push where, only humans merge, merge commits only | `branching_strategy.md` |
| AW-26 | Commits made by Claude working unattended name Claude as the author | same |
| WS-1 | One feature = one issue = one PR into `int` | `ADR/ADR-008-work-slicing-and-sequencing.md` |
| WS-2 | Features are built in sub-branches: infra → backend → frontend | same |
| WS-4 | Don't push a dev branch while someone else's unmerged infra branch is deployed | same |
| WS-9 | No more than three features in progress at once | same |
| CM-1..7 | Commit message format | `commit_conventions.md` |
| CC-*, TS-* | Coding rules and testing rules | `clean_code_rules.md`, `testing_strategy.md` |
