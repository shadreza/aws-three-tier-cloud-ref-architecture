# 0011. ECS on Fargate, ARM, one immutable image tag chosen through SSM

- Status: Accepted
- Date: 2026-09-29

## Context

The backend is one container image with several commands (ADR 0002). On AWS we need to run the API all the time, run `check` and `rollup` on a schedule, and deploy new versions without downtime. The team is small and does not want to manage servers.

We also need a clear answer to "which version is running?", both for people and for the two things that deploy: a person with `make tf-apply` (steps 04 to 07) and GitHub Actions (step 08).

## Options

Where to run containers:

1. **ECS on Fargate.** No servers. Pay per task, per second (one-minute minimum). Integrates with load balancers, Secrets Manager, CloudWatch Logs and EventBridge Scheduler without extra glue.
2. **ECS on EC2.** Cheaper per vCPU at high, steady load, but we would patch and scale the instances ourselves.
3. **EKS (Kubernetes).** Very capable, and a lot to learn and run. The control plane alone costs $0.10 an hour ($73 a month), more than our whole API.
4. **Lambda.** Great for short jobs. The API would need an adapter, and the check job holds a MySQL lock and many outbound connections, which fits a container better.

Which CPU:

1. **x86_64.** Works everywhere.
2. **ARM64 (Graviton).** About 20% cheaper for the same vCPU and memory on Fargate. Go cross-compiles to ARM with no changes.

How a deploy chooses the image:

1. **`latest` tag.** Simple, but "latest" means something different every hour, and a task restarted at night might pick up an untested image.
2. **A Terraform variable** `image_tag`. Clear, but the person applying has to remember the current tag every time, or they roll the app back by accident.
3. **An SSM parameter** `/uptime-<env>/image-tag`. The deployer writes the tag there once; every later `terraform apply` reads it. ECR tags are **immutable**, so a tag always means exactly one image.

## Decision

- ECS on Fargate, ARM64. API: 0.25 vCPU / 0.5 GB, 1 task in dev; 0.5 vCPU / 1 GB, 2 to 4 tasks with CPU autoscaling in prod.
- One ECR repository per environment (`uptime-<env>/backend`), immutable tags, scan on push, keep the newest 50 images (a rollback can go back up to 50 deploys). It gets its own stack, `registry`, applied between `data` and `compute` (this adds one layer to the list in ADR 0007), because the image must be pushed before any task can start.
- The image tag is the git commit (`git rev-parse --short=12 HEAD`). The compute stack reads it from SSM.
- The load balancer is internal (ADR 0005); tasks run in private subnets with no public IP.
- Deploys are rolling: new tasks start before old ones stop, and the deployment circuit breaker rolls back by itself if new tasks do not become healthy.

## Consequences

- A person and CI can both apply the compute stack without fighting over the version.
- A rollback is `make image-use env=dev tag=<old tag>` and an apply.
- Each environment has its own copy of the image. Promoting from dev to prod means pushing the same build to the prod repository (step 08 does this with one build).
- Fargate does not cache images between tasks, so every task start pulls the whole image. The S3 gateway endpoint keeps that off the NAT gateway (ADR 0006).
- The image must be built for ARM. `make image-push` and CI use `docker buildx --platform linux/arm64`, and the Dockerfile cross-compiles, so no emulation is needed on an x86 laptop.

## When we would change this

- If we run many services with steady high load, ECS on EC2 (or Fargate with Savings Plans) becomes cheaper.
- If we get several AWS accounts, one shared ECR repository in a tools account with cross-account pull would replace the copy per environment.
- If a library we need does not support ARM, we switch the task definitions to `X86_64`.
