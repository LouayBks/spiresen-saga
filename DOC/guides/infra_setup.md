# Setting up AWS/domain/pipeline infra (#10, #11) — a walkthrough

The step-by-step "what do I actually click/run" companion to `ADR-005-aws-identity-strategy.md`
(the *why* behind the credential choices below) and the human-steps sections of #10/#11's plan.
Every step here is something only a human can do — account creation, payment, IAM console
work, and the `terraform apply` calls themselves (Claude never applies, per AW-24). Do these in
order; several steps are hard prerequisites for the ones after.

What already exists in the repo by the time you start this: `infra/modules/dns`,
`infra/environments/prod` (region `eu-west-3`, ACM forced to `us-east-1` via a provider alias),
`infra/bootstrap` (state bucket, no DynamoDB — native S3 locking), and
`.github/workflows/infra-deploy.yml`.

## 1. AWS account + root security

Skip to step 2 if you already have an account you're using for this.

1. [aws.amazon.com](https://aws.amazon.com) → Create an AWS Account → your email, a strong
   root password (save it in a password manager), a payment method, phone verification.
2. Sign in as root → top-right account name → **Security credentials**.
3. **Enable MFA on root**: Assign MFA device → Authenticator app → scan the QR code → save
   backup codes → confirm two consecutive codes.
4. **Billing alarm**: CloudWatch → Alarms → Create alarm → metric: Billing → Estimated
   Charges > (your comfort threshold, e.g. $5) → notify your email via SNS.
5. **After this, stop using root.** Everything from here on uses IAM Identity Center (step 2
   below), never the root credentials again.

## 2. IAM Identity Center — for your (and Claude's) local Terraform work

Per ADR-005: this is the credential both you and Claude use locally. There's no separate
"Claude identity" — Claude inherits whatever's active in your shell.

1. AWS Console → search **IAM Identity Center** → **Enable** (works standalone, no AWS
   Organizations needed for one account). Confirm the region it asks for — that becomes your
   SSO region, note it down.
2. **Create a permission set**: Identity Center → Permission sets → Create → Custom permission
   set → name it `spiresen-infra-admin`. Attach an inline policy (this is broader than
   `ReadOnlyAccess` because you'll use this same session to run the actual `terraform apply`
   calls below — CI's separate OIDC role, not this one, handles ongoing automated applies):
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       { "Effect": "Allow", "Action": ["route53:*"], "Resource": "*" },
       {
         "Effect": "Allow",
         "Action": [
           "acm:RequestCertificate", "acm:DescribeCertificate",
           "acm:AddTagsToCertificate", "acm:DeleteCertificate",
           "acm:ListTagsForCertificate"
         ],
         "Resource": "*"
       },
       { "Effect": "Allow", "Action": ["s3:*"], "Resource": "arn:aws:s3:::spiresen-saga-*" },
       { "Effect": "Allow", "Action": ["s3:ListAllMyBuckets", "s3:CreateBucket"], "Resource": "*" },
       { "Effect": "Allow", "Action": ["iam:CreateOpenIDConnectProvider", "iam:GetOpenIDConnectProvider",
           "iam:CreateRole", "iam:GetRole", "iam:PutRolePolicy", "iam:AttachRolePolicy"],
         "Resource": "*" }
     ]
   }
   ```
   (The last block is only needed once, for step 4's OIDC provider/role — you can remove it
   afterward if you want the permission set to stay minimal day-to-day.)
3. **Session duration**: on the same permission set, Session settings → set the "session
   duration" for CLI/SDK sessions. Default is 8 hours (re-login every day you use it); it can go
   up to 90 days. Pick whatever friction level you're comfortable with — there's no "correct"
   value, just a trade-off (ADR-005 leaves this to you explicitly).
4. **Assign yourself**: Identity Center → Users → Add user (your own email) → assign the
   `spiresen-infra-admin` permission set to your AWS account.
5. **Find your SSO start URL**: Identity Center → Dashboard → "Settings summary" box →
   **AWS access portal URL** (looks like `https://d-xxxxxxxxxx.awsapps.com/start`).
6. **Configure locally**:
   ```bash
   aws configure sso
   # SSO session name: spiresen-dev
   # SSO start URL: <the awsapps.com/start URL from step 5>
   # SSO region: <the region from step 1>
   # (it opens a browser — log in, approve)
   # CLI default client Region: eu-west-3
   # Profile name: spiresen-dev
   ```
7. **Activate + verify**:
   ```bash
   aws sso login --profile spiresen-dev
   export AWS_PROFILE=spiresen-dev
   aws sts get-caller-identity
   ```
   Expect a JSON blob with your `Account` and `UserId` — no error. This is the credential both
   you and Claude (via this same shell) now use for every `terraform plan`/`apply` below.

## 3. Buy the domain (Namecheap)

