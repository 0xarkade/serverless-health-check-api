# Serverless Health Check API

A `/health` endpoint on AWS, defined in Terraform and deployed to two
environments by GitHub Actions.

A request gets logged to CloudWatch, stored in DynamoDB under a generated UUID,
and answered with `200 {"status": "healthy"}`.

```
client --x-api-key--> API Gateway (REST) --> Lambda --> DynamoDB
                      throttling              |        (KMS CMK)
                      request validation      |
                      api key                 +------> CloudWatch Logs

                      Lambda runs in a private VPC with no internet route.
                      It reaches DynamoDB over a VPC gateway endpoint.
```

## Repository layout

| Path | Purpose |
| --- | --- |
| `bootstrap/` | Applied once by a human. Creates the state backend, the GitHub OIDC provider and the deploy roles. Has its own state. |
| `infra/` | The application stack, applied by CI. One root module, two environments. |
| `infra/modules/` | `kms`, `dynamodb`, `network`, `lambda`, `api_gateway`. |
| `infra/environments/` | Per-environment `.tfvars` and backend config. |
| `src/health_check/` | Lambda source. |
| `scripts/smoke_test.sh` | Post-deploy verification, run by the pipeline. |
| `.github/workflows/` | CI and deployment pipelines. |

## Prerequisites

**Tools**

- Terraform >= 1.10 (S3 native state locking)
- AWS CLI v2
- An AWS account, and admin credentials for the one-time bootstrap only

**GitHub repository settings**

- Two Environments named exactly `staging` and `prod`
  (Settings -> Environments). The OIDC trust policy matches on these names, so
  they can't differ.
- `prod` has **Required reviewers** enabled. That's what makes the approval
  gate real instead of advisory.

**Secrets**

None. There are no AWS keys in this repo. GitHub Actions authenticates with
OIDC and gets credentials that last an hour. The only values the pipeline needs
are the account id and region, which aren't secret and live in the workflow and
backend config.

**Variables**

`bootstrap/` (see `bootstrap/terraform.tfvars.example`):

| Variable | Default | Purpose |
| --- | --- | --- |
| `aws_region` | `eu-central-1` | Region for shared resources |
| `project` | `health-check` | Prefix and `Project` tag |
| `github_owner` / `github_repo` | this repo | Built into the OIDC subject |
| `github_owner_id` / `github_repo_id` | numeric ids | Immutable half of the OIDC subject |
| `environments` | `["staging", "prod"]` | One deploy role per entry |

`infra/` (set in `infra/environments/<env>.tfvars`):

| Variable | staging | prod |
| --- | --- | --- |
| `environment` | `staging` | `prod` |
| `vpc_cidr` | `10.10.0.0/16` | `10.20.0.0/16` |
| `log_retention_days` | 7 | 30 |
| `api_throttle_rate_limit` | 20 | 100 |
| `api_throttle_burst_limit` | 40 | 200 |
| `kms_deletion_window_days` | 7 | 30 |

`lambda_memory_size` (256) and `lambda_timeout` (10) have defaults and are not
set per environment.

## One-time bootstrap

The pipeline needs an S3 backend and an IAM role before it can run, and it
can't create the role it runs as. So I apply `bootstrap/` by hand, once, with
admin credentials. Scoping that identity tightly would be circular - it would
have to list every permission needed to create the role that enforces least
privilege. It's one manual apply, and everything after it goes through the
scoped OIDC roles.

```bash
cd bootstrap
terraform init
terraform apply
```

It creates the state bucket, so its own first apply uses local state. Then move
that state into the bucket it just made:

```bash
terraform init -migrate-state
rm terraform.tfstate terraform.tfstate.backup
```

After this every stack, including `bootstrap` itself, keeps state in S3.

## How the pipeline works

Two workflows.

**`ci.yml`** runs on every pull request and every push to `main`:

- `terraform fmt -check` over the whole repo
- `init -backend=false` and `validate` for `bootstrap/` and `infra/`
- Trivy config scan of the Terraform
- Trivy filesystem scan of the Lambda dependencies

It never touches AWS. `init` runs with `-backend=false`, so there are no
credentials and no state access. That's on purpose: a workflow that holds AWS
credentials and can be triggered by a pull request is a hole. Only the jobs
behind an environment get credentials.

**`deploy.yml`** runs on a push to `main`, or by hand from the Actions tab:

