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
