# Notes — reading the token usage log

Working notes on what actually drives cost in a session, using the ticket #5 session (`b8ea7071-…`, $2.45 / 4.87M tokens) as the worked example. Not a process document — just an explanation of the numbers so the log is legible later.

## The token mix looks alarming, but isn't uniform in price

| Token type | Count | Share of total |
|---|---|---|
| Input (fresh) | 108 | ~0.0% |
| Output | 39,916 | 0.8% |
| Cache creation | 286,165 | 5.9% |
| Cache read | 4,543,879 | 93.3% |

93% of the "4.87M tokens" is cache reads — the system prompt, tool definitions, and prior conversation history being re-supplied on every single turn so the model has full context. That's normal for any multi-turn agentic session and isn't itself a sign of waste: per Anthropic's published rates, a cache-read token costs roughly **1/10th** of a fresh input token and a small fraction of an output token. So the *volume* is dominated by cache reads, but the *cost* is not — output tokens (under 1% of volume) and cache-creation tokens (under 6%) carry most of the actual dollar weight, because they're priced far higher per token.

## What actually drove the cost, in order

1. **Turn count.** 54 API round-trips in this session. Every turn re-reads the entire accumulated context (system prompt + tool schemas + full conversation so far) from cache. That baseline cost per turn is fixed and grows with conversation length regardless of how small the actual question was — a lot of small back-and-forth (checking `/mcp` status, one-line confirmations, incremental diagnosis) adds turns without adding proportional value per turn.

2. **Two full cache-expiry resets — 124,311 tokens (43% of all cache-creation tokens) came from just these two events:**
   - `18:51:43` — 52,237 tokens recreated from scratch
   - `21:47:30` — 72,074 tokens recreated from scratch

   Both show `cacheReadTokens: 0` alongside a large `cacheCreationTokens` — meaning nothing survived from the prior cache and the *entire* context had to be rewritten at cache-write price (materially higher than cache-read price) instead of cheaply re-read. The second reset followed a ~2h17m gap in activity; caches expire after a TTL (5 min or 1 hour depending on tier), so idle gaps mid-session are one of the more avoidable cost multipliers here — each reset effectively re-bills the whole context once at the expensive rate.

3. **Tool schema loading.** Several `ToolSearch` calls pulled in full JSON schemas for tools like `Monitor`, `DesignSync`, `RemoteTrigger`, `SendMessage`, `WebFetch`/`WebSearch` — each is a few hundred to a couple thousand tokens, added once but then re-read on every subsequent turn for the rest of the session. Loading tools "just in case" has a compounding cost, not a one-time one.

4. **Exploratory investigation, not just the fix.** A meaningful chunk of this session was diagnosis — grepping config files, dumping `~/.claude.json`, reading plugin manifests, `git log --graph`, multiple `ccusage --json` pulls — before the actual one-line fix (setting `GITHUB_PERSONAL_ACCESS_TOKEN`) was identified. That's legitimate work, but it's why a ticket that "should" be a 5-minute fix shows a multi-dollar session: the cost reflects the debugging path, not the size of the final change.

5. **Output tokens are cheap per-unit but not free.** 39,916 output tokens across the session (explanations, generated docs, table rewrites) is the single largest few-cents contributor after the cache-write resets, since output is priced well above cache-read.

## Takeaway for future tickets

- Long idle gaps mid-session are the most concrete, avoidable cost driver found here — a session left open overnight or across a multi-hour break pays a cache-rebuild tax when it resumes. Wrapping up and starting fresh next time (rather than leaving a session dangling) can be cheaper than resuming a stale one.
- Turn count matters more than most people expect — batching questions/checks into fewer round-trips reduces the fixed per-turn cache-read cost.
- Diagnostic sessions (auth failures, config archaeology) will always look expensive relative to their eventual one-line fix — that's expected, not a red flag, as long as the log makes clear *why* (this file's purpose).

## Ticket #8 (#9's scaffold) — the most expensive single session logged so far

Session `150d8149-…`, $9.76 / 35.0M tokens — the largest single-session cost in this log to date
(previous max was `b445fc5c` at $7.55). Unlike the #5 example above, this was one long continuous
session rather than several resumed ones, so there's no raw-JSONL cache-reset timeline to point
at here — the analysis below is qualitative, from what the session actually did, not a re-derived
per-event breakdown.

