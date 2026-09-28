# AWS Three-Tier Reference Architecture

A small, real web app and, step by step, the AWS setup to run it properly.

The app is **Uptime**. You give it a web address, and it checks every minute whether that site is up. It keeps a history and writes a daily report.

We picked it because it needs every part of a normal production system:

- a **frontend** people open in the browser
- an **API** the frontend calls
- a **database** that keeps the data
- a **scheduled job** that runs by itself and calls the internet

Right now the app runs on your laptop with Docker. The AWS part comes next, one step at a time (see [The steps](#the-steps)).

**New here? Start with [Step 01: Understand the application](docs/steps/01-understand-the-application.md).**

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
| `web` (Vite dev server) | S3 + CloudFront |
| `api` | ECS Fargate service behind an Application Load Balancer |
| `mysql` | RDS for MySQL |
| `scheduler` | EventBridge Scheduler starting ECS tasks |
| `reports` volume | S3 bucket |
| `migrate` | one-off ECS task before each deploy |

[docs/app/how-it-works.md](docs/app/how-it-works.md) walks through what happens inside, like the life of a single check.

## Where we are heading

This is the AWS setup the steps build, piece by piece. Don't worry if the names mean nothing yet. Each one gets its own step.

<p align="center"><img src="docs/diagrams/aws-target-architecture.svg" alt="Target AWS architecture: CloudFront and WAF in front, a load balancer in public subnets, ECS Fargate in private subnets and RDS MySQL in isolated subnets" width="100%"></p>

## What's in this repo

```
app/
  backend/        Go: the API and the jobs, one program with several commands
  web/            TypeScript + React frontend
docs/
  steps/                 the learning path, one step at a time (start here)
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
| [01](docs/steps/01-understand-the-application.md) | Understand the application and run it locally | ready |
| 02 | AWS network: VPC, subnets, routing, NAT | next |
| 03 | Security groups, database (RDS), secrets | planned |
| 04 | Containers on ECS Fargate behind a load balancer | planned |
| 05 | Domain, HTTPS, CloudFront, WAF | planned |
| 06 | Scheduled jobs with EventBridge Scheduler | planned |
| 07 | Logs, metrics, alarms | planned |
| 08 | CI/CD with GitHub Actions | planned |
| 09 | Everything rebuilt from zero with Terraform | planned |

Each AWS step is built by hand in the console first, so we understand it, and then written as Terraform. Every step has its own branch and tag. See [docs/steps](docs/steps/README.md).

## Contributing

Read [CONTRIBUTING.md](CONTRIBUTING.md) for branch names and commit messages.