```
push to main
  |
  |- security gate      trivy scans the terraform, fails the run on HIGH/CRITICAL
  |
  |- staging            assume staging-deploy-role via OIDC
  |                     init / plan / apply / smoke test
  |
  \- prod               waits for a required reviewer to approve
                        assume prod-deploy-role via OIDC
                        init / plan / apply / smoke test
```

The security gate is repeated here even though `ci.yml` already ran it, so
there's no path to `terraform apply` that skips a scan.

Both environments call the same reusable workflow, `terraform-deploy.yml`, with
a different `environment` input. One copy of the steps, so staging and prod
can't drift apart. The role ARN comes from that input too, as
`<environment>-deploy-role`.

## Deploying staging

1. Branch, make the change, open a pull request. `ci.yml` runs fmt, validate
   and both scans.
2. Merge to `main`. That's the trigger, there's nothing else to press.
3. `deploy.yml` starts with the security gate. If Trivy finds anything HIGH or
   CRITICAL the run stops there and nothing gets applied.
4. The `staging` job assumes `staging-deploy-role` over OIDC, then runs `init`
   with `environments/staging.backend.hcl`, `plan` and `apply` with
   `environments/staging.tfvars`, and finally `scripts/smoke_test.sh` against
   the deployed endpoint.
5. Staging is live. `prod` will now sit waiting for an approval, so if you only
   wanted staging, leave it.

Watch it from the Actions tab or with:

```bash
gh run watch
```

## Deploying prod

`prod` only starts once `staging` has applied and its smoke tests passed, then
waits for a required reviewer. Approve it from the run page and the same steps
run against `prod-deploy-role` and `prod.tfvars`.

AWS enforces this, not just GitHub. The prod role only trusts a token whose
subject ends in `environment:prod`, and you can't enter that environment
without the approval.

## Deploying from a workstation

Both environments can be applied from a workstation with the right permissions.
`init` is what selects the environment, because state lives at a different key
for each one:

```bash
cd infra
terraform init -backend-config=environments/staging.backend.hcl
terraform plan  -var-file=environments/staging.tfvars
terraform apply -var-file=environments/staging.tfvars
```

Swap `staging` for `prod` in both flags to target production. Switching
environments means re-running `init`, which I think is a good thing - you can't
plan against the wrong state by forgetting a flag.

## Testing the endpoint

Get the URL and key from the Terraform outputs:

```bash
cd infra
terraform output -raw health_url
terraform output -raw api_key_value
```

GET, used as a liveness probe:

```bash
curl -i -H "x-api-key: $API_KEY" \
  https://m1fsiyy9kd.execute-api.eu-central-1.amazonaws.com/staging/health
```

```json
{"status": "healthy", "message": "Request processed and saved."}
```

POST, which must carry a `payload` key:

```bash
curl -i -X POST \
  -H "x-api-key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"payload": {"source": "manual-check"}}' \
  https://m1fsiyy9kd.execute-api.eu-central-1.amazonaws.com/staging/health
```

Requests that should be refused:

| Request | Result |
| --- | --- |
| No `x-api-key` header | `403` from API Gateway |
| POST with a body lacking `payload` | `400` from API Gateway, Lambda is not invoked |
| More than the configured rate | `429` |

`scripts/smoke_test.sh <url> <key>` runs all four of these and is what the
pipeline runs after each apply.

## Design choices

**Two root modules, two state files.**
`bootstrap/` and `infra/` have different lifecycles, different credentials and
different blast radius. If they shared state, the pipeline's own role would
need permission to edit its own trust policy, which is a way to escalate. As it
is, the pipeline can manage application resources but can't give itself more
access.

**REST API, not HTTP API.**
HTTP API is cheaper and faster and would normally be my default. It doesn't
support API keys with usage plans, or request validation against a JSON schema,
and I needed both. So REST it is.

**No long lived AWS credentials.**
GitHub mints an OIDC token for the job and AWS swaps it for credentials that
last an hour. Nothing is stored in the repo, so there's no key to rotate or
leak.

**One deploy role per environment, tied to a GitHub Environment.**
The trust policy matches the exact OIDC subject, down to `environment:prod`. So
the prod role can only be assumed by a job running in the prod environment, and
that environment needs an approval first. The gate is enforced by IAM, not just
by the workflow file. Two subjects are listed because GitHub now issues an
immutable form that pins the account and repo by numeric id - both are exact
matches, so listing both doesn't widen anything.

**The naming convention is a security boundary.**
Everything is `<env>-<name>`, so the deploy policy can scope by ARN prefix:
`table/staging-*`. The staging role can't touch prod resources, and its S3
access only covers `infra/staging/*`, so it can't read prod state either.

