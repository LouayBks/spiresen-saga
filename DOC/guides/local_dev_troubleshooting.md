# Local dev troubleshooting

Known environment-specific issues hit while building/running this app locally, and what to try.
Not exhaustive — add to this file when you hit and resolve something non-obvious, rather than
letting the fix live only in your own memory or a PR description.

## Frontend

### `ng` refuses to run: "The Angular CLI requires a minimum Node.js version of..."

Angular 22 needs Node ≥22.22.3/24.15.0/26.0.0. Check `DOC/architecture/dependencies.md` for the
exact version this repo is built against. If your system Node is older, don't touch it globally —
install a project-scoped version with `nvm` instead:

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
export NVM_DIR="$HOME/.nvm"; [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm install 22
nvm use 22        # run this in every new shell, or `nvm alias default 22` to skip it
```

### `npm install` fails with `Cannot read properties of null (reading 'edgesOut')`

A known `npm`/`arborist` bug, not a problem with this repo's dependency graph. Fix: upgrade npm
itself (scoped to whichever Node you're using — this doesn't touch your system npm if you're on a
`nvm`-managed Node):

```bash
npm install -g npm@latest
npm install
```

### `npx ng test` hangs, then fails with `Timeout waiting for worker to respond`

Seen building #9 on a memory-constrained WSL machine running several concurrent sessions (3.8GB
RAM, heavy swapping) — not a scaffold defect; lint/format/`tsc` all passed fine at the time.
Reproduced identically with both Vitest's default `forks` pool and `threads`, and with the CLI's
own process sandbox disabled, so it points at resource contention rather than a pool-specific or
sandbox-specific bug — but that wasn't conclusively confirmed, just the leading explanation.

Things to try, roughly cheapest-first:

1. Close other heavy processes (other Claude Code sessions, other dev servers, etc.) and retry
   `npx ng test --watch=false` — if it's contention, freeing RAM/CPU should fix it outright. Check
   `free -h` first — heavy swap usage is the tell.
2. `frontend/vitest-base.config.ts` sets `pool: 'threads'`, but that's *not* a confirmed fix —
   both pools hit the identical timeout when this was diagnosed. It's an arbitrary choice, not
   something to trust; worth trying `forks` (delete the `pool` line) too.
3. If it's consistently reproducible regardless of load, it may be specific to running Node
   worker processes against a `/mnt/c/...` (WSL DrvFs) or OneDrive-synced path — worth testing
   whether it still happens from a native Linux filesystem path, though moving where the
   repo/`node_modules` lives is a bigger change that shouldn't be done without weighing the
   tradeoffs first.
4. Whatever you find, the actual gate for this is `frontend-ci.yml` on the PR — a real,
   uncontended GitHub Actions runner. Treat local failures here as a dev-experience problem, not a
   sign the code itself is wrong, unless CI fails too.
