# 0007. Terraform layout: modules, stacks and one folder of values per environment

- Status: Accepted
- Date: 2026-09-29

## Context

From step 02 on, everything is also written in Terraform. We want:

- to create dev, staging and prod from **the same code**, with only the values different
- a mistake in one part (say, the load balancer) not to be able to touch another part (say, the database)
- every environment to be able to live in its own AWS account later
- beginners to be able to read it

## Options

For environments:

1. **Terraform workspaces.** One folder, one backend, `terraform workspace select prod`. Easy to forget which workspace you are in, and all environments must share one backend and one set of credentials.
2. **One folder of code per environment** (`envs/dev/main.tf`, `envs/prod/main.tf`). Clear, but the copies drift apart: someone fixes prod and forgets dev.
3. **One folder of code per stack, one folder of values per environment.** The code in `stacks/` is the same for all environments. `envs/<env>/` holds only `.tfvars` files and the backend settings.
4. **Terragrunt.** Solves this well, but it is one more tool to learn.

For splitting the infrastructure:

1. **One big root module.** One `apply` does everything. Every plan reads every resource, and one bad change can hit anything.
2. **Layered stacks**, each with its own state file, that read each other's outputs.

For state locking:

1. **S3 backend with a DynamoDB lock table.** The old way.
2. **S3 backend with `use_lockfile = true`.** Terraform 1.10 and later can lock with a small file in the same bucket. No table to create or pay for.

## Decision

Option 3, layered stacks, and S3-native locking:

```
terraform/
  bootstrap/          the state bucket, once per AWS account (local state)
  modules/            reusable building blocks, no provider or backend settings
    network/
    security-groups/
    ...
  stacks/             one root module per layer, each with its own state file
    network/          step 02
    security/         step 02
    data/             step 03
    compute/          step 04
    edge/             step 05
    jobs/             step 06
    observability/    step 07
    cicd/             step 08
  envs/
    dev/              backend.hcl, common.tfvars, <stack>.tfvars
    staging/
    prod/
```

- State for stack `network` in `dev` is `s3://uptime-tfstate-<account>/dev/network.tfstate`.
- A stack reads the stacks below it with `terraform_remote_state`. Stacks are applied in order: network, security, data, compute, edge, jobs, observability, cicd.
- `make tf-plan env=dev stack=network` and `make tf-apply env=dev stack=network` run everything, in Docker, so Terraform does not need to be installed.
- Each environment gets its own `.terraform` folder (`TF_DATA_DIR=.terraform/<env>`), so a plan for dev can never be applied to prod's state.
- The provider has `allowed_account_ids`. Terraform stops before changing anything if your terminal is logged in to the wrong account.
- Every resource gets the tags `Project`, `Environment`, `Stack` and `ManagedBy` from `default_tags`, so the bill can be split by environment and stack.

## Consequences

- Making a new environment is: copy `envs/dev` to `envs/qa`, change the values, apply the stacks in order. No code changes. Step 09 does exactly this.
- A plan only reads one layer, so it is fast and the blast radius is small.
- Changing an output that other stacks use needs two applies, in order. The docs say when.
- The same code for all environments means an environment cannot have "just one extra resource". A difference has to be a variable.

## When we would change this

- If we get many environments or many accounts, Terragrunt or Terraform Stacks would remove the repeated backend and variable wiring.
- If a stack grows too big to plan quickly, we split it.
