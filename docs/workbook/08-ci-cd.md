# Workbook 08: CI/CD

Companion to the [step 08 guide](../steps/08-ci-cd.md). Commands marked **(AWS)** talk to your account; `gh` commands talk to GitHub.

<p align="center"><img src="../diagrams/step-08-cicd.svg" alt="Step 08 CI/CD: GitHub workflows, OIDC, the deploy role" width="100%"></p>

## Before you start

- [ ] Steps 02 to 07 applied in dev
- [ ] Admin rights on the GitHub repository; `gh auth status` shows you logged in
- [ ] Account ID committed in `terraform/envs/dev/backend.hcl` and `common.tfvars`
- [ ] Time: 2 to 3 hours. Cost: nothing extra.

## Session log

| Date | Start | End | What I did | Left running? |
|---|---|---|---|---|
| | | | | |
| | | | | |

## Values I recorded

| What | Where to get it | My value |
|---|---|---|
| OIDC provider ARN | output of `make tf-bootstrap` | |
| deploy role ARN (dev) | `make tf-output env=dev stack=cicd name=deploy_role_arn` | |
| first green deploy run | GitHub **Actions** | |
| time from merge to deployed | the run's duration | |

## Phase 1. Understand

- [ ] CI versus CD, in one line each: ______________________
- [ ] What the OIDC token says, and what the trust policy checks: ______________________
- [ ] What the deploy role may **not** do: ______________________
- [ ] Why build once and promote the same artifact: ______________________
- [ ] Read [ADR 0016](../adr/0016-github-actions-oidc-deploys.md).

## Phase 2. Trust GitHub (guide section 3)

```bash
make tf-bootstrap account_id=ACCOUNT budget_email=you@example.com   # (AWS)
```
- [ ] `Plan: 1 to add` (or no changes, if bootstrapped from a recent master); OIDC provider visible in **IAM, Identity providers**
- [ ] Looked at a console-generated web identity trust policy, then cancelled

## Phase 3. Terraform and GitHub (guide section 4)

```bash
make tf-plan  env=dev stack=cicd     # (AWS) Plan: 2 to add
make tf-apply env=dev stack=cicd     # (AWS) deploy_role_arn = ...
REPO=shadreza/aws-three-tier-cloud-ref-architecture
gh api -X PUT repos/$REPO/environments/dev
gh variable set AWS_DEPLOY_ROLE_ARN --repo $REPO --env dev --body "arn:aws:iam::ACCOUNT:role/uptime-dev-github-deploy"
gh variable set DEPLOY_DEV --repo $REPO --body true
gh variable set DEPLOY_STAGING --repo $REPO --body false
gh variable set DEPLOY_PROD --repo $REPO --body false
```
- [ ] cicd applied (2)
- [ ] Environment `dev` with `AWS_DEPLOY_ROLE_ARN`; repo variables set
- [ ] Branch rule on `master`: pull request + checks `backend`, `web`, `terraform`, `image`

## Phase 4. Test (guide section 5)

- [ ] PR with a small change: four `ci` jobs green
- [ ] Merged: `deploy` ran `build` then `dev`; OIDC login, image push, plan/apply, services stable, web upload
- [ ] `curl https://dxxxx.cloudfront.net/api/health` shows the change

## Phase 5. Break it (guide section 6)

| Experiment | Expected | What I saw |
|---|---|---|
| a) code that does not compile | `ci` fails, merge blocked | |
| b) job outside `environment: dev`, role hardcoded | `Not authorized to perform sts:AssumeRoleWithWebIdentity` | |
| c) `log_retention_days` 14 to 30 | apply fails `AccessDenied ... logs:PutRetentionPolicy`; person applies it | |
| d) prod with required reviewers | `Waiting for review` until approved | |

## Done when

- [ ] A merge to `master` deploys dev with nobody running a command.
- [ ] No AWS access key exists for CI anywhere.
- [ ] I can explain why an infrastructure change fails in CI, and who applies it.
- [ ] I answered the six "check yourself" questions.

## Clean up

- [ ] Nothing costs money. To stop deploys: `gh variable set DEPLOY_DEV --repo $REPO --body false`, or **(AWS)** `make tf-destroy env=dev stack=cicd`

## If something goes wrong

| What you see | Likely cause | Fix |
|---|---|---|
| `deploy` does nothing | `DEPLOY_DEV` not `true` | set the repo variable |
| `Could not assume role ... Not authorized` | trust policy `sub`: wrong repo name in `cicd.tfvars`, or job without `environment:` | fix `github_repository`, apply `cicd` |
| `Credentials could not be loaded` / empty role | `AWS_DEPLOY_ROLE_ARN` missing on the environment | `gh variable set ... --env dev` |
| `terraform init` fails with `AccessDenied` on S3 | state bucket name in `backend.hcl` still `000000000000`, or role policy | commit the account ID; compare the policy |
| apply fails `AccessDenied` on something outside compute | the change needs a person | plan and apply that stack by hand, re-run the workflow |
| `tag ... already exists` | re-run of the same commit | handled: the workflow skips the push |

## Notes

