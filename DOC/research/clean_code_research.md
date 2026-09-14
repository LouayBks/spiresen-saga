# Point 2 research notes — clean code

Backing research for `ADR-0002: Clean-code rules and enforcement strategy`. Two parts: (A) canonical, sourced best-practices for this project's actual stacks; (B) how those practices interact with Claude/LLM code-generation correctness and cost specifically. Evidence is tiered throughout (validated-on-real-systems / prescriptive-but-anecdotal / aspirational-unvalidated), per this project's existing research discipline.

---

## Part A — Canonical clean-code best practices for FastAPI/Lambda backend + Angular 22/TypeScript frontend

Sourced only from official specs, first-party framework docs, and the two most widely-recognized industry style guides — not generic blog advice.

### Backend: Python / FastAPI / Lambda

**PEP 8 — Style Guide for Python Code.** The official CPython style guide; base target of every Python linter/formatter. `snake_case`/`CapWords`/`ALL_CAPS` naming; grouped imports (stdlib → third-party → local); `is`/`is not` for `None`; never a bare `except:`; consistent return behavior; two blank lines between top-level defs. [peps.python.org/pep-0008](https://peps.python.org/pep-0008/)

**PEP 257 — Docstring Conventions.** Every public module/function/class/method should carry a docstring; one-liners for trivial functions, summary+blank-line+elaboration for non-trivial ones; `"""triple double quotes"""`. [peps.python.org/pep-0257](https://peps.python.org/pep-0257/)

**PEP 20 — The Zen of Python.** "Explicit is better than implicit" (favor Pydantic schemas over raw dicts); "flat is better than nested" (extract helpers from nested box-tree recursion); "errors should never pass silently, unless explicitly silenced" (always handle/log `ClientError`); "there should be one obvious way to do it." [peps.python.org/pep-0020](https://peps.python.org/pep-0020/)

**Google Python Style Guide.** A stricter superset of PEP 8; basis for many enterprise pylint configs. Functions over ~40 lines are a refactor signal; never catch bare `Exception` unless re-raising; type-annotate public signatures (`X | None`, not implicit `Optional`); avoid mutable module-level/global state (matters extra here since Mangum keeps the Lambda execution environment warm across invocations — an immutable global DynamoDB client is fine, a mutable global cache is not without justification); import modules, not individual names; `Args:`/`Returns:`/`Raises:` docstring sections for non-trivial functions. [google.github.io/styleguide/pyguide.html](https://google.github.io/styleguide/pyguide.html)

**Robert C. Martin, *Clean Code* (2008).** The foundational, most-cited craftsmanship text; stack-agnostic. Functions do one thing only; keep functions small; names reveal intent; DRY; exceptions over error codes/null returns; comments explain *why* not *what*; single responsibility per class/module (persistence, business rules, and HTTP transport shouldn't share a function). ISBN 978-0132350884.

**FastAPI official documentation.** First-party, from the framework's creator. `APIRouter` per resource (`app/routers/boxes.py`), not one `main.py`; shared `prefix`/`tags`/`dependencies` at router level; centralized `dependencies.py` with composed sub-dependencies (`get_db` → `get_current_user` → `get_active_user`); `Annotated[Type, Depends(...)]` aliases reused across endpoints; `raise HTTPException` or a single `@app.exception_handler(...)` rather than scattered try/except. [fastapi.tiangolo.com/tutorial/bigger-applications](https://fastapi.tiangolo.com/tutorial/bigger-applications/) · [.../dependencies](https://fastapi.tiangolo.com/tutorial/dependencies/) · [.../handling-errors](https://fastapi.tiangolo.com/tutorial/handling-errors/)

**Pydantic official documentation.** FastAPI's validation layer. Separate `Create`/`Update`/`Read` models per resource (`BoxCreate`/`BoxUpdate`/`BoxRead`), not one shared everything-optional model; `ConfigDict(from_attributes=True)` for mapping DynamoDB-derived objects; `Field(...)` metadata flowing into OpenAPI docs; `@field_validator` for rules types alone can't express (e.g., a box can't parent itself); one aggregated `ValidationError` rather than hand-rolled field errors. [docs.pydantic.dev/latest/concepts/models](https://docs.pydantic.dev/latest/concepts/models/)

### Frontend: Angular 22 / TypeScript

**Angular official style guide & framework docs (angular.dev).** First-party, Google Angular-team-maintained. Hyphenated file names matching the class, feature-folder colocation (not type-folder); standalone is the only component model going forward; `inject()` over constructor injection, `@Service()` over `@Injectable({providedIn:'root'})` in Angular 22; signal-based `input()`/`output()`/`model()` over `@Input()`/`@Output()`; `computed()` for derived state, `effect()` reserved for real side effects; OnPush-by-default requires immutable state updates (load-bearing for the drag-and-drop box canvas — position/parent changes need new object/array references); native `[class]`/`[style]` and `@if`/`@for`/`@switch` over `NgClass`/`*ngIf` etc.; business logic in services, not components. [angular.dev/style-guide](https://angular.dev/style-guide) · [angular.dev/guide/signals](https://angular.dev/guide/signals) · [angular.dev/essentials/dependency-injection](https://angular.dev/essentials/dependency-injection)

**Angular's RxJS-interop guidance (angular.dev).** The closest first-party guidance for RxJS *usage within Angular* (RxJS itself has no independent official style guide). `toSignal()` with an `initialValue` for Observable-based data; don't repeatedly call `toSignal()`/`toObservable()` for the same source; `takeUntilDestroyed()` over manual `ngOnDestroy` teardown; signals as primary state, RxJS only where operator composition is actually needed (e.g., debounced autosave); `async` pipe over manual `.subscribe()`. [angular.dev/ecosystem/rxjs-interop](https://angular.dev/ecosystem/rxjs-interop)

**Google TypeScript Style Guide.** Official, publicly released; basis for strict industry TS linting. Avoid `any`, use `unknown` and narrow (especially at the DynamoDB-item → typed-`Box` boundary); `interface` for object shapes, `type` for unions/tuples; optionality (`?`) at point of use, not baked into shared aliases; default to `private`; `readonly` for constructor-only-assigned properties; no custom decorators. [google.github.io/styleguide/tsguide.html](https://google.github.io/styleguide/tsguide.html)

**TypeScript Handbook — `strict` mode.** Official compiler-team guidance; the "Recommended" setting. Bundles `strictNullChecks`, `noImplicitAny`, `strictPropertyInitialization`, `useUnknownInCatchVariables`, etc. — explicit null handling for box lookups that may miss, mandatory param typing, forced initialization of component/service fields, caught errors typed `unknown` until narrowed. [typescriptlang.org/tsconfig#strict](https://www.typescriptlang.org/tsconfig#strict)

**Airbnb JavaScript/TypeScript Style Guide.** Not an official Angular/TS authority, but the most widely adopted community/industry JS/TS guide (basis for `eslint-config-airbnb`) — included as the general JS-layer baseline. `const` by default, never `var`; never mutate function parameters (return new objects/arrays — exactly what OnPush/signals correctness needs); destructuring; arrow functions for lexical `this` (RxJS callbacks, drag handlers); spread over `Object.assign()`/manual copying for immutable box-tree updates. [github.com/airbnb/javascript](https://github.com/airbnb/javascript)

### Synthesis: universal vs. stack-specific

**Universal (any stack):** intention-revealing names; small single-purpose functions (Google Python's ~40-line signal, *Clean Code* ch.3); DRY; errors surfaced explicitly, never swallowed (PEP 20, Google Python, *Clean Code* ch.7, FastAPI's exception-handler pattern); comments explain *why*; single responsibility at module/class/component level; explicit over implicit; avoid unnecessary mutable shared state (also the literal mechanism OnPush/signals correctness depends on).

**Stack-specific — backend:** PEP 8 mechanics; FastAPI's `APIRouter`/`Depends` conventions; Pydantic's Create/Update/Read split; centralized exception handlers; caution on mutable globals given Mangum's warm-Lambda reuse.

**Stack-specific — frontend:** standalone-only components; Angular 22's `inject()`/`@Service()`/signals idiom; OnPush immutability discipline; RxJS-interop bridge conventions; TypeScript `strict` mode plus Google TS's `interface`/`readonly`/visibility discipline.

**Gap flagged by this research:** none of these canonical sources cover DynamoDB access-pattern-driven code organization specifically — that would need AWS's own DynamoDB Developer Guide, out of scope for this pass since it's a data-modeling concern already settled in `ARCHITECTURE.md`, not a code-organization one.

---

## Part B — Claude/LLM code-generation correctness research

### 1. Constraint decay (verified, with an important correction to prior recollection)

**Source:** Dente, Satriani, Papotti, *"Constraint Decay: The Fragility of LLM Agents in Backend Code Generation,"* arXiv:2605.06445. [abs](https://arxiv.org/abs/2605.06445) · [full text](https://arxiv.org/html/2605.06445v1). **Tier: validated-on-real-systems** (controlled benchmark, arXiv preprint, not yet peer-reviewed).

8 agent configurations × 2 scaffolds, 80 greenfield + 20 feature tasks on a RealWorld Conduit API spec, across 8 backend frameworks; correctness via 291 behavioral test assertions.

- Decay from unconstrained to fully-specified tasks: **~30pp average** (range −17pp to −45pp across configurations).
- Marginal cost per constraint type: Clean Architecture **−9.1±1.6pp**; PostgreSQL **−19.3±2.5pp**; SQLite **−14.3±2.5pp**; SQLAlchemy **−1.5±2.1pp**; Sequelize **−0.6±2.2pp**.
- Framework aggregate pass rates: Express 51.4%, Koa 50.7%, Flask 49.3% vs. **FastAPI 24.2%, Django 25.4%**, Hono 18.5% — a ~25–32pp gap, matching this project's earlier recollected figure.

**Correction to earlier framing:** the paper does **not** conclude "mechanically-checkable constraints help, architectural constraints hurt." It attributes the gap to *implicit vs. explicit* conventions — Express/Koa/Flask win from a minimal, explicit API surface with no implicit conventions; Django is penalized for convention-driven auto-discovery; and **FastAPI is penalized specifically for its type-hint-driven validation machinery**. The low marginal cost of ORM constraints (SQLAlchemy/Sequelize) is *consistent with* "mechanical constraints are cheaper," but the paper never states that as a general principle — that's an inference, not its finding. Load-bearing implication for this project: **the framework already locked in (FastAPI) is this benchmark's second-worst performer, and its own type-hint machinery is implicated as a contributor** — a real tension with this project's existing plan (from ADR-0001's carried-forward items) to lean on typed contracts at slice boundaries. Not a reason to abandon that plan, but a reason not to treat "more types/schemas" as an unqualified win.

### 2. AI-Generated Code Smells — deeper findings

**Source:** Zhu, Tsantalis, Rigby, *"AI-Generated Smells: An Analysis of Code and Architecture in LLM and Agent-Driven Development,"* arXiv:2605.02741. [abs](https://arxiv.org/abs/2605.02741) · [full text](https://arxiv.org/html/2605.02741v1). **Tier: validated-on-real-systems** (static-analysis measurement study, arXiv preprint).

- **Function length:** "Reasoning-Complexity Trade-off" — *more capable* models produced *more* Long-Method violations, not fewer (Qwen-Coder-480B: 11 vs. 1 human baseline across 90 problems). Larger models pile procedural logic into single blocks for edge cases rather than decomposing.
- **Duplication:** framed as "Potential Improper API Usage" — models repeatedly rewrite inline invocation logic instead of extracting reusable helpers ("a critical lack of local abstraction... mirroring a copy-paste coding style"), worst at application-level complexity.
- **Naming and comments: not covered by this paper** — it's scoped to structural/architectural smells only. Don't attribute naming/documentation findings to it.
- **ρ=0.94 "Volume-Quality Inverse Law":** confirmed — near-perfect correlation between total LOC and architectural smells (p<0.001); neither better model accuracy nor refined instructions prevented the degradation.
- **"Modular mirage":** Scattered Functionality + Unstable Dependencies co-occurring — file separation without semantic cohesion.

### 3. Type systems and LLM correctness

No single "Claude pass-rate improves by X% with type hints" study exists. Closest analogues:

- **Type-constrained decoding** (a stronger intervention than prose type hints — enforced during generation): Wei et al., *"Type-Constrained Code Generation with Language Models,"* PACMPL/OOPSLA, arXiv:2504.09246. [PDF](https://arxiv.org/pdf/2504.09246). **Tier: validated-on-real-systems**, peer-reviewed. On TypeScript HumanEval/MBPP: compilation errors cut 75.3% (HumanEval) / 52.1% (MBPP) vs. unconstrained; pass@1 synthesis gains modest (+3.1–8.0pp), but **repair** gains large (+6.5 to +79.4pp HumanEval, +12.6 to +86.7pp MBPP).
- **Type-hint quality on real repos** (not generation correctness per se): TYPYBENCH, arXiv/ICML 2025. [HTML](https://arxiv.org/html/2507.22086v1). **Tier: validated-on-real-systems.** Claude-3.5-Sonnet: TYPESIM 0.788, 127.1 mypy-detectable errors/repo (vs. 141.8 ground truth). Key finding: local type-hint plausibility and repo-level type-*consistency* are different things — a model can write individually-fine hints that don't cohere. Type hints alone don't guarantee mypy-clean code; a checker still needs to be in the loop.
- **Not found:** a controlled study of Claude/Claude Code pass-rate with a mypy/pyright feedback loop vs. without. Flagged as an open gap, not asserted.

### 4. Documentation-as-constraint vs. enforced-linting-as-constraint

Weak evidence base; no head-to-head generation-time study found. Closest: an escholarship thesis on LLMs *detecting* style violations (not generating compliant code) under prose-guideline vs. pretrained-knowledge-only prompts — mixed, language-dependent results (prose guidance helped more for Java, a less-seen style in pretraining, than for Python). **Tier: prescriptive-but-anecdotal, small-scale, and only loosely transferable** to generation-time adherence. [PDF](https://escholarship.org/content/qt9h5637p5/qt9h5637p5.pdf)

### 5. Anthropic's own published guidance

**Tier: validated first-party documentation, prescriptive rather than a controlled experiment.** Source: [code.claude.com/docs/en/best-practices](https://code.claude.com/docs/en/best-practices).

- Direct quote: **"The over-specified CLAUDE.md. If your CLAUDE.md is too long, Claude ignores half of it because important rules get lost in the noise."** Fix: "Ruthlessly prune... delete it or convert it to a hook."
- Explicitly excludes from CLAUDE.md: "standard language conventions Claude already knows," "self-evident practices like 'write clean code.'"
- **"Hooks... Unlike CLAUDE.md instructions which are advisory, hooks are deterministic and guarantee the action happens."**
- "Give Claude a check it can run: tests, a build, a screenshot... Without a check it can run, 'looks done' is the only signal available."

### 6. Multi-turn style drift and over-constraining risk

- **Persona/register drift** (not code-style specifically): Ding et al., *"ContextEcho: A Benchmark for Persona Drift in Long Agentic-Coding Sessions,"* arXiv:2605.24279. [full text](https://arxiv.org/html/2605.24279). **Tier: validated for persona drift, aspirational-unvalidated for code-style drift.** 3 real Claude Code sessions (3,746–9,716 turns), 23 models: +0.72 drift gap on a 0–3 register scale; compaction does **not** reset drift; a single anchor intervention restores it. The paper does not test whether linters/CLAUDE.md rules reduce this — plausible transfer to code-style consistency, but unproven.
- **Over-long CLAUDE.md causing ignored rules:** validated, first-party (item 5 above).
- **Token-cost illustrations of CLAUDE.md bloat** (e.g., a worked example showing ~10x cost difference between a fully-cached vs. mid-session-invalidated 4,000-token CLAUDE.md): **tier: aspirational-unvalidated, illustrative arithmetic only**, not measured production data — cite only as illustration, never as a finding.
- **"Excessive rule-following degrades reasoning about correctness" in code generation:** **no source found.** Flag as an assumption if used, not a citable fact.
- **A concrete counter-example already in hand:** FastAPI's type-hint-driven validation correlating with the *worst* measured backend correctness score (item 1) — real, sourced evidence that "more explicit/typed constraints = better" is not a safe universal assumption.
- **Bonus, smaller-scale datapoint:** *"Comparing Human and LLM Generated Code: The Jury is Still Out!"*, arXiv:2501.16857. [PDF](https://arxiv.org/pdf/2501.16857). **Tier: validated but small-n (72 tasks, 1 human baseline).** GPT-4: 85% missing complete docstrings (vs. 78% human — both bad); 72 naming violations vs. 65 human; average cyclomatic complexity 5.0 vs. 3.1 human (61% higher, attributed to defensive over-engineering); import/dependency errors in 55% of files vs. 40% human.

### Evidence-tier summary

| # | Topic | Best source | Tier | Key number |
|---|---|---|---|---|
| 1 | Constraint decay | arXiv:2605.06445 | Validated (benchmark) | FastAPI 24.2%, Django 25.4% vs. Flask 49.3%; Clean Architecture −9.1pp |
| 2 | AI code smells | arXiv:2605.02741 | Validated (static analysis) | ρ=0.94 LOC↔smells; naming/comments not covered |
| 3 | Types & correctness | arXiv:2504.09246, TYPYBENCH | Validated (benchmark) | Type-constrained decoding: −75.3% compile errors; repair pass@1 +6.5–79.4pp |
| 4 | Docs vs. linting | escholarship thesis | Prescriptive-but-anecdotal | Language-dependent; no generation-time head-to-head found |
| 5 | Anthropic guidance | code.claude.com/docs | Validated (first-party, prescriptive) | Over-specified CLAUDE.md → rules ignored (explicit quote) |
| 6 | Drift / over-constraining | arXiv:2605.24279 | Validated (persona), unvalidated (code-style) | +0.72 drift gap; persists through compaction; mitigation untested |

Not found / explicitly flagged as gaps, not facts: a Claude-specific mypy/pyright-feedback-loop pass-rate study; a direct prose-vs-enforced-linting generation-time comparison; any study that excessive rule-following degrades code-generation reasoning.