# AWS Three-Tier Reference Architecture

A small, real web app and, step by step, the AWS setup to run it properly.

The app is **Uptime**. You give it a web address, and it checks every minute whether that site is up. It keeps a history and writes a daily report.

We picked it because it needs every part of a normal production system:

- a **frontend** people open in the browser
- an **API** the frontend calls
- a **database** that keeps the data
- a **scheduled job** that runs by itself and calls the internet

The app runs on your laptop with Docker. Steps 02 to 09 then build the AWS setup for it, one layer at a time, first by hand and then in Terraform (see [The steps](#the-steps)).

**New here? Read the [learning path](docs/learning-path.md), then start with [Step 01: Understand the application](docs/steps/01-understand-the-application.md) and its [workbook](docs/workbook/01-understand-the-application.md).**

Want the design thinking without building anything? Read **[From Laptop to Tokyo](docs/storybook/README.md)**, a 16-episode series that explains why every piece is there, what it costs and what we didn't pick.

## See it running in 5 minutes

You need **Docker**, **make** and **git**. Nothing else: no Go, no Node, no MySQL.

```bash
git clone git@github.com:shadreza/aws-three-tier-cloud-ref-architecture.git
cd aws-three-tier-cloud-ref-architecture
make up
make seed
```

Open <http://localhost:5173>. Within a minute you will see three monitors: one up, one down on purpose, and one watching the app's own API.

Want the slow, step-by-step version? Read **[docs/local-development.md](docs/local-development.md)**. It explains every command and what you should see after it.

## How the pieces fit

<p align="center"><img src="docs/diagrams/local-architecture.svg" alt="The app on your laptop: browser, web, api, scheduler, mysql and the websites being checked" width="100%"></p>

Each box is one Docker container locally. Later, each box becomes an AWS service:

| Local (Docker) | On AWS |
|---|---|
| `web` (Vite dev server) | S3 + CloudFront (which also forwards `/api/*` to the load balancer) |
| `api` | ECS Fargate service behind an internal Application Load Balancer |
| `mysql` | RDS for MySQL |
| `scheduler` | EventBridge Scheduler starting ECS tasks |
| `reports` volume | S3 bucket |
| `migrate` | a container that runs first in every API task, then exits |

[docs/app/how-it-works.md](docs/app/how-it-works.md) walks through what happens inside, like the life of a single check.

## Where we are heading

This is the AWS setup the steps build, piece by piece. Don't worry if the names mean nothing yet. Each one gets its own step.

<p align="center"><img src="docs/diagrams/aws-target-architecture.svg" alt="Target AWS architecture: CloudFront and WAF in front, an internal load balancer and ECS Fargate in private subnets, RDS MySQL in isolated subnets" width="100%"></p>

## What's in this repo

```
app/
  backend/        Go: the API and the jobs, one program with several commands
  web/            TypeScript + React frontend
terraform/
  bootstrap/      the state bucket, once per AWS account
  modules/        reusable pieces (network, security groups, database...)
  stacks/         one folder per layer, each with its own state
  envs/           the values for dev, staging and prod
docs/
  steps/                 the guides, one step at a time (start here)
  workbook/              what you work through for each step: checklists, commands, a log
  storybook/             From Laptop to Tokyo: the design story, no Terraform needed
  learning-path.md       how to study the whole track on your own
  teaching-guide.md      how to run it as a course for a team
  runbook.md             operating the finished system: deploys, alarms, recovery
  costs.md               what everything costs in Tokyo
  local-development.md   run it on your laptop, command by command
  app/how-it-works.md    what each piece does and why
  adr/                   decisions we made and why (Architecture Decision Records)
compose.yaml      every container the app needs locally
Makefile          short commands: make up, make logs, make test...
CONTRIBUTING.md   branch names, commit messages, pull requests
```

## Everyday commands

```bash
make           # list every command
make up        # start everything
make logs      # watch the logs (one service: make logs s=api)
make check     # run the check job now instead of waiting
make rollup    # build today's report now
make test      # run all tests
make down      # stop (data is kept)
make reset     # stop and delete all local data
```

## The steps

| Step | What | Status |
|---|---|---|
| [01](docs/steps/01-understand-the-application.md) | Understand the application and run it locally | done |
| [02](docs/steps/02-aws-network.md) | AWS network: VPC, subnets, routing, NAT, security groups, Terraform layout | ready |
| [03](docs/steps/03-database-and-secrets.md) | RDS MySQL, Secrets Manager, reports on S3 | ready |
| [04](docs/steps/04-containers-on-ecs.md) | Containers on ECS Fargate behind a load balancer | ready |
| [05](docs/steps/05-cdn-and-waf.md) | CloudFront, WAF, HTTPS, optional domain | ready |
| [06](docs/steps/06-scheduled-jobs.md) | Scheduled jobs with EventBridge Scheduler | ready |
| [07](docs/steps/07-observability.md) | Logs, metrics, alarms, dashboard | ready |
| [08](docs/steps/08-ci-cd.md) | CI/CD with GitHub Actions and OIDC | ready |
| [09](docs/steps/09-rebuild-and-replicate.md) | A second environment from values only, then rebuild everything from zero | ready |

Everything runs in **Tokyo (`ap-northeast-1`)**. A finished dev environment costs about $120 a month (about $0.16 an hour), prod about $253. [docs/costs.md](docs/costs.md) breaks that down per service and per step.

Each AWS step is built by hand in the console first, so we understand it, and then written as Terraform. Every step has its own branch; once merged, it also gets a tag and a `checkpoint/step-NN` branch that includes later fixes. See [docs/steps](docs/steps/README.md).

## Contributing

Read [CONTRIBUTING.md](CONTRIBUTING.md) for branch names and commit messages.
