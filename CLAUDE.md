# CLAUDE.md

Guidance for Claude Code (and anyone else) working in this repo.

## What this repo is

A small real app (**Uptime**, a website uptime monitor) plus, step by step, the AWS setup to run it: VPC, RDS, ECS Fargate, ALB, CloudFront/WAF, EventBridge Scheduler, observability, CI/CD, then everything rebuilt with Terraform.

It is **learning material first**. Every change should keep the repo easy to follow for a beginner. The app is only the vehicle; the architecture is the point.

## Layout

```
app/backend/     Go 1.25, GORM, MySQL. One binary, many commands (api, migrate, seed, check, rollup, dev-scheduler)
app/web/         React 19 + TypeScript + Vite. All API calls go through /api (src/api.ts)
compose.yaml     mysql, migrate (one-off), api, scheduler, web
Makefile         the only entry point for everyday commands
docs/steps/      the learning path, one file per step
docs/app/        how the app works
docs/adr/        Architecture Decision Records
docs/diagrams/   styled SVG diagrams + build.py
```

## Commands

Everything runs in Docker. Go and Node do not need to be installed.

```bash
make up          # build and start everything (app on :5173, API on :8080)
make seed        # example monitors
make check       # run the check job once
make rollup      # run the rollup job once
make test        # go vet + go test, frontend typecheck + build
make fmt         # gofmt
make logs s=api  # follow one service
make reset       # delete all local data
```

Run `make test` before every commit. After Go changes, `make restart` rebuilds the containers.

## Architecture rules

- **One backend image, many commands** (ADR 0002). New jobs are new commands in `cmd/uptime/main.go`, not new programs.
- **Jobs use `runLocked`** (MySQL `GET_LOCK`) so runs never overlap. Jobs must be safe to run twice (upsert, not insert).
- **Every outbound request from the checker goes through `internal/netguard`** (SSRF guard, checks the resolved IP at dial time). Never add a proxy or a second HTTP client that skips it. `ALLOW_PRIVATE_TARGETS` is `true` only in local compose.
- **`/api/health` never touches the database; `/api/ready` does.** Load balancer health checks use `/api/health`.
- **Settings come from environment variables** (`internal/config`). No config files, no hardcoded hosts.
- **The browser only ever talks to one origin.** `/api/*` is proxied (Vite locally, CloudFront on AWS). Do not add CORS.
- **Report storage goes through `reports.Store`**. The S3 version will be added behind the same interface.
- Schema changes go through GORM AutoMigrate (ADR 0003) until we need a rename or data migration; then switch to versioned migrations with a new ADR.
- **Architectural depth over service count.** Add an AWS service only with a clear reason, and write an ADR for it, including "when we would change this". Say what was considered and not used.

## AWS work

- Each AWS step is done **by hand in the console first**, then written as Terraform. Docs follow that order: understand, build by hand, test and break, Terraform.
- Do not run AWS CLI commands (not even read-only ones). Print the exact command for the human to run and ask for the output.
- Terraform lives under `terraform/` once step 02 starts, split into layered stacks (network, security, data, compute, edge, observability, cicd).

## Git

- `master` is the main branch. Never push straight to it; merge a branch with a **merge commit** (not squash) so small commits stay visible.
- Commit as `shadreza <shadreza100@gmail.com>` (set in this repo's local git config).
- Branches:
  - a whole step: `step-NN/<what-it-builds>`, e.g. `step-02/aws-network`
  - anything else: `<type>/<short-description>`, e.g. `fix/rollup-midnight-results`
- After a step is merged, tag it with the branch name using `-`: `step-02-aws-network`.
- Commits follow Conventional Commits: `<type>(<scope>): <subject>`
  - types: `feat fix docs infra ci refactor test chore`
  - scopes: `api jobs db web docker make docs`, and AWS parts like `network ecs rds edge`
  - subject: imperative, lowercase, no full stop, 50 characters or less; body explains why
- Full rules in [CONTRIBUTING.md](CONTRIBUTING.md).

## Writing docs

- Plain, simple English a beginner can follow. Short sentences. Explain every new term the first time.
- Every command is followed by what you should see.
- Write like a person: no filler, no hype words ("robust", "seamless", "leverage"), no emoji.
- Each step doc (`docs/steps/NN-*.md`) has: goal and time, what you will be able to do, numbered sections, hands-on experiments (including breaking something on purpose), check-yourself questions with hidden answers, clean up, next step.
- ADRs: one decision per file, copied from `docs/adr/template.md`, never rewritten later (supersede with a new one). Add each one to `docs/adr/README.md`.
- Put a diagram wherever it makes a section easier to understand.

## Diagrams

- **Architecture maps** (where things live: laptop, Docker, region, VPC, subnets) are SVGs in `docs/diagrams/`, generated by `python3 docs/diagrams/build.py`. Keep the style: IBM Plex fonts, a colored category chip with a short code on each card, dashed region border, purple VPC border, green/teal/blue bands for public/private/isolated subnets, dashed card for things that run and stop, dashed arrow for control or lookup. Fixed colors with a dark-mode `@media` block (no CSS variables). Check the result with `rsvg-convert` before committing.
- **Everything else** (sequences, ER, small flows, git graphs) is Mermaid in the Markdown. Flowcharts get the same category colors as borders with `classDef`:

  | class | color | used for |
  |---|---|---|
  | `compute` | `#ED7100` | containers, ECS, ECR |
  | `jobs` | `#E7157B` | scheduler, EventBridge, CloudWatch |
  | `database` | `#C925D1` | MySQL, RDS |
  | `storage` | `#7AA116` | volumes, S3 |
  | `network` | `#8C4FFF` | ALB, NAT, Route 53, CloudFront |
  | `security` | `#DD344C` | WAF, ACM, Secrets Manager, SSRF guard |

- Validate new Mermaid with mermaid-cli (`docker run --rm -v "$PWD":/data minlag/mermaid-cli -i /data/x.mmd -o /data/x.svg`) before committing.

## Code style

- Go: standard library first (`net/http` routing, `log/slog` JSON logs). Short comments that explain *why*. Errors wrapped with context. Users see plain error messages; details go to the logs.
- TypeScript: strict mode, no UI library, one fetch wrapper in `src/api.ts`, plain CSS in `src/styles.css`.
- Keep the app small. New features need a reason that serves the architecture or the teaching.
