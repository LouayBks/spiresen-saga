ADR-0005: AWS identity and credential strategy for infra work

Status: Accepted. Date: 2026-09-15. Scope: two decisions — (1) credential mechanism for
local/interactive Terraform work (human + Claude, since Claude holds no AWS identity
independent of the shell it runs in — see below), (2) credential mechanism for CI's
automated `terraform apply` step (#11's `infra-deploy.yml`).

This ADR states the decision and reasoning only, per the same split ADR-0002/0003 use
against their companion process docs. Concrete console steps, IAM policy JSON, and the
literal setup sequence belong in `DOC/guides/infra_setup.md` — not duplicated here.

Context and objective

#10/#11 (`DOC/architecture/application_architecture.md`, `branching_strategy.md` AW-24)
are the first tickets where Terraform actually calls the AWS API — `terraform plan`/`apply`
need a real credential, not just local file edits. Two distinct call sites need one, with
different constraints: a human running Terraform locally (with Claude in the same shell,
per the note below) and GitHub Actions running `terraform apply` unattended on push to
`main`.

Claude has no AWS identity of its own in this project. Terraform invoked via Claude Code's
Bash tool inherits whatever credential chain is already active in the same local
shell/environment as the human driving the session — there is no separate "Claude"
principal to provision. This matters directly for the decision below: provisioning "for
Claude" and provisioning "for the human at the keyboard" are the same action, not two, for
the local/interactive case. This was surfaced only mid-conversation, after an earlier reply
in this same working session initially treated "Claude's AWS access" as if it were a
separate provisioning question — flagged here so it isn't reintroduced as a live confusion
later.

Decision — local/interactive work: AWS IAM Identity Center (SSO), not a static IAM user
access key

Use `aws sso login` against an IAM Identity Center permission set, not a long-lived IAM
user access key pair, for any Terraform command run locally (by the human, or by Claude in
that same shell). AWS's own IAM best-practices guidance names long-term access keys for
human identities as the pattern to actively move away from — no built-in expiry, no MFA
tie-in, and a leaked key (a stray git commit, a log line, a wrong paste) stays a standing
open door until someone notices and manually revokes it.

The real cost of this choice is CLI/SDK session duration: 8 hours by default, after which
an interactive browser re-login is required — a step Claude cannot perform unattended,
since it's a redirect-based human auth flow, not a scriptable one. This is a tunable dial,
not a fixed cost: IAM Identity Center administrators can set CLI/SDK session duration
anywhere from 15 minutes up to 90 days (the cap was raised from 7 days in September 2023).
Set it short for tighter security posture, or long (weeks/months) for a low-friction
solo-project workflow — either way, the session still has a hard expiry and can be
centrally terminated from the console at any time, properties a static key doesn't have
regardless of how any duration is tuned.

Rejected: a static IAM user access key for this case. It would remove the session-refresh
friction entirely — no browser step ever blocks a Terraform call — but rejected anyway,
because the entire point of this decision is removing a standing, non-expiring secret from
the local machine. Trading that away for convenience defeats the decision before it's made.

Decision — CI's automated apply: direct GitHub OIDC → IAM role, not Identity Center, not a
static key

GitHub Actions authenticates to AWS via OpenID Connect federation directly to a scoped IAM
role (`infra-deploy.yml`'s `aws-actions/configure-aws-credentials` step), with a trust
policy restricted to `repo:LouayBks/spiresen-saga:ref:refs/heads/main`. No AWS credential
of any kind is stored as a GitHub secret for this path.

Rejected: routing CI through IAM Identity Center too, on the assumption that one identity
system for every consumer is inherently simpler than two. It isn't available here — Identity
Center authenticates a human through a browser redirect; there is no human present during
an unattended CI run for it to authenticate. This isn't a configuration gap to work around,
it's what the product is for — Identity Center and workload-identity federation solve
different problems by design. OIDC-to-IAM-role federation is AWS's and GitHub's documented
pattern for exactly this non-interactive case, and needs no session or rotation once its
one-time setup (OIDC provider + role trust policy) is done: a workflow run mints and burns
its own token in minutes, and nothing is left standing between runs.

Consequences and limitations

- Two separate credential mechanisms exist for two separate call sites — this is not one
  unified "AWS identity for the project," and shouldn't be described as one. Documenting
  them together (this ADR, and the companion `DOC/guides/infra_setup.md`) is what keeps
  that distinction from being lost again — it already blurred once in this project's own
  history, in the same conversation that produced this decision.
- The local/interactive session-duration dial is a real security/friction trade-off
  explicitly left to Lou's judgment, not resolved here to a specific number —
  `infra_setup.md` documents how to set it, not what value is "correct" for this project.
- This ADR formalizes a decision `DOC/setup/claude_code_setup.md` (section C, C1-C3) already
  stated inline, without a dedicated ADR behind it — written here per this project's own
  pointer discipline (AW-14: decisions and reasoning belong in `ADR/`, not scattered through
  a setup guide). That file's concrete commands and policy JSON stay where they are; nothing
  here duplicates them.
- Least-privilege scoping of the actual IAM policies (the deploy role, the local permission
  set) is a mechanical detail, not re-litigated here — see `infra_setup.md` for the policy
  documents actually used, scoped to what #10/#11 touch today (Route 53, ACM, the Terraform
  state S3 bucket), narrower than the Lambda/DynamoDB/Cognito surface named in
  `claude_code_setup.md` C3, which applies once the `api` module (a later ticket) exists.
- No AWS Organizations dependency: IAM Identity Center works standalone for a single-account
  setup — this decision doesn't assume or require multi-account structure, which this
  project doesn't have.
