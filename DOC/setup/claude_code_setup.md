# Claude Code setup — plugins, GitHub integration, AWS credentials, permissions

The last piece before wiring point 4's decisions into the actual repo. This is a configuration reference, not a decision record — where a real choice exists (OIDC vs. static keys, which GitHub App scope) it's made directly against current AWS/GitHub/Anthropic best practice rather than scored, since these aren't close calls. Everything below was checked against live documentation on 2026-09-08; a few items are flagged for you to confirm directly in a live session or against `awslabs/mcp` (robots-blocked from automated fetch).

## A. Plugins

| Plugin | Install | Notes |
|---|---|---|
| `typescript-lsp` | `/plugin install typescript-lsp@claude-plugins-official` | Covers the Angular frontend (Angular is TypeScript — no separate Angular-template LSP plugin exists). Requires `typescript-language-server` installed separately (`npm i -g typescript-language-server`) — the plugin installs the client config, not the binary. |
| `pyright-lsp` | `/plugin install pyright-lsp@claude-plugins-official` | Covers the FastAPI backend. Requires `pyright` installed separately (`pip install pyright` / `pipx install pyright`). |
| `security-guidance` | `/plugin install security-guidance@claude-plugins-official` | Runs a vulnerability review after each change — a reasonable structural fit alongside TS-17/AW-4's high-risk-logic review, though it's a generic scan, not a substitute for those scoped rules. |

**No official Anthropic plugin exists for Terraform or AWS.** A HashiCorp-published Terraform plugin appears in Claude's plugin directory (`claude.com/plugins/terraform`) but its exact marketplace/install string couldn't be confirmed from a page fetch — **confirm live via `/plugin` → Discover → search "terraform" before relying on it.**

