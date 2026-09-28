# 0016. GitHub Actions with OIDC: build once, deploy the same build to each environment

- Status: Accepted
- Date: 2026-09-29

## Context

Until now a person deploys: `make image-push`, `make image-use`, `make tf-apply` for the compute stack, `make web-deploy`. That needs AWS credentials on a laptop, and nothing stops untested code from being deployed.

We want every pull request tested, every merge to `master` deployed to dev automatically, and prod deployed only after a person approves, with no long-lived AWS keys anywhere.

## Options

For credentials:

1. **An IAM user's access keys stored as GitHub secrets.** Simple, and a key that never expires, sitting in a third-party system, with permissions someone has to remember to trim.
2. **OIDC federation.** GitHub gives each job a signed token that says which repository, branch and environment it is running for. AWS trusts GitHub's tokens (an OIDC identity provider, once per account) and swaps them for credentials that expire within an hour, for a role whose trust policy names exactly this repository and environment.

For what CI is allowed to do:

1. **Admin, so CI can apply every stack.** One pipeline for everything. And one leaked workflow change can do anything in the account.
2. **Only what a deploy needs**: push to one ECR repository, set one SSM parameter, apply the compute stack, upload web files, invalidate one distribution. Infrastructure stacks stay applied by people.

For the build:

1. **Build in each environment's job.** Simple, but prod then runs a different build from the one tested in dev.
2. **Build once, promote the same artifact.** The image and the web files are built once and passed to each environment's job.

## Decision

- **`ci.yml`** on every pull request and push: `make test-backend`, `make test-web`, `make tf-validate`, and an ARM image build. No AWS access at all.
- **`deploy.yml`** on push to `master` (when app or compute code changed): one `build` job on an ARM runner saves the image (`docker save`) and the web build as artifacts. The whole workflow only runs when the repository variable `DEPLOY_DEV` is `true`. Then `deploy-environment.yml` runs for dev, then staging (if `DEPLOY_STAGING` is `true`), then prod (if `DEPLOY_PROD` is `true`). Each one: push the same image to that environment's ECR, `make image-use`, `make tf-plan` and `make tf-apply` for the compute stack, wait for the service to be stable, `make web-upload`.
- Each environment is a **GitHub environment** with a variable `AWS_DEPLOY_ROLE_ARN`. The role (`terraform/stacks/cicd`) trusts only `repo:<owner>/<repo>:environment:<env>`. The `prod` environment has required reviewers, so the prod job waits for a person.
- The GitHub OIDC provider is created by `terraform/bootstrap`, once per account.
- CI uses the same `make` targets as people. There is one way to deploy.

## Consequences

- No AWS keys exist anywhere, not in GitHub, not on laptops for deploys.
- If a change needs more than a compute deploy (for example a new security group rule), the CI apply fails with `AccessDenied`. That is on purpose: a person applies that stack, and the next deploy goes through.
- The images in dev, staging and prod are the same bytes. The tag is the git commit.
- Deploys of one environment never run at the same time (`concurrency`), so two merges cannot fight over the Terraform state.
- ARM runners (`ubuntu-24.04-arm`) are free for public repositories. A private repository needs a paid plan for them, or can build on x86 runners: the Dockerfile cross-compiles, so that works without emulation; only the `image` check in `ci.yml` would then not be a native ARM build.

## When we would change this

- More people changing infrastructure: run `terraform plan` for every stack on pull requests with a read-only role, and apply after review (for example with Atlantis or HCP Terraform).
- Several AWS accounts: one shared registry in a tools account instead of pushing to each environment.
