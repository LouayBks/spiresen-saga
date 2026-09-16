ADR-0005: AWS identity and credential strategy for infra work

Status: Accepted. Date: 2026-09-15, revised 2026-09-16. Scope: three decisions — (1)
credential mechanism and permission baseline for the human admin's local/interactive
Terraform work, (2) credential mechanism for CI's automated `terraform apply` step (#11's
`infra-deploy.yml`), (3) a separate, read-only credential for Claude, distinct from (1) —
added in the 2026-09-16 revision, which also replaces (1)'s original per-ticket baseline.

Revision note (2026-09-16): the original version of this ADR (a) scoped the admin's
permission set narrowly to only what tickets #10/#11 touch, intending to extend it
ticket-by-ticket as later infra tickets land, and (b) had Claude inherit that same
admin session wholesale, reasoning that "Claude holds no AWS identity independent of the
shell it runs in." Both are revised below: (a) was unrealistic in practice — every new
service touched (IAM identity-provider listing, SAML listing, trust-policy edits, and so
on for every future service) forced a console round-trip to hand-edit the inline policy
before work could continue, for no real security benefit since the admin is also the one
approving their own policy edits. (b) was a non-sequitur: "Claude has no *separate*
principal today" does not imply "Claude should share the admin's write-capable session" —
it only meant nobody had provisioned an alternative yet. The blast-radius argument for
narrow scoping was real, but it applies to bounding *Claude's* reach, not the human
admin's.

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

Claude has no AWS identity of its own in this project yet. Terraform invoked via Claude
Code's Bash tool inherits whatever credential chain is already active in the same local
shell/environment as the human driving the session — there is no separate "Claude"
principal provisioned so far. This was surfaced only mid-conversation, after an earlier
reply in this same working session initially treated "Claude's AWS access" as if it were a
separate provisioning question — flagged here so it isn't reintroduced as a live confusion
later. (2026-09-16: this was later revisited — see the "Claude gets its own read-only
identity" decision below. "No separate principal exists today" turned out not to imply
"Claude should permanently share the admin's write session"; it only meant nobody had
built the alternative yet.)

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

Decision (revised 2026-09-16) — the admin's permission baseline is the full known stack,
granted once, not extended per ticket

The `spiresen-infra-admin` permission set is scoped to every AWS service
`DOC/architecture/application_architecture.md` already names as part of this project's
stack — Route 53, ACM, S3 (Terraform state, the compiled frontend bucket, and media),
CloudFront, DynamoDB, Lambda, API Gateway (HTTP API), and Cognito — plus IAM actions
needed to create and manage this project's own roles, inline policies, and OIDC provider
(never IAM privileges beyond that project-scoped surface). Full read/write is granted for
all of it now, in one policy, rather than split into a read tier and a later write
extension: the admin is the one provisioning resources as each ticket lands, and gating
their own write access behind a self-approved policy edit adds a console round-trip with
no separation-of-duties benefit, since there's no second approver in a solo project.

"Extend later" still applies, but only to services genuinely outside today's documented
stack — e.g. `application_architecture.md`'s mention of heavier compute for a future
"agentic playroom" subdomain, or any AI/ML service adopted after this ADR. A service
already named in the architecture doc is baseline, not an extension.

Rejected: the original per-ticket-narrow-then-extend model from this ADR's first version.
It was intended to bound blast radius, but in practice it only added friction for the
admin — every new service touched meant re-authenticating as an elevated identity to
hand-edit an inline policy before work already planned in the architecture doc could
proceed. The actual blast-radius concern this was trying to address belongs to the Claude
credential decision below, not the admin's own.

Decision (new, 2026-09-16) — Claude gets its own read-only identity, separate from the
admin's session; not yet built

Going forward, Claude should authenticate to AWS as its own principal — a read-only IAM
Identity Center permission set (or read-only IAM role), scoped to this project's resources,
never sharing the admin's write-capable `spiresen-infra-admin` session. Claude should never
be able to directly mutate AWS state through its own credential; `terraform apply` and any
console/CLI write action stay a human-driven action per AW-24, and a read-only identity
makes that a property of the credential itself, not just of process discipline.

This is a decision to build, not yet a completed setup — `infra_setup.md` doesn't yet have
the walkthrough steps for provisioning it. Until it exists, Claude continues to inherit
whatever credential is active in the shell (today, the admin's `spiresen-dev`/equivalent
profile) exactly as the original version of this ADR described. That's a known, temporary
gap, not a silent inconsistency: the fix is scoped follow-up work (a new permission set,
`aws configure sso` profile for Claude, and instructions for which profile Claude's shell
commands should use), not a same-day change.

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

- Three separate credential mechanisms exist for three separate consumers — admin
  interactive (broad, project-stack-scoped), Claude interactive (read-only,
  project-stack-scoped, not yet built), and CI's automated apply (OIDC-federated role) —
  this is not one unified "AWS identity for the project," and shouldn't be described as
  one. Documenting them together (this ADR, and the companion `DOC/guides/infra_setup.md`)
  is what keeps that distinction from being lost again — it already blurred once in this
  project's own history, twice now across the original decision and this revision.
- The local/interactive session-duration dial is a real security/friction trade-off
  explicitly left to Lou's judgment, not resolved here to a specific number —
  `infra_setup.md` documents how to set it, not what value is "correct" for this project.
- This ADR formalizes a decision `DOC/setup/claude_code_setup.md` (section C, C1-C3) already
  stated inline, without a dedicated ADR behind it — written here per this project's own
  pointer discipline (AW-14: decisions and reasoning belong in `ADR/`, not scattered through
  a setup guide). That file's concrete commands and policy JSON stay where they are; nothing
  here duplicates them.
- Least-privilege scoping of the actual IAM policies (the deploy role, the admin permission
  set) is a mechanical detail, not re-litigated here — see `infra_setup.md` for the policy
  documents actually used. As of the 2026-09-16 revision, the admin's baseline already
  covers the full Route 53/ACM/S3/CloudFront/DynamoDB/Lambda/API Gateway/Cognito surface
  named in `application_architecture.md`, which supersedes the original narrower scoping
  this bullet used to describe (and the `claude_code_setup.md` C3 surface it pointed to as
  a future extension is now part of the baseline, not deferred).
- Claude's read-only identity (the new decision above) is unbuilt as of this revision — its
  own setup steps, once written, belong in `infra_setup.md` alongside the admin's, and this
  bullet should be updated to point at them once that work lands.
- No AWS Organizations dependency: IAM Identity Center works standalone for a single-account
  setup — this decision doesn't assume or require multi-account structure, which this
  project doesn't have.
