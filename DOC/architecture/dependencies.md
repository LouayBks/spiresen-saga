# Technical stack dependencies

Tracked versions of the runtimes and key tooling this app is built on. Update this file in the
same PR/commit that bumps any version below — it's meant to be trustworthy at a glance, not
something you cross-check against `package.json`/`pyproject.toml` to be sure. Full dependency
lists live in `backend/pyproject.toml` and `frontend/package.json`; this file is the short,
human-scannable summary of what actually matters — runtimes and the libraries a version bump of
which would be worth knowing about.

Last verified: 2026-09-15 (#10).

## Backend (`backend/`)

| Dependency | Version | Notes |
|---|---|---|
| Python | 3.12.3 | `requires-python = ">=3.12"` in `pyproject.toml` |
| FastAPI | 0.141.1 | |
| Mangum | 0.22.0 | Lambda adapter |
| uvicorn | 0.53.0 | local dev server only — Lambda uses Mangum, not uvicorn |
| ruff | 0.16.7 | lint + format (CC-1, CC-3) |
| pyright | 1.1.414 | strict mode (CC-5) |
| pytest | 9.1.1 | |
| pytest-randomly | 5.0.0 | order randomization (TS-12) |
| httpx | 0.28.1 | dev-only, via FastAPI's `TestClient` |

## Frontend (`frontend/`)

| Dependency | Version | Notes |
|---|---|---|
| Node.js | 22.23.2 | **Required** — Angular 22 refuses to run below ~22.22.3/24.15.0/26.0.0. This machine's system Node is v18.19.1 (too old); a project-scoped Node 22 was installed via `nvm` instead of touching system Node — see `DOC/guides/running_locally.md`. |
| npm | 12.0.2 | System npm (bundled with Node 18) hit a reproducible `arborist` install bug (`Cannot read properties of null (reading 'edgesOut')`) on this scaffold; upgrading npm (scoped to the nvm-managed Node) resolved it. If you hit that exact error, upgrade npm first before anything else. |
| Angular (`@angular/core`, `@angular/cli`) | 22.1.6 / 22.1.8 | standalone-only, no NgModules |
| TypeScript | 6.0.3 | `"strict": true` |
| Vitest | 4.1.11 | test runner (TS-7) |
| ESLint + `angular-eslint` + `typescript-eslint` | 10.10.0 / 22.5.0 / 8.69.0 | |
| Prettier | 3.9.6 | + `eslint-config-prettier` to avoid rule conflicts |
| RxJS | 7.8.2 | |

## Infra (`infra/`)

| Dependency | Version | Notes |
|---|---|---|
| Terraform | 1.11.2 (local); `required_version = ">= 1.9"` | CLI used to author/validate `infra/`; CI pins its own version in `infra-deploy.yml` |
| `hashicorp/aws` provider | `~> 6.0` | wildcard ACM cert (#10) forces `us-east-1` regardless of the environment's own region, via a provider alias |