**Wildcards only where AWS gives me no choice.**
Six statements in `bootstrap/deploy_policy.tf` use `"*"`, each because the call
has no resource level permissions or the id doesn't exist yet:

| Statement | Why | Constrained by |
| --- | --- | --- |
| `ListLogGroups` | `logs:DescribeLogGroups` has no resource level permissions | - |
| `CreateKmsKey` | no ARN exists before creation | - |
| `ManageProjectKmsKeys` | key ids are generated | `aws:ResourceTag/Project` |
| `ReadNetworking` | EC2 `Describe*` has no resource level permissions | - |
| `CreateNetworking` | VPC ids are generated | - |
| `ModifyProjectNetworking` | same | `aws:ResourceTag/Project` |

Where I can't name the resource I constrain by tag instead. Creation can't be
scoped, deletion can, so the destructive half of the networking permissions
carries a tag condition.

**Terraform creates the log group.**
If Lambda creates it on the first invocation, the role needs
`logs:CreateLogGroup`, and that can't be scoped to a group that doesn't exist
yet. So I create it up front. The role then only needs `CreateLogStream` and
`PutLogEvents` on one group, and I can set a retention period instead of
keeping logs forever.

**The function can only write.**
One DynamoDB permission: `PutItem` on one table. No read, no scan, no delete.
KMS is limited to one key with a
`kms:ViaService = dynamodb.eu-central-1.amazonaws.com` condition, so the role
can't use that key for anything but DynamoDB.

**No NAT gateway.**
Lambda sits in private subnets with no route to the internet and reaches
DynamoDB over a VPC gateway endpoint, which is free. A NAT gateway costs about
32 USD a month and would push the traffic out over the internet for no reason.
The security group allows egress only to the AWS managed prefix list for
DynamoDB, so there is no outbound path anywhere else.

**GET is a liveness probe, POST carries the payload.**
The brief asks for GET and POST, and also asks for a 400 when the JSON body has
no `payload`. A GET has no body, so applying that rule to GET would make GET
support useless. I validate the body on requests that actually have one. A GET
is logged and stored like anything else but doesn't need a payload. A POST
without one gets 400 at the gateway, before Lambda runs.

**Shared resources are not environment prefixed.**
`<env>-<name>` is used for everything `infra/` creates and for both deploy
roles. The state bucket and the OIDC provider are shared by both environments,
so a prefix there would say nothing.

**Validation runs twice.**
API Gateway rejects a body without `payload` before Lambda is invoked - that's
the cheap check. The handler checks again because it shouldn't trust its
caller, and that check still holds if the function is invoked some other way.

**CMK for DynamoDB, SSE-S3 for state.**
DynamoDB is encrypted either way. What the CMK gives me is control of the key
policy, rotation and revocation. I didn't do the same for the state bucket: a
second CMK needs its own policy and recovery plan, the deploy roles would need
KMS permissions just to read state, and losing that key would take out every
state file. The trade-off is written down in `.trivyignore.yaml`, next to the
finding it suppresses.

**I don't re-declare AWS defaults.**
New buckets already get encryption, public access blocking and ACLs disabled. I
checked this against the live account with `get-bucket-encryption` and
`get-public-access-block` instead of assuming it. One exception: deleting an
applied public access block does remove it, so that one is declared.

**Lock files cover Linux and Windows.**
Generated with
`terraform providers lock -platform=linux_amd64 -platform=windows_amd64`. If
the lock file only has the developer's platform, the Linux runner rewrites it,
and then there was no point having one.

**Trivy, because it covers both scans.**
Two things needed scanning: the Terraform for misconfiguration before apply,
and the Lambda for vulnerable dependencies. For the first I looked at Checkov,
Terrascan and KICS, and pip-audit for the second. tfsec isn't a separate
project anymore - it was merged into Trivy. Both scans run in `ci.yml` on every
pull request and push. The misconfiguration scan also runs in `deploy.yml` as a
job the apply jobs depend on, so there's no way to reach `terraform apply`
without it, however the deploy was started.

## Cost

Everything is free tier except KMS: one customer managed key per environment at
1 USD a month, so 2 USD for both. No NAT gateway, no WAF.

To tear it all down:

```bash
cd infra
terraform init -backend-config=environments/staging.backend.hcl
terraform destroy -var-file=environments/staging.tfvars
```

Repeat for `prod`, then destroy `bootstrap` last, since it holds the state
backend the other stacks use.
