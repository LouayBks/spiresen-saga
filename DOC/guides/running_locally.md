# Running the app locally

Everyday "how do I run this" steps, split by slice as each one gets scaffolded. Companion to
`using_coding_agents.md` (that guide is about the dev *workflow*; this one is about getting a
server up) and `DOC/architecture/dependencies.md` (exact tracked versions). Hit something that
doesn't just work? Check `local_dev_troubleshooting.md` before assuming it's a code problem.

## Backend (`backend/`)

One-time setup:

```bash
cd backend
python3 -m venv .venv
.venv/bin/pip install --upgrade pip
.venv/bin/pip install -e ".[dev]"
```

Day to day:

```bash
.venv/bin/uvicorn app.main:app --reload   # serves on http://127.0.0.1:8000, GET /health to check
.venv/bin/ruff check .                    # lint
.venv/bin/ruff format .                   # format
.venv/bin/pyright                         # strict type-check
.venv/bin/pytest                          # tests
```

## Frontend (`frontend/`)

Needs Node ≥22.22.3 (see `dependencies.md`) — if `node -v` shows something older, get a
project-scoped Node 22 via `nvm` first (`local_dev_troubleshooting.md` has the exact steps), then:

```bash
cd frontend
nvm use 22   # skip if your default Node is already new enough
npm install
```

Day to day:

```bash
npx ng serve                              # serves on http://localhost:4200 (needs the backend running too for API calls — CORS is already set up for localhost:4200)
npx ng lint                               # lint
npx prettier --check .                    # format check (--write to fix)
npx tsc --noEmit -p tsconfig.app.json     # type-check (app)
npx tsc --noEmit -p tsconfig.spec.json    # type-check (tests)
npx ng test --watch=false                 # tests (Vitest) — see local_dev_troubleshooting.md if this hangs
```
