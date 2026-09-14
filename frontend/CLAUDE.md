# frontend/

Angular 22 workspace (standalone components only, Vitest as the test runner). Scaffolded by #9
via `ng new` — vertical slices (ADR-001) get their own directory under `src/app/` as they're
built; nothing beyond the default shell exists yet.

- Format/lint: `npx prettier --check .`, `npx ng lint` — see
  `../DOC/architecture/clean_code_rules.md` (CC-1..33) for the full rule set, `eslint.config.js` /
  `.prettierrc` for the actual config.
- Type-check: `npx tsc --noEmit -p tsconfig.app.json` and `-p tsconfig.spec.json`.
- Tests: `npx ng test --watch=false` (Vitest). See `../DOC/guides/local_dev_troubleshooting.md` if
  the worker pool fails to start on your machine — known WSL/low-resource issue, not a code
  problem.
- Run locally: `npx ng serve` (see `../DOC/guides/running_locally.md`).
- New component checklist: standalone, `inject()` over constructor DI, signals
  (`input()`/`output()`/`model()`/`computed()`) over decorators, `OnPush` change detection (CC-21,
  CC-29), new control-flow syntax (`@if`/`@for`/`@switch`) over `*ngIf`/`*ngFor` (CC-33).
