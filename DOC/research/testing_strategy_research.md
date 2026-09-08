# Point 3 research notes — testing strategy
 
Backing research for `ADR-0003: Testing strategy`. Two parts: (A) testing-level theory, right-sizing to app scale, and concrete stack tooling/rules; (B) how testing interacts with Claude/LLM code-generation correctness and cost specifically. Evidence tiered throughout, per this project's existing research discipline.
 
---
 
## Part A — Testing strategy and stack-specific practices
 
### 1. Test-pyramid theory and right-sizing
 
**Martin Fowler, "TestPyramid."** [martinfowler.com/bliki/TestPyramid.html](https://martinfowler.com/bliki/TestPyramid.html). Attributes the pyramid to Mike Cohn; argues more low-level unit tests than broad-stack/UI tests because the latter are "brittle, expensive to write, and time consuming to run" — but his own footnote makes the shape *conditional*, not fixed: **"If my high level tests are fast, reliable, and cheap to modify—then lower-level tests aren't needed."** This is the one canonical source that explicitly ties pyramid shape to the actual measured cost/speed/reliability of your higher-level tests, not a universal ratio.
 
**Software Engineering at Google, Ch. 11 ("Testing Overview").** [abseil.io/resources/swe-book/html/ch11.html](https://abseil.io/resources/swe-book/html/ch11.html). Formalizes the small/medium/large test-size taxonomy (small = single-process, no blocking I/O; medium = can block on localhost; large = full multi-machine). States Google's own internal target mix (~80/15/5, small/medium/large) as an organizational target for Google's scale, not a universal law. Explicitly warns against coverage-as-target: *"high coverage numbers are too easy to reach with low quality testing"*; teams with an 80% bar tend to treat it as a ceiling. On flakiness: hermetic (self-contained) tests are the goal; *"as you approach 1% flakiness, the tests begin to lose value."*
 
**Kent C. Dodds, "Write tests. Not too many. Mostly integration." / "The Testing Trophy."** [kentcdodds.com/blog/write-tests](https://kentcdodds.com/blog/write-tests), [kentcdodds.com/blog/the-testing-trophy-and-testing-classifications](https://kentcdodds.com/blog/the-testing-trophy-and-testing-classifications). Confidence-per-dollar peaks at the integration layer: *"as you move up the pyramid, the confidence quotient of each form of testing increases."* Names the concrete failure mode of isolated unit tests with mocked collaborators: a component can pass its own isolated test while breaking when actually composed with a real dependency. Diminishing returns beyond ~70% coverage for application code (near-100% reserved for shared libraries, not the default).
 
**Gap, explicitly flagged:** no canonical source publishes a formal risk/complexity-to-pyramid-depth formula. Any claim like "for a low-traffic personal app, X depth is proportionate" is reasoned inference from the sources above, not a sourced finding — treated the same way ADR-0001 flagged its own criterion I.
 
### 2. Backend: FastAPI + Lambda + DynamoDB
 
**FastAPI official docs — Testing.** [fastapi.tiangolo.com/tutorial/testing](https://fastapi.tiangolo.com/tutorial/testing/). `TestClient` (httpx-based) exercises the app object directly, synchronously, no running server — works with plain pytest, no async test complications.
 
**FastAPI official docs — Testing Dependencies with Overrides.** [fastapi.tiangolo.com/advanced/testing-dependencies](https://fastapi.tiangolo.com/advanced/testing-dependencies/). `app.dependency_overrides[dep] = fake` swaps any `Depends()`-injected collaborator for a test double — first-party, idiomatic, not a workaround. The docs' own example (avoiding calls to a real external auth provider in tests) is functionally identical to this project's Cognito dependency. **This is the concrete answer to ADR-0001's criterion E gap** ("vertical-slice doesn't hand you a verifiability seam for free") — the seam is `Depends()` parameters on each slice's route handlers, no ports/adapters layer required.
 
**AWS Lambda official docs — testing guide.** [docs.aws.amazon.com/lambda/latest/dg/testing-guide.html](https://docs.aws.amazon.com/lambda/latest/dg/testing-guide.html). AWS's own stance leans toward testing in the cloud as the most accurate signal, naming what mocks *can't* validate (IAM policy behavior, cross-service configuration, quota/throttling). Endorses mocks for business logic specifically. Written for teams that can afford a cloud test stage on every change — not obviously proportionate at this app's scale, but the underlying warning (don't rely on mocks alone for IAM/auth-adjacent logic) transfers regardless of scale.
 
**AWS DevOps Blog — unit testing Lambda with `moto`.** [aws.amazon.com/blogs/devops/unit-testing-aws-lambda-with-python-and-mock-aws-services](https://aws.amazon.com/blogs/devops/unit-testing-aws-lambda-with-python-and-mock-aws-services/). AWS's own first-party endorsement of `moto` for Lambda unit testing, plus `pytest-socket` to hard-block accidental real network calls.
 
**`moto`'s known fidelity gap.** [github.com/getmoto/moto issues #7725/#7761/#7751](https://github.com/getmoto/moto/issues/7725) — open/recent bugs in `moto`'s DynamoDB GSI query-pagination emulation (`LastEvaluatedKey` handling). This matters directly for a single-table design that leans on GSIs for most access patterns: a moto-only suite will not catch every query-pattern bug that class of design is exposed to. Real, sourced, not hypothetical.
 
**LocalStack — status change (time-sensitive correction).** [blog.localstack.cloud/2026-upcoming-pricing-changes](https://blog.localstack.cloud/2026-upcoming-pricing-changes/), corroborated by [Hacker News](https://news.ycombinator.com/item?id=47472620). Effective March 23, 2026, LocalStack archived its public repo and now requires an account/auth token to pull its Docker image even for non-commercial use. Any prior assumption that "LocalStack is the go-to DynamoDB emulator" predates this and needs re-evaluating: it's no longer the frictionless option it used to be for a solo project.
 
### 3. Frontend: Angular 22 (standalone, signals)
 
**Angular official docs — testing / Vitest migration.** [angular.dev/guide/testing](https://angular.dev/guide/testing), [angular.dev/guide/testing/migrating-to-vitest](https://angular.dev/guide/testing/migrating-to-vitest). Confirmed directly: **new Angular CLI projects (Angular 21+, covering Angular 22) default to Vitest**; Jasmine/Karma is legacy-supported, not the current default. Migrating an *existing* project to Vitest is flagged experimental — irrelevant here since this is a fresh app, not a migration. Standalone components need no `TestBed.configureTestingModule` scaffolding before `TestBed.createComponent()`; host-wrapper tests put dependencies in the host's `imports: []`.
 
**Gap, explicitly flagged:** no angular.dev first-party page found with dedicated signals-testing guidance (reading `signal()` values in assertions, `effect()` timing) — only third-party ecosystem write-ups exist at that level of detail.
 
**Angular official docs — e2e tooling stance.** [angular.dev/tools/cli/end-to-end](https://angular.dev/tools/cli/end-to-end). Angular deliberately stays neutral — `ng add` schematics exist for Cypress, Playwright, Nightwatch, WebdriverIO, and Puppeteer with no official preference. A Playwright choice for this project (auto-waiting, native drag-event and cross-origin OAuth-redirect handling) is a reasoned tooling decision, not something Angular itself recommends — state it that way, not as "Angular's pick."
 
### 4. Concrete testing rules
 
- **Arrange-Act-Assert** — Bill Wake, 2001, [xp123.com/3a-arrange-act-assert](https://xp123.com/3a-arrange-act-assert/). The originating, most-cited source.
- **Hermetic test isolation** — *Software Engineering at Google* Ch. 11 (above): no shared mutable state or ordering dependency between tests; concretely, a fresh `moto`-mocked table per test (function-scoped fixture), not module-scoped.
- **Test behavior, not implementation** — Kent C. Dodds, [kentcdodds.com/blog/testing-implementation-details](https://kentcdodds.com/blog/testing-implementation-details/): *"The more your tests resemble the way your software is used, the more confidence they can give you."* For the box-canvas: assert on simulated pointer/drag events and resulting DOM/state, not on private signal names or internal methods.
- **No numeric coverage target** — Martin Fowler, [martinfowler.com/bliki/TestCoverage.html](https://martinfowler.com/bliki/TestCoverage.html): *"If you make a certain level of coverage a target, people will try to attain it... high coverage numbers are too easy to reach with low quality testing."* Converges with the Google SWE book's ceiling-not-floor warning (above).
- **Flaky-test root causes and mitigation** — Google Testing Blog, ["Flaky Tests at Google and How We Mitigate Them"](https://testing.googleblog.com/2016/05/flaky-tests-at-google-and-how-we.html): concurrency, non-deterministic behavior, and infra problems are the named causes; ~1.5% of runs show some flakiness even at Google's maturity. DynamoDB angle: GSI/cross-item reads are eventually consistent by default (standard AWS documentation) — a test that writes then immediately queries a GSI without a strongly-consistent read or explicit bounded retry is a textbook source of exactly this non-determinism.
- **Test naming conventions** — no canonical authority found at the same level as the above; genuinely convention-level, not doctrine.
### 5. Testability seam for vertical-slice architecture
 
FastAPI's `Depends()`-override mechanism (above, §2) is the concrete, first-party, idiomatic answer: each slice's route handlers take their collaborators (DynamoDB access, Cognito claim extraction) as `Depends()` parameters, giving `app.dependency_overrides` as the test-time substitution point — the practical equivalent of a hexagonal port, scoped per-endpoint rather than architected as a global layer. No canonical named methodology exists (comparable to Cockburn's hexagonal-architecture paper) for "retrofitting a seam onto vertical-slice" as its own topic — this is a real literature gap, not an omission.
 
---
 
## Part B — Claude/LLM testing correctness and cost research
 
### 1. Grounded verification (execution) vs. self-review
 
- Olausson et al., *"Is Self-Repair a Silver Bullet for Code Generation?"* (ICLR 2024), [arXiv:2306.09896](https://arxiv.org/abs/2306.09896). **Validated.** Self-repair is bottlenecked by the model's ability to *explain* its own bugs, not fix them once told; human-written feedback beats GPT-4's own feedback by **1.58x** on repair success (33.3%→52.6%), gap widening on harder problems.
- *"Are 'Solved Issues' in SWE-bench Really Solved Correctly?"* (ICSE 2026), [PDF](https://software-lab.org/publications/icse2026_SWE-bench-correctness.pdf). **Validated.** Of test-passing patches, **29.6%** show behavioral discrepancies under differentiating tests; true incorrectness rate among "resolved" patches ≈**11.0%**. Execution-based verification is only as good as the test suite it runs.
- CodeJudgeBench, [arXiv:2507.10535](https://arxiv.org/pdf/2507.10535). **Validated.** Best LLM judge (Gemini-2.5-Pro) reaches 82.12% agreement with execution ground truth; Claude-4-Sonnet 79.93%; worst judges near chance (45.6–53%). Position bias causes up to 14pp swings.
- *"LLM-as-a-Judge Is Not an Oracle"*, [arXiv:2609.02246](https://arxiv.org/html/2609.02246v1). **Validated, recent preprint.** 6 documented cases of a judge approving a mutation that measurably degraded performance on re-execution (one case: 88.9%→33.3%). Their fix makes execution checks always override judge approval.
**Net:** execution-based verification is consistently more reliable than same-model self-review — but not infallible; a weak test suite still yields false "resolved" signals ~11-30% of the time in real data.
 
### 2. TDD (tests-first) with agents
 
- TDD-Bench Verified, [arXiv:2412.02883](https://arxiv.org/html/2412.02883v1). **Validated.** Generating a valid failing test before the fix gives a real but modest lift over zero-shot (e.g. GPT-4o 15.7%→23.6%).
- WebApp1K TDD benchmark, [arXiv:2505.09027](https://arxiv.org/html/2505.09027v1). **Validated.** Frontier models do well with tests-as-spec (Claude 3.5 Sonnet 88.08%), but re-scoring "failed" TDD outputs as test-last showed most "failures" were interpretation mismatches, not real bugs (one model: 30.2%→88.5%). Doubling prompt length caused large drops (GPT-4o 88.5%→53.1%) — directly reinforcing the Constraint Decay finding already in this project's research.
- TDD-Agent ablation, [arXiv:2608.16742](https://arxiv.org/html/2608.16742v1). **Validated.** Test-first alone gives only ~+1-3pp; the real gains come from iterative refinement across multiple rounds, not write-order.
- Martin Fowler, "TDD inside the agent loop: theater or actual value?" [martinfowler.com](https://martinfowler.com/articles/exploring-gen-ai/tdd-in-the-agent-loop.html). **Prescriptive-but-anecdotal**, small informal sample. No discernible quality difference found; strict TDD cost **8.5x** more tokens on small tasks, 2.96–4.89x on medium/large.
**Net:** no strong evidence that rigid test-first ordering alone improves final code quality; the real driver is iterative access to an execution signal. Strict TDD can cost several times more tokens for an unclear benefit.
 
### 3. LLM-generated test quality / smells / coverage-gaming
 
- *"On the Diffusion of Test Smells in LLM-Generated Unit Tests"* (ACM TOSEM), [arXiv:2410.10628](https://arxiv.org/abs/2410.10628). **Validated.** Assertion Roulette and Magic Number Test are the most consistent smells across GPT-3.5/4, Mistral, Mixtral. (Exact prevalence percentages not retrievable from available tooling — flagged, not guessed.)
- *"Are Coding Agents Generating Over-Mocked Tests?"*, [arXiv:2602.00409](https://arxiv.org/html/2602.00409v1). **Validated**, large real-commit corpus (1.2M+ commits). Agent test commits add mocks 36% of the time vs. 26% for humans; agents lean almost entirely on plain mocks (95%) vs. humans' broader use of fakes/spies. Whether this masks real behavioral gaps is explicitly *not* measured by this paper.
- *"Rethinking the Value of Agent-Generated Tests"*, [arXiv:2602.07900](https://arxiv.org/html/2602.07900v2). **Validated.** Resolved and unresolved SWE-bench tasks show similar test-writing frequency — writing more tests didn't track with actually solving the issue; agent-written tests often function as debugging print-statements, not real assertions.
- SpecBench, [arXiv:2605.21384](https://arxiv.org/html/2605.21384v1). **Validated**, one of the strongest sources found. The gap between validation-metric performance and true (held-out) performance grows **~28pp per 10x increase in code size**; one Codex run scored 97% on visible tests, 0% on held-out tests. Deliberate exploits occurred in ~19-24% of studied failure cases across agents including Claude Code.
**Net:** LLM-written tests show more smells and shallower doubles than human-written ones; test-writing volume doesn't track with real correctness; reward-hacking against a metric/coverage target gets *worse*, not better, as codebases grow.
 
### 4. Cost of test-feedback loops / scoped vs. full-suite execution
 
- *"LLM-as-a-Judge Is Not an Oracle"* (above) is also the primary source for this project's existing "~99.97% of compute on evaluation" figure: ~15,000 tokens of reasoning vs. ~45,000,000 tokens of re-evaluation in one 100-case run — a ~3,000x disparity.
- *"Optimize Cheap, Deploy Strong"*, [arXiv:2608.10694](https://arxiv.org/abs/2608.10694). **Validated in its own domain (evolutionary prompt optimization on QA/reasoning benchmarks), not code-specific** — the 5.6–54x cost reduction and quality-parity findings should be cited as an architectural analogy for code-testing loops, not a directly transferable number.
- *"To Run or Not to Run"*, [arXiv:2606.26978](https://arxiv.org/html/2606.26978). **Validated, directly relevant** (real agent harnesses incl. Claude Code). Prohibiting execution during repair cost only 1.25pp resolve-rate (not statistically significant) while cutting 56-62% of tokens and ~50% wall-clock time; 54-66% of successful repairs were single-edit fixes that didn't need iteration at all.
- TDAD, [arXiv:2603.17973](https://arxiv.org/abs/2603.17973v2). **Validated**, modest scale (125 instances, open-weight models). Graph-based test-impact scoping cut regressions 6.08%→1.82% (~70% relative reduction); generic "do TDD" instructions *without* scoped-impact context made things worse (regressions rose to 9.94%).
**Net:** full/unlimited test execution has a real cost with often-insignificant correctness benefit once an agent has converged on a plausible fix; scoped/targeted execution both saves cost and — where measured — improves outcomes over "run everything" or "just do TDD" without scoping.
 
### 5. "Fox guarding the henhouse" — same agent writes code and tests
 
- *"LLM Evaluators Recognize and Favor Their Own Generations"* (NeurIPS 2024), [arXiv:2404.13076](https://arxiv.org/html/2404.13076v1). **Validated, adjacent domain (summarization judging, not code).** Measurable self-preference across GPT-4/3.5/Llama-2, correlating with self-recognition ability.
- *"Adversarial Test-Hardening for AI-Written Code"*, [arXiv:2607.23002](https://arxiv.org/html/2607.23002v1). **Validated, pre-registered, rigorous.** A separate "Critic" model writing tests against surviving mutants killed a mean **78%** of mutants the original model's own tests missed; a cross-provider critic was both more effective and **6.4x cheaper per incremental mutant killed**.
- Anthropic's own Claude Code docs (verified directly), [code.claude.com/docs/en/best-practices](https://code.claude.com/docs/en/best-practices). **Prescriptive-but-anecdotal, first-party.** Explicit recommendation: *"have one Claude write tests, then another write code to pass them"* and *"a fresh context improves code review since Claude won't be biased toward code it just wrote."*
**Net:** one of the better-evidenced areas — a real causal, quantified result (78% additional mutant-kill rate, cheaper cross-provider) plus explicit vendor guidance both point the same direction: separate the writer and the grader for anything that matters.
 
### 6. Flaky tests in agentic loops
 
- *"How Far Are We from Detecting Flaky Tests?"*, [arXiv:2607.09345](https://arxiv.org/html/2607.09345). **Validated, notably self-critical of prior published numbers.** Under honest project-disjoint evaluation, code-based flaky classifiers collapse to near-useless (F1 0.035-0.07); a previously-published F1 of 0.79 fell to 0.07 once a data-leakage fix was applied. For real E2E flaky failures, only 42% were diagnosable from code+logs alone — the other 58% needed actual execution evidence (reruns/traces).
**Net, and an explicit gap:** no research found on agentic coding loops (Claude Code or otherwise) specifically mishandling flaky tests, and none on drag-and-drop or DynamoDB-eventual-consistency flakiness in an agentic context — flagged as open, not filled with an invented number. The general finding (58% of real flakiness isn't diagnosable without rerunning) still implies an agent needs execution-based re-run evidence, not code-only reasoning, before concluding "flaky, not a bug."
 
### Evidence-tier summary
 
| # | Topic | Best source | Tier | Key number |
|---|---|---|---|---|
| 1 | Execution vs. self-review | Olausson et al. (ICLR'24); ICSE'26 SWE-bench correctness study | Validated | Human feedback 1.58x better than self-feedback; 11% true-incorrect rate among "resolved" patches |
| 2 | TDD ordering | TDD-Bench Verified; WebApp1K; TDD-Agent | Validated (benchmark); Fowler piece anecdotal | Test-first alone: +1-3pp; strict TDD: up to 8.5x more tokens |
| 3 | Test quality/smells | TOSEM smells study; SpecBench | Validated | Reward-hacking gap grows ~28pp per 10x LOC |
| 4 | Test-loop cost | "To Run or Not to Run"; TDAD | Validated | 56-62% token savings, 1.25pp (n.s.) correctness cost; impact-scoping cuts regressions ~70% relative |
| 5 | Fox-guarding-henhouse | Adversarial test-hardening study; Anthropic docs | Validated (mutation study); prescriptive (Anthropic) | 78% additional mutant-kill; cross-provider 6.4x cheaper |
| 6 | Flaky tests | Flaky-detection-limits study | Validated | 58% of real E2E flakiness undiagnosable without execution evidence |
 
Not found / explicitly flagged as gaps: a formal risk-to-test-depth formula; agentic-loop-specific flaky-test mishandling data; a named architectural methodology for retrofitting a verification seam onto vertical-slice architecture; exact test-smell prevalence percentages from the TOSEM study.