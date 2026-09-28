# Workbooks

The step guides in [docs/steps](../steps/README.md) explain. The workbooks are what you **work through**: a checklist per phase, the exact commands in order with what you should see, blanks for the values you will need later, and a log of your sessions.

Open the guide and the workbook side by side. Tick a box when it is done, not when it is read.

| Step | Workbook | Guide | Terraform stacks |
|---|---|---|---|
| 01 | [the application](01-understand-the-application.md) | [guide](../steps/01-understand-the-application.md) | none |
| 02 | [AWS network](02-aws-network.md) | [guide](../steps/02-aws-network.md) | `bootstrap`, `network`, `security` |
| 03 | [database and secrets](03-database-and-secrets.md) | [guide](../steps/03-database-and-secrets.md) | `data` (+ debug host in `security`) |
| 04 | [containers on ECS](04-containers-on-ecs.md) | [guide](../steps/04-containers-on-ecs.md) | `registry`, `compute` |
| 05 | [CloudFront and WAF](05-cdn-and-waf.md) | [guide](../steps/05-cdn-and-waf.md) | `edge` |
| 06 | [scheduled jobs](06-scheduled-jobs.md) | [guide](../steps/06-scheduled-jobs.md) | `jobs` |
| 07 | [observability](07-observability.md) | [guide](../steps/07-observability.md) | `observability` |
| 08 | [CI/CD](08-ci-cd.md) | [guide](../steps/08-ci-cd.md) | `cicd` (+ OIDC in `bootstrap`) |
| 09 | [rebuild and replicate](09-rebuild-and-replicate.md) | [guide](../steps/09-rebuild-and-replicate.md) | all |

## How to use a workbook

1. **Copy it** before you start, so the original stays clean: `cp docs/workbook/02-aws-network.md ~/uptime-notes/02.md`. Or work on a personal branch and commit your filled-in copy there.
2. **Fill in the session log** every time you sit down and every time you stop. The "left running?" column is the one that saves money.
3. **Record the values** in the tables as you get them. Later steps ask for them.
4. **Write the answers in your own words** in the "Understand" phase before you look at the guide's answers.
5. **Stop at "Done when".** If a box there is not ticked, the step is not finished.

Every command that talks to AWS is marked **(AWS)**. You run those yourself. Nothing in this repo runs them for you.

## Terraform commands, the short version

Every stack uses the same five commands. `env` is `dev`, `staging` or `prod`; `stack` is the folder name in `terraform/stacks`.

```bash
make tf-plan    env=dev stack=network   # (AWS) show what would change, save the plan
make tf-apply   env=dev stack=network   # (AWS) apply exactly that saved plan
make tf-output  env=dev stack=network   # (AWS) show the outputs; add name=vpc_id for one raw value
make tf-destroy env=dev stack=network   # (AWS) delete everything in the stack, asks for yes
make tf-validate                        # offline: fmt check + validate every stack
```

Whole environments: `make tf-up env=dev stacks="network security"` and `make tf-down env=dev`. Order of stacks: `network security data registry compute edge jobs observability cicd`. Destroy in reverse.

The [runbook](../runbook.md) has the day-to-day operations once everything is built.