1. [namecheap.com](https://namecheap.com) → search `spiresen.com` → purchase.
2. **Don't set custom DNS yet** — that happens in step 6, after the Route 53 zone exists and
   can tell you its own name servers.

## 4. Bootstrap Terraform state

This creates the S3 bucket `infra/environments/prod` will use as its backend. It has to exist
before `prod`'s `terraform init` can succeed — this order is not optional.

```bash
cd infra/bootstrap
terraform init -input=false
terraform plan -input=false     # expect: 1 to add (the S3 bucket) + its 3 sub-resources
terraform apply                 # type "yes" — this is the one Terraform apply that's on you
```

## 5. Apply the `dns` module

```bash
cd ../environments/prod
terraform init -input=false     # now succeeds — the bucket from step 4 exists
terraform plan -input=false     # expect: Route 53 zone + ACM cert + validation records
terraform apply
```

Note the `dns_name_servers` output — you need those four values for the next step.

## 6. Delegate the domain at Namecheap

1. Namecheap → Domain List → `spiresen.com` → **Manage**.
2. On the domain page, find the **Nameservers** section → open its dropdown → select
   **Custom DNS**.
3. Four input fields appear — paste in the four NS values from step 5's output, one per
   field, without trailing dots.
4. Click the **green checkmark** to save. Propagation is usually under an hour, can take up
   to ~48h. Once switched to Custom DNS, Namecheap's own DNS editor is disabled — all further
   DNS changes happen in Route 53/Terraform, not in Namecheap.

## 7. Confirm the cert issues

Once delegation propagates, the ACM validation records Terraform already created in the zone
resolve, and AWS auto-validates — no manual token copying needed.

```bash
dig NS spiresen.com          # should show the Route 53 name servers from step 5
aws acm describe-certificate --region us-east-1 \
  --certificate-arn "$(terraform output -raw wildcard_certificate_arn)" \
  --query 'Certificate.Status'
# expect: "ISSUED" (may show "PENDING_VALIDATION" for a while first — that's normal, re-check later)
```

## 8. GitHub OIDC provider + deploy role (for CI's automated apply)

Separate from everything above — this is what `.github/workflows/infra-deploy.yml`'s `push`-to-`main`
job assumes, per ADR-005's second decision. Do this via the console (or `aws iam` CLI commands using
your step-2 session, if you'd rather not click through it):

1. IAM → Identity providers → Add provider → **OpenID Connect**:
   - Provider URL: `https://token.actions.githubusercontent.com`
   - Audience: `sts.amazonaws.com`
2. IAM → Roles → Create role → Web identity → pick the provider from step 1, audience
   `sts.amazonaws.com` → name it `spiresen-saga-terraform-apply`.
3. Attach an inline policy — same scope as step 2's permission set, minus the one-time IAM/OIDC
   block (CI never needs to create its own provider/role):
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       { "Effect": "Allow", "Action": ["route53:*"], "Resource": "*" },
       {
         "Effect": "Allow",
         "Action": [
           "acm:RequestCertificate", "acm:DescribeCertificate",
           "acm:AddTagsToCertificate", "acm:DeleteCertificate",
           "acm:ListTagsForCertificate"
         ],
         "Resource": "*"
       },
       { "Effect": "Allow", "Action": ["s3:*"], "Resource": "arn:aws:s3:::spiresen-saga-*" }
     ]
   }
   ```
4. Edit the role's **Trust relationships** to scope `sub` to this exact repo/branch (a wildcard
   here defeats the point of the trust boundary):
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [{
       "Effect": "Allow",
       "Principal": { "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com" },
       "Action": "sts:AssumeRoleWithWebIdentity",
       "Condition": {
         "StringEquals": { "token.actions.githubusercontent.com:aud": "sts.amazonaws.com" },
         "StringLike": { "token.actions.githubusercontent.com:sub": "repo:LouayBks/spiresen-saga:ref:refs/heads/main" }
       }
     }]
   }
   ```
   (Replace `ACCOUNT_ID` with your 12-digit account number — IAM → Dashboard.)
5. **GitHub repo** → Settings → Secrets and variables → Actions → **Variables** tab → New
   repository variable:
   - Name: `AWS_DEPLOY_ROLE_ARN`
   - Value: `arn:aws:iam::ACCOUNT_ID:role/spiresen-saga-terraform-apply`
6. (Optional, recommended) **Settings → Environments → New environment** named `prod` →
   add yourself as a required reviewer. This makes `infra-deploy.yml`'s `apply` job (which
   already declares `environment: prod`) pause for your approval on every push-to-`main` apply,
   even though it's already gated behind a human-merged PR.

## 9. Verify the pipeline end to end

1. Open a PR that touches `infra/**` (even a no-op comment change) → confirm the `plan` job runs
   and comments the Terraform plan on the PR.
2. Merge it → confirm the `apply` job runs on push to `main`, and (since steps 4-5 already
   applied everything by hand) shows **no changes** — confirms CI's state matches what you
   applied locally, not a drifted duplicate.
3. `terraform plan -input=false` locally, from `infra/environments/prod`, should also show zero
   diff at this point.

## If something's stuck

- `terraform init` fails with "bucket does not exist" → you're running `prod` before
  `bootstrap` (step 5 before step 4). Do step 4 first.
- `aws sts get-caller-identity` fails → your SSO session expired (step 2's duration setting) —
  `aws sso login --profile spiresen-dev` again.
- ACM stuck on `PENDING_VALIDATION` past a day → check `dig NS spiresen.com` actually shows
  the Route 53 servers (step 6 may not have propagated, or the wrong nameservers were pasted).