**AWS/Terraform tooling is wired as MCP servers instead**, published by AWS Labs (`github.com/awslabs/mcp`, AWS's own org):

```bash
# Terraform: Checkov security scanning + AWS best-practice guidance
claude mcp add terraform-mcp -- uvx awslabs.terraform-mcp-server@latest

# AWS's newer hosted MCP server (preferred over the older aws-api-mcp-server package,
# which AWS's own docs say is superseded by this one)
claude mcp add-json aws-mcp --scope user \
  '{"command":"uvx","args":["mcp-proxy-for-aws==1.6.0","https://aws-mcp.us-east-1.api.aws/mcp","--metadata","AWS_REGION=us-west-2"]}'
```

Pin exact package versions against `awslabs/mcp`'s current releases before committing these to `.claude/settings.json` — the fetch above couldn't confirm current version numbers directly (GitHub blocked automated fetch of that repo).

**Note on cloud sessions**: Claude Code running in a cloud/web session doesn't start plugin language servers at all — LSP-based discovery (AW-16/AW-17) only applies to local interactive sessions.

**Documentation lookup — Context7.** One naming check first: you asked for "Context8" — the real, official tool is **Context7**, published by Upstash. A "Context8" exists only as an unofficial community fork of Context7 with no meaningful difference from the original, so this is Context7 under the name you had. It fetches current, version-specific library/framework docs and code examples on demand (a `resolve-library-id` → `get-library-docs` pair of MCP tools), which is a real fit for this stack — Angular 22 and FastAPI both move fast enough that Claude's training data can be stale on API specifics, and this sidesteps that the way TS-6 already sidesteps a stale-tooling assumption for LocalStack. It's a raw MCP server, not a Claude Code plugin (no `/plugin install` form exists):

```bash
# local (npx-bundled)
claude mcp add --scope user context7 -- npx -y @upstash/context7-mcp --api-key YOUR_API_KEY

# or remote (hosted, no local process)
claude mcp add --scope user --header "Authorization: Bearer YOUR_API_KEY" --transport http context7 https://mcp.context7.com/mcp
```

The API key is optional (a free tier works unauthenticated at lower rate limits) but recommended — get one at `context7.com/dashboard`. `--scope user` matches the rest of this doc's pattern of keeping credentials/tooling choices out of the committed repo config.

## B. GitHub integration (the Claude Code GitHub Action)

**Setup**: `gh auth login`, then `/install-github-app` in a Claude Code session — installs the GitHub App, adds the auth secret, opens a PR adding the workflow file. Merge it and `@claude` works.

**Auth secret — recommendation: `CLAUDE_CODE_OAUTH_TOKEN`** (via `claude setup-token`), not `ANTHROPIC_API_KEY`, since this is a solo-owned repo, not something shared across an org's multiple repos (API key is the better fit only in that shared case).

**GitHub App scope — recommendation: the documented least-privilege custom app**, not the full shared Claude GitHub App. Anthropic's own docs state this explicitly: *"If your organization requires only the permissions the Claude Code GitHub Action uses, create a custom GitHub App with Contents, Issues, and Pull requests"* — the full app additionally requests Actions/Checks/Discussions/Members/Workflows write, which this project's workflow (Part 4's PR-based review, Part 3's alert-triage PRs) doesn't need. Trade-off: the custom app doesn't get you the managed Code Review service or web auto-fix, only the Action itself — acceptable, since Part 4 already treats managed Code Review as optional/tier-dependent.

**Interactive mode** (`@claude` mentions on issues/PRs — no `prompt` input):

```yaml
name: Claude Code
on:
  issue_comment:
    types: [created]
  pull_request_review_comment:
    types: [created]
jobs:
  claude:
    if: contains(github.event.comment.body, '@claude')
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pull-requests: write
      issues: write
      id-token: write
    steps:
      - uses: actions/checkout@v6
        with: { fetch-depth: 1 }
      - uses: anthropics/claude-code-action@v1
        with:
          claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
```

This is what wires AW-11 (every PR routes through the Action) and Part 4's review workflow.

**Cost controls**: `--max-turns` and `--model` under `claude_args`, a workflow-level `timeout-minutes`, and GitHub's own `concurrency` block to prevent overlapping runs on the same PR.

**Important distinction not to conflate**: this GitHub Action is separate from Claude Code's **Routines** feature, which is what AW-8's alert-triage flow (Part 3) actually runs on — a Routine fires on a schedule or a webhook call, runs a full Claude Code session, and can open a PR directly, independent of any GitHub Action workflow file. Both can end up opening PRs, but they're two different mechanisms — don't wire the alert-triage pattern as a GitHub Action `schedule` trigger; use a Routine, per Anthropic's own documented "alert triage" example.

## C. AWS credentials and permissions

Two separate identities, two separate credential paths — this is where AW-9's open item ("`autoMode.environment` allowlisting is Lou's call") and Part 3/8's deploy-vs-log-scan role split actually get wired.

### C1. Local interactive Claude Code sessions (writing Terraform, running `terraform plan`)

**Use AWS IAM Identity Center (`aws sso login`), not a static IAM user access key.** This is AWS's own current recommendation, not a project-specific judgment call — AWS's IAM best-practices guide states plainly that IAM users with long-term keys are the pattern to move away from for human identities.

```bash
aws configure sso                    # one-time
aws sso login --profile spiresen-dev
export AWS_PROFILE=spiresen-dev
```

Claude Code supports auto-refreshing this via `awsAuthRefresh` in settings, so an expired SSO session doesn't silently stall a long session.

### C2. CI (the GitHub Action's deploy step)

**Use GitHub's OIDC-to-AWS federation — no static AWS keys stored as GitHub secrets at all.**

```yaml
permissions:
  id-token: write
  contents: read
steps:
  - uses: aws-actions/configure-aws-credentials@e3dd6a429d7300a6a4c196c26e071d42e0343502  # pin to full SHA
    with:
      role-to-assume: ${{ secrets.AWS_DEPLOY_ROLE_ARN }}
      role-session-name: spiresen-deploy
      aws-region: us-east-1
```

Trust policy on the AWS side (create the OIDC provider once, then this role):

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com" },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
        "token.actions.githubusercontent.com:sub": "repo:YOUR_ORG/spiresen-saga:ref:refs/heads/main"
      }
    }
  }]
}
```

Scope `sub` to this exact repo and branch — a wildcard `repo:YOUR_ORG/*` defeats the point of the trust boundary.

### C3. Two roles, not one — matching Part 3/8's deploy-vs-log-scan split

**Deploy role** (Terraform: Lambda, API Gateway, DynamoDB, Cognito, plus the Lambda's own execution role). This role needs `iam:CreateRole`/`iam:PassRole`, which AWS's own docs name as a real privilege-escalation vector if scoped loosely — a compromised or buggy deploy run could hand an over-privileged role to a Lambda it creates. Scope it:

```json
{
  "Effect": "Allow",
  "Action": ["iam:CreateRole", "iam:PassRole", "iam:PutRolePolicy", "iam:AttachRolePolicy"],
  "Resource": "arn:aws:iam::ACCOUNT_ID:role/spiresen-lambda-exec-*",
  "Condition": {
    "StringEquals": {
      "iam:PassedToService": "lambda.amazonaws.com",
      "iam:PermissionsBoundary": "arn:aws:iam::ACCOUNT_ID:policy/SpiresenLambdaBoundary"
    }
  }
}
```

Attach a permissions boundary policy (`SpiresenLambdaBoundary`) to cap what any role this identity creates can ever do, regardless of what the Terraform code says later — and deny `iam:DeleteRolePermissionsBoundary` so that cap can't be stripped. This is the role Part 3's human-approval gate applies to: implement the gate as a `permissions.ask` rule (below) on `terraform apply`/`terraform destroy` when the plan touches prod, or — the stronger version — only ever let prod applies happen through the GitHub Action's PR-reviewed flow, never a local `terraform apply`.

**Log-scan role** (the AW-8 monitoring Routine's CloudWatch access). No IAM permissions at all — it structurally can't become an escalation path even running unattended:

```json
{
  "Effect": "Allow",
  "Action": ["logs:FilterLogEvents", "logs:GetLogEvents", "logs:DescribeLogGroups", "logs:DescribeLogStreams"],
  "Resource": "arn:aws:logs:REGION:ACCOUNT_ID:log-group:/aws/lambda/spiresen-*:*"
}
```

## D. `.claude/settings.json` — permission modes and `autoMode`

**Default mode locally: `default` (manual) or `acceptEdits`** — not `auto`, and not `bypassPermissions`. This isn't just a preference: Claude Code silently ignores `"auto"`/`"bypassPermissions"` set in a project-scoped file (`.claude/settings.json` or `.claude/settings.local.json`) — those only take effect from `~/.claude/settings.json` or org-managed settings. Setting them in the committed repo config would do nothing.

```json
{
  "permissions": {
    "defaultMode": "acceptEdits",
    "ask": [
      "Bash(terraform apply *)",
      "Bash(terraform destroy *)",
      "Bash(git push * main)"
    ],
    "allow": [
      "Bash(npm run *)",
      "Bash(pytest *)",
      "Bash(git commit *)"
    ]
  }
}
```

**This is where AW-9's open item resolves concretely.** `autoMode.environment` (and its siblings `autoMode.allow`/`soft_deny`/`hard_deny`) are read **only** from `~/.claude/settings.json` or org-managed settings — never from anything checked into the repo. So the allowlist decision ADR-0004 left to you isn't a repo config choice at all; it's a one-time setup step on your own machine (and, separately, on whatever runs the Routines/GitHub Action, since those have their own settings scope). Concretely, if you want to keep the classifier's default-deny on production Terraform applies rather than allowlisting anything, there's nothing to configure — that's the out-of-the-box behavior. Only add an `autoMode.allow` entry if you later want to carve out a specific, named exception (e.g., a staging environment that resets nightly).

## E. Hooks

**One mechanic worth flagging before you wire AW-6's mechanical check**: `PostToolUse` hooks cannot hard-block — exit code 2 is ignored on that event, because the edit has already happened by the time it fires. A hook there can only feed information back to Claude (via `additionalContext` in its JSON output) so Claude notices and self-corrects in the same turn — it's a strong nudge, not an enforced gate. For a true blocking gate, the mechanism is either a `PreToolUse` hook (before the edit lands) or, more simply, the LSP plugins from Part A: Anthropic's own docs describe the language server reporting errors back to Claude after every edit natively, without a custom hook. For CI-level enforcement (the actual backstop), the mechanical checks (ADR-0002) belong in the GitHub Action / CI pipeline, not solely a local hook.

**AW-6's mechanical risk-path check** (fires before an edit, checks the touched path against TS-17's named risk areas):

```json
{
  "hooks": {
    "PreToolUse": [{
      "matcher": "Edit|Write",
      "hooks": [{ "type": "command", "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/check-risk-path.sh" }]
    }]
  }
}
```

`check-risk-path.sh` reads `tool_input.file_path` from stdin JSON and checks it against a maintained list (`features/boxes/ordering*`, `features/auth/*`, any cross-slice import) — flagging via `hookSpecificOutput.additionalContext` rather than blocking, since the actual escalation to plan-review/`/code-review` is a workflow decision (AW-4/TS-17), not a hard stop.

**AW-7's smoke test** is better fired as a step in the deploy pipeline itself (the GitHub Action's post-apply step) than as a `PostToolUse` hook matching the `terraform apply` Bash call — hooks are tool-call-scoped, not "deployment succeeded" event-scoped, so the CI step is the more reliable trigger. **AW-8's CloudWatch scan** has no natural hook timer at all (hooks don't have an "N minutes later" mechanism) — this is exactly why it's a scheduled Routine, not a hook, as ADR-0004 already specified.

## Open items for you to close when wiring this into the repo

- Confirm the HashiCorp Terraform plugin's exact install string live (`/plugin` → Discover).
- Pin exact `awslabs.terraform-mcp-server` / `mcp-proxy-for-aws` versions against current releases.
- Create the `SpiresenLambdaBoundary` permissions boundary policy and the two IAM roles (deploy, log-scan) before the first Terraform apply.
- Decide whether prod applies happen locally (behind the `ask` rule above) or only through the GitHub Action's PR flow — both are consistent with ADR-0004, this doc doesn't force one.
- Check the managed Code Review service's actual availability on your plan tier (AW-12, still unconfirmed).