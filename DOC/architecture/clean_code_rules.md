# Point 2 — Final clean-code rules

Step 4 of point 2, following `ADR-0002` (hybrid strategy: mechanical core + a short curated prose residual). Every rule below carries a **recommended** implementation surface, drawn from ADR-0002's taxonomy — recommended, not mandated: the actual wiring may turn out differently once it's tried, and that's fine.

**Surfaces used below:**
- **Hook** — a deterministic, blocking pre-commit/CI check (formatter, type-checker, linter run as a gate).
- **Lint config** — a specific rule turned on in the existing linter/type-checker, not a bespoke script.
- **Skill** — an on-demand-loaded checklist/procedure for something judgment-based but routine enough to script as a repeatable pass, without paying its cost in every turn's context.
- **Agent/task def** — built into how a coding task or subagent role is framed (point 4), for rules that are about how work gets scoped rather than something checkable after the fact.
- **CLAUDE.md prose** — the smallest tier, reserved for what's genuinely uncheckable by any of the above (naming intent, SRP judgment, comment truthfulness).

Recommended tools (named here because step 4 is where concreteness belongs, per ADR-0002): backend — **ruff** (lint + import-sort + format, single tool) and **pyright** in strict mode (an LSP server, which also serves point 1's preference for LSP-based navigation over grep); frontend — **ESLint + `@typescript-eslint` + `angular-eslint`**, **Prettier**, and `tsc --noEmit` with `"strict": true`. Cross-stack duplication: **jscpd**.

## A. Formatting — fully mechanical

| ID | Rule | Surface | Notes |
|---|---|---|---|
| CC-1 | Backend code is auto-formatted, not manually styled | Hook | `ruff format`, pre-commit + CI gate |
| CC-2 | Frontend code is auto-formatted, not manually styled | Hook | Prettier, pre-commit + CI gate |
| CC-3 | Imports grouped stdlib → third-party → local, alphabetized | Lint config | ruff's `I` (isort) rules |
| CC-4 | Imports grouped and ordered (frontend) | Lint config | ESLint `import/order` |

## B. Typing / machine-checkable contracts

Directly resolves ADR-0001's carried-forward item "machine-checkable contracts over documented conventions."

| ID | Rule | Surface | Notes |
|---|---|---|---|
| CC-5 | Backend type-checked in strict mode | Hook | `pyright --strict` (or mypy strict), CI gate |
| CC-6 | Frontend type-checked in strict mode | Hook | `tsc --noEmit`, `tsconfig` `"strict": true` |
| CC-7 | No `any` in frontend code | Lint config | `@typescript-eslint/no-explicit-any` |
| CC-8 | No implicit `Optional`; explicit `X \| None` | Lint config | ruff `ANN`/pyright strict already enforces this |
| CC-9 | Every resource gets separate `Create`/`Update`/`Read` Pydantic models, not one shared everything-optional model | Agent/task def | Not lintable directly — build into the task template for "add a new resource/endpoint" |
| CC-10 | `interface` for object shapes, `type` only for unions/tuples (frontend) | Lint config | `@typescript-eslint/consistent-type-definitions` |

**Watch, don't over-apply:** per `clean-code-research.md` Part B §1, FastAPI's own type-hint-driven validation is implicated in that framework's worst-in-class correctness score in a controlled benchmark. These rules stand because the evidence for typed contracts elsewhere (repair pass@1, cross-file consistency checking) is real — but treat CC-5–CC-10 as a lever to monitor in practice, not a closed case.

## C. Complexity and size discipline

Directly resolves ADR-0001's carried-forward item "resistance to volume-driven quality collapse" (ρ=0.94 LOC-to-decay correlation, and the finding that more capable models produce *more* long-method violations, not fewer).

| ID | Rule | Surface | Notes |
|---|---|---|---|
| CC-11 | Function length soft ceiling ~40 lines | Lint config | ruff `PLR0915` (too-many-statements) |
| CC-12 | Cyclomatic complexity ceiling ~10 | Lint config | ruff `C901`; ESLint `complexity` |
| CC-13 | File length soft ceiling ~300 lines | Hook | No native ruff rule for this yet — small custom pre-commit script; ESLint has `max-lines` natively |
| CC-14 | Function length ceiling (frontend) | Lint config | ESLint `max-lines-per-function` |
| CC-15 | No duplicated logic beyond a small threshold | Hook | `jscpd` as a CI gate (cross-stack); a failing run is a prompt to extract a shared helper, not just silence the tool |

## D. Error handling / fail-fast

Directly resolves ADR-0001's carried-forward item "fail-fast vs. fail-silent."

| ID | Rule | Surface | Notes |
|---|---|---|---|
| CC-16 | No bare `except:`, no swallowed exceptions without re-raise or explicit logging | Lint config | ruff `E722`, `BLE001` |
| CC-17 | No empty catch blocks (frontend) | Lint config | ESLint `no-empty` (catch clause) |
| CC-18 | Domain errors raised via `HTTPException` or a single centralized `@app.exception_handler`, not scattered per-route try/except | Agent/task def | Structural convention, not lintable — apply when a task adds/touches a route |
| CC-19 | No mutable default arguments | Lint config | ruff `B006` |

**Cross-reference to point 3 (not resolved here):** CC-16–CC-19 make failure *visible in code*, but whether a failure path actually gets exercised is a testing-strategy question. Per ADR-0002's scope note, that's point 3's decision.

## E. Immutability / state discipline

Load-bearing for the box-canvas drag-drop feature specifically (Angular OnPush correctness requires new object/array references on every state change).

| ID | Rule | Surface | Notes |
|---|---|---|---|
| CC-20 | No mutating function parameters; return new objects/arrays | Lint config | ESLint `no-param-reassign` |
| CC-21 | OnPush change detection on every component | Lint config | `@angular-eslint/prefer-on-push-component-change-detection` |
| CC-22 | No mutable module-level globals in the backend beyond a justified immutable client (e.g., the DynamoDB resource) | Skill | Not reliably lintable — a periodic structural review pass, relevant because Mangum keeps the Lambda execution environment warm across invocations |

## F. Naming, comments, and documentation

The genuine mechanically-uncoverable residual — kept intentionally small per ADR-0002's "ruthlessly prune" principle.

| ID | Rule | Surface | Notes |
|---|---|---|---|
| CC-23 | Every public function/class/module has a docstring | Lint config | ruff `D` (pydocstyle) rules enforce *presence* |
| CC-24 | Docstrings and comments must stay true to the code — explain *why*, not restate *what* | CLAUDE.md prose | Presence is lintable (CC-23); truthfulness isn't |
| CC-25 | Names reveal intent; no abbreviations or disinformation | CLAUDE.md prose | The one item no linter can judge |
| CC-26 | Single Responsibility per function/class/component — one thing, done well | CLAUDE.md prose | Judgment call; kept short deliberately |

## G. Structural conventions (stack idioms)

Consequences of the stack already locked in (`ARCHITECTURE.md`) and the point-1 architecture choice — not independent rules, but conventions that make those choices actually hold up in code.

| ID | Rule | Surface | Notes |
|---|---|---|---|
| CC-27 | One `APIRouter` per feature slice, not one `main.py` | Agent/task def | Direct consequence of ADR-0001's vertical-slice choice |
| CC-28 | Shared dependencies composed via `Annotated[Type, Depends(...)]` aliases, reused across endpoints | Agent/task def | Avoids re-deriving the same dependency chain per route |
| CC-29 | Standalone components only; `inject()` over constructor DI; signals (`input()`/`output()`/`model()`/`computed()`) over `@Input()`/`@Output()` decorators | Lint config where available | `angular-eslint` has partial coverage (e.g. `prefer-standalone`); gaps fall to Skill-based review |
| CC-30 | Prefer explicit direct instantiation and pure functions with explicit DI over deep inheritance/Factory-Singleton-Strategy chains | CLAUDE.md prose | ADR-0001's "indirection tax on hallucination" carry-forward — primarily a design judgment call, not mechanically enforceable with the chosen toolchain |
| CC-31 | RxJS↔signal bridging via `toSignal()`/`toObservable()` (created once, reused, not re-called per source); `takeUntilDestroyed()` over manual `ngOnDestroy` teardown; `async` pipe in templates over manual `.subscribe()` | Lint config where available, else Skill | An `eslint-plugin-rxjs-angular`-style rule can catch missed `takeUntilDestroyed`/manual subscribe patterns if the version in use supports it — verify before relying on it; otherwise treat as a periodic review pass |
| CC-32 | Default to `private`; `readonly` on properties never reassigned outside the constructor | Lint config | `@typescript-eslint/explicit-member-accessibility`, `@typescript-eslint/prefer-readonly` |
| CC-33 | Prefer new control-flow syntax (`@if`/`@for`/`@switch`) and native `[class]`/`[style]` bindings over `*ngIf`/`*ngFor`/`NgClass`/`NgStyle` | Lint config if available, else Agent/task def | `angular-eslint` has migration tooling for this in recent versions — confirm the installed version actually ships the lint rule before assuming it's enforced automatically; default to applying it as a convention for new code either way |

## Summary: rule count by surface

| Surface | Count | Rules |
|---|---|---|
| Hook | 5 | CC-1, CC-2, CC-5, CC-6, CC-13, CC-15 |
| Lint config | 18 | CC-3, CC-4, CC-7, CC-8, CC-10, CC-11, CC-12, CC-14, CC-16, CC-17, CC-19, CC-20, CC-21, CC-23, CC-29 (partial), CC-31 (partial), CC-32, CC-33 (if available) |
| Skill | 3 | CC-22, CC-29 (residual), CC-31 (residual) |
| Agent/task def | 5 | CC-9, CC-18, CC-27, CC-28, CC-33 (fallback) |
| CLAUDE.md prose | 4 | CC-24, CC-25, CC-26, CC-30 |

The prose tier stays at 4 short rules out of 33 — consistent with ADR-0002's decision to keep that layer small enough to survive Anthropic's own "over-specified CLAUDE.md gets ignored" caution, with everything else pushed to a deterministic or task-structural surface instead.

## Note on traceability to research

`clean-code-research.md` contains a few additional narrow conventions not given their own rule ID here — consolidated rather than dropped: "prefer explicit over implicit" and "flat is better than nested" (Zen of Python) survive only as specific instances (CC-7, CC-8, CC-9); Pydantic's `ConfigDict(from_attributes=True)` and FastAPI's router-level shared `prefix`/`tags`/`dependencies` are folded into CC-9/CC-27/CC-28's broader statement rather than spelled out separately; Airbnb's JS mechanics (`const`-by-default, destructuring, arrow functions, spread, template literals) are left to whatever standard ESLint config gets adopted rather than given bespoke rules, since CC-20 already covers the load-bearing immutability part; PEP 257's `Args:`/`Returns:`/`Raises:` docstring structure and Google Python's "import modules, not names" were judged too marginal, or too unreliable to lint, to warrant their own line.