| Token type | Count | Share of total |
|---|---|---|
| Input (fresh) | 422 | ~0.0% |
| Output | 90,305 | 0.26% |
| Cache creation | 492,984 | 1.4% |
| Cache read | 34,425,957 | 98.35% |

Cache-read share is even more dominant than the #5 example (98.4% vs. 93.3%) precisely *because*
the session stayed continuous — nothing expired and had to be rewritten at cache-write price, so
almost everything after the first few turns was a cheap re-read. The cost instead comes from how
many turns there were to re-read context on, and how much got loaded into that context in the
first place.

### What actually drove the cost, in order

1. **Background-task polling for slow local tooling.** This session ran ~15+ long-running
   installs/builds in the background (backend pip install, two npm installs, two `ng new` attempts,
   `ng add`, three `ng lint` runs, four separate `ng test` attempts, `tsc`, `pyright`) — each one is
   a full extra round trip (start it, get notified, read the output), and this machine's tooling
   was consistently slow (WSL + a OneDrive-synced mount + shared 3.8GB RAM across several
   concurrent Claude Code sessions).
2. **Environment debugging that didn't resolve cleanly.** Node 18 vs. Angular 22's minimum version
   (→ install `nvm`, install Node 22), a reproducible `npm`/`arborist` install bug (→ upgrade npm),
   and a Vitest worker-startup timeout diagnosed across four separate retries (`forks`, `threads`,
   sandbox disabled, `threads` again) that never actually got fixed — only documented as a known
   limitation. That's a distinct cost category from productive build work: turns spent ruling
   things out, not turns spent producing the deliverable.
3. **Reading the full rule-tagged doc set before writing code.** `clean_code_rules.md`,
   `testing_strategy.md`, `application_architecture.md`, `branching_strategy.md`,
   `using_coding_agents.md`, `plan_template.md` — six full docs read up front, per this repo's own
   AW-1/AW-14 doctrine ("read the docs, don't restate them"). Necessary and correct for a
   first-time-scaffolding ticket, but it's real, paid-once cache-creation cost that a smaller
   follow-up ticket in an already-scaffolded slice won't have to pay again.
4. **Several rounds of Plan Mode + `AskUserQuestion`.** The `draft/` folder's history, #11's scope
   (deferred to #10), the Node-version blocker, the Vitest blocker, and the commit-message
   convention design each added a clarifying round trip — the right call given how many of those
   were genuine "only the user can decide this" forks, but each one is a full turn.
5. **A genuinely large output.** Ten new/changed docs and config files (backend scaffold, frontend
   scaffold, two CI workflows, `commit_conventions.md`, `dependencies.md`,
   `running_locally.md`/`local_dev_troubleshooting.md`, `draft/` cleanup across four files, this
   log), split into 10 separate commits per the user's request — more output volume than a typical
   single-deliverable ticket, though still a small share of total tokens per the table above.

### Takeaway

- This is what a legitimate "first real ticket" session costs on this stack: reading the doc
  baseline once, scaffolding two runtimes from scratch, and hitting real environment friction on a
  resource-constrained shared machine. Not a red flag on its own.
- The environment-debugging line item (Node/npm/Vitest) is the one part of this cost that *won't*
  have to be paid again — it's now written down in `local_dev_troubleshooting.md` specifically so
  the next session that hits the same Node version wall or the same `npm`/`arborist` bug can fix it
  in one step instead of rediscovering it.
- This ticket bundled several logically-separable phases (branch+scaffold, doc cleanup, convention
  design, 10 commits, this log) into one very long continuous session. A long session keeps its
  cache warm (good — see the 98% cache-read share above), but every turn still re-reads the *entire*
  accumulated context, so the fixed per-turn cost keeps climbing as the session grows. Splitting a
  multi-phase ticket like this into a session per completed sub-deliverable trades some
  session-boundary/cache-rebuild overhead for a lower per-turn cost later in the work — worth
  weighing for the next multi-phase ticket (e.g. #10) rather than defaulting to one long session.
