# Runbook

How to operate Uptime on AWS once it is built (steps 02 to 08): everyday tasks, what to do when an alarm fires, and how to recover. Each procedure is a list of commands in order, with what you should see.

Every command here talks to AWS or GitHub. **You run them yourself**, logged in to the right account (`aws sts get-caller-identity`). Replace `dev` with the environment you are working on.

```bash
export ENV=dev                       # dev, staging or prod
export AWS_REGION=ap-northeast-1
export CLUSTER=uptime-$ENV SERVICE=uptime-$ENV-api
```

## Where things are

| Thing | Name |
|---|---|
| app URL | `make tf-output env=$ENV stack=edge name=url` |
| ECS cluster / API service | `uptime-$ENV` / `uptime-$ENV-api` |
| task definitions | `uptime-$ENV-api`, `uptime-$ENV-check`, `uptime-$ENV-rollup` |
| log groups | `/ecs/uptime-$ENV/api`, `/ecs/uptime-$ENV/jobs` |
| database | RDS `uptime-$ENV`, secret `uptime-$ENV/db` |
| admin token | secret `uptime-$ENV/admin-token` |
| image tag in use | SSM `/uptime-$ENV/image-tag` |
| reports | `s3://uptime-$ENV-reports-ACCOUNT/reports/` |
| schedules | group `uptime-$ENV`: `check`, `rollup` |
| alerts | SNS `uptime-$ENV-alerts`, dashboard `uptime-$ENV` |
| Terraform state | `s3://uptime-tfstate-ACCOUNT/$ENV/<stack>.tfstate` |

## Everyday tasks

### Which version is running?

```bash
aws ssm get-parameter --name /uptime-$ENV/image-tag --query Parameter.Value --output text
aws ecs describe-services --cluster $CLUSTER --services $SERVICE \
  --query 'services[0].deployments[].{status:status,taskDef:taskDefinition,running:runningCount,rollout:rolloutState}'
```

You should see one tag (a git commit) and one deployment `PRIMARY` with `rollout: COMPLETED`. Two deployments means a deploy is in progress.

### Deploy a new version

Normal way: merge a pull request to `master`. The `deploy` workflow does the rest (step 08). Watch it in **Actions**.

By hand (CI broken, or before step 08):

```bash
make image-push env=$ENV                   # prints the tag
make image-use  env=$ENV tag=<tag>
make tf-plan    env=$ENV stack=compute     # expect 3 task definitions replaced, the service updated
make tf-apply   env=$ENV stack=compute
aws ecs wait services-stable --cluster $CLUSTER --services $SERVICE
```

The `wait` returns with no output when the new tasks are healthy and the old ones are gone (a few minutes).

### Roll back

Pick the last good tag (from the previous deploy run, or `aws ecr describe-images --repository-name uptime-$ENV/backend --query 'sort_by(imageDetails,&imagePushedAt)[-5:].imageTags' --output text`), then:

```bash
make image-use env=$ENV tag=<good tag>
make tf-plan   env=$ENV stack=compute
make tf-apply  env=$ENV stack=compute
```

ECR keeps the newest 50 images. Older tags cannot be rolled back to.

If a deploy is still running and failing, the circuit breaker rolls back by itself within a few minutes. Check `rolloutState` above before doing anything.

### Run a one-off command

Any app command (`seed`, `check`, `rollup`, `migrate`) runs as a task from the rollup task definition with a different command:

```bash
NET=$(make -s tf-output env=$ENV stack=compute name=run_task_network)
aws ecs run-task --cluster $CLUSTER --launch-type FARGATE --task-definition uptime-$ENV-rollup \
  --network-configuration "$NET" \
  --overrides '{"containerOverrides":[{"name":"app","command":["check"]}]}' \
  --query 'tasks[0].taskArn' --output text
aws logs tail /ecs/uptime-$ENV/jobs --since 5m --format short
```

### Scale the API

Permanent: change `api_min_tasks` / `api_max_tasks` (and `api_cpu` / `api_memory`) in `terraform/envs/$ENV/compute.tfvars`, plan and apply `compute`.

Emergency, right now:

```bash
aws ecs update-service --cluster $CLUSTER --service $SERVICE --desired-count 3 --query 'service.desiredCount'
```

Terraform ignores `desired_count` (autoscaling owns it), so this stays until autoscaling or you change it. In prod autoscaling will not go below `api_min_tasks`.

### Pause and resume the jobs

```bash
# terraform/envs/$ENV/jobs.tfvars: schedules_enabled = false   (true to resume)
make tf-plan  env=$ENV stack=jobs
make tf-apply env=$ENV stack=jobs
```

`checks-stopped` fires about 10 minutes after pausing. That is expected.

### Park an environment overnight (save money)

What costs money while nobody looks, in dev: NAT gateway (~$1.60/day), RDS (~$0.70/day), load balancer (~$0.60/day), WAF (~$0.30/day), check tasks (~$0.30/day).

Park (in this order):

```bash
# 1. jobs off: schedules_enabled = false            -> tf-apply jobs
# 2. database stopped (keeps data, up to 7 days):
aws rds stop-db-instance --db-instance-identifier uptime-$ENV --query 'DBInstance.DBInstanceStatus'
# 3. optional, bigger saving: remove the NAT gateway: nat_gateway_mode = "none" -> tf-apply network
```

You should see `"stopping"` for the database. Unpark in reverse: `aws rds start-db-instance ...` (wait until `available`, about 5 minutes), NAT back to `single`, jobs back on. The NAT's public IP changes when it is recreated.

For a longer break, destroy the stacks instead (`make tf-down env=$ENV`); see step 09.

### Rotate the database password

```bash
# terraform/envs/$ENV/data.tfvars: db_password_version = <current + 1>
make tf-plan  env=$ENV stack=data         # the instance and the secret version change
make tf-apply env=$ENV stack=data
aws ecs update-service --cluster $CLUSTER --service $SERVICE --force-new-deployment --query 'service.serviceName'
```

Between the apply and the new tasks, running API tasks cannot open new connections (existing ones keep working). Scheduled jobs pick up the new password on their next run. Do it at a quiet time.

### Rotate the admin token

```bash
# terraform/envs/$ENV/data.tfvars: admin_token_version = <current + 1>
make tf-plan  env=$ENV stack=data
make tf-apply env=$ENV stack=data
aws ecs update-service --cluster $CLUSTER --service $SERVICE --force-new-deployment --query 'service.serviceName'
aws secretsmanager get-secret-value --secret-id uptime-$ENV/admin-token --query SecretString --output text
```

Give the new token to whoever manages monitors.

### Look inside: logs, database

```bash
aws logs tail /ecs/uptime-$ENV/api  --since 30m --format short     # API requests and errors
aws logs tail /ecs/uptime-$ENV/jobs --since 30m --format short     # check and rollup runs
```

Saved queries: **CloudWatch, Logs Insights, Saved queries**, folder `uptime-$ENV` (slowest requests, errors, check runs per hour).

Database: set `enable_debug_host = true` in `envs/$ENV/security.tfvars`, apply `security`, then:

```bash
aws ec2-instance-connect ssh --instance-id $(make -s tf-output env=$ENV stack=security name=debug_host_instance_id) --connection-type eice
# on the host:
mysql -h <db_address> -u uptime -p --ssl-ca=rds-ca.pem --ssl-verify-server-cert uptime
```

Turn the debug host off afterwards.

## When an alarm fires

Every alarm email names the alarm. Find it below. First, always:

1. Open the dashboard (`make tf-output env=$ENV stack=observability name=dashboard_url`).
2. Check whether a deploy just happened (**Actions**, or "Which version is running?" above).
3. Write down the time. It is the first line of the incident notes.

### `api-no-healthy-tasks`: the app is down

1. `aws ecs describe-services --cluster $CLUSTER --services $SERVICE --query 'services[0].{running:runningCount,desired:desiredCount,events:events[:5].message}'`
2. If `desired` is 0: someone scaled it down. Set it back (Scale the API).
3. If tasks keep stopping: `aws ecs list-tasks --cluster $CLUSTER --service-name $SERVICE --desired-status STOPPED --query 'taskArns[:3]'`, then `aws ecs describe-tasks --cluster $CLUSTER --tasks <arn> --query 'tasks[0].{reason:stoppedReason,containers:containers[].{name:name,exit:exitCode,reason:reason}}'`.
4. Stopped reasons and fixes:

| Reason | Fix |
|---|---|
| `CannotPullContainerError` | image tag missing in ECR, or no route to ECR (NAT). Roll back or fix the network. |
| `ResourceInitializationError: unable to pull secrets` | execution role policy or secret ARN. Apply `compute`. |
| `migrate` exit code 1 | database down, password rotated without restart, or a bad migration. Read `/ecs/uptime-$ENV/api`. |
| `Task failed ELB health checks` | app not answering `/api/health` on 8080, or `app` security group lost the `alb` rule. Apply `security`. |

### `alb-5xx` or `api-5xx`: users see errors

1. `api-5xx` (the app answered 5xx): run the `errors` saved query. Usually the database (`/api/ready` fails too) or a bad deploy. Roll back if it started with a deploy.
2. `alb-5xx` (the load balancer answered): `502` means a task closed the connection, `503` no healthy target, `504` a task too slow. Check healthy host count, then the API logs.

### `api-slow`: p95 over 1 second

1. `slowest-api-requests` saved query: which paths?
2. Database CPU and connections on the dashboard. If high, see `db-cpu-high`.
3. API CPU on the dashboard. If near 100% and prod: raise `api_max_tasks`. In dev: raise `api_cpu`.

### `db-cpu-high`, `db-cpu-credits-low`

1. Credits low while CPU looks moderate: the `t4g` instance is out of burst credits and is being throttled. Short term: nothing breaks, it is slow. Fix: a bigger class in `data.tfvars` (`db_instance_class`), applied at a quiet time (the instance restarts; Multi-AZ fails over first).
2. CPU high: slow query log (`/aws/rds/instance/uptime-$ENV/slowquery`). The monitors table and check results grow with retention; `RETENTION_DAYS` (compute) limits raw results.

### `db-storage-low`

Storage grows by itself up to `max_allocated_storage` (100 GB, an input of `modules/rds-mysql`). If you are near that: pass a bigger value from `stacks/data/main.tf` (add a variable for it in `data.tfvars`), or lower `retention_days` in `compute.tfvars` so rollup deletes more raw results.

### `scheduler-errors`

The scheduler could not start a task. Usually IAM (the scheduler role) or a task definition problem.

1. **EventBridge, Scheduler, schedules, `check`**: last invocation errors.
2. Try the same task by hand (Run a one-off command). If that fails too, the task definition or network is the problem, not the scheduler.
3. Re-apply `jobs` to restore the role.

### `checks-stopped`: no check finished in 10 minutes

The catch-all. Go down the chain:

1. Schedules enabled? `aws scheduler get-schedule --group-name uptime-$ENV --name check --query State`
2. Tasks starting? `aws ecs list-tasks --cluster $CLUSTER --family uptime-$ENV-check --desired-status STOPPED --query 'length(taskArns)'` (should grow every minute)
3. Tasks failing? Stopped reason of the newest one (see the table under `api-no-healthy-tasks`).
4. Tasks running but no `check finished`? `aws logs tail /ecs/uptime-$ENV/jobs --since 15m`: `skipping run` every time means one run is stuck holding the lock; stop the old RUNNING check task.
5. Someone changed the `check finished` log message? Then the metric filter no longer matches; fix the filter with the code.

### `app-errors`

`errors` saved query. Group by message. A burst after a deploy: roll back. Steady errors about the database: see the database alarms.

### WAF blocking real users (no alarm, a user complains)

1. **WAF & Shield, Web ACLs (Global), `uptime-$ENV`, Sampled requests**: find the request and the rule.
2. Switch that rule to **Count** in the console to stop the blocking, then fix it in `terraform/modules/waf-cloudfront` (a rule override) and apply `edge`. The console change is drift; the next `edge` apply puts Block back unless the code changed.

## Recovery

### Restore the database to a point in time

Backups: 1 day in dev, 7 days in prod. Restore always makes a **new** instance:

```bash
aws rds restore-db-instance-to-point-in-time \
  --source-db-instance-identifier uptime-$ENV \
  --target-db-instance-identifier uptime-$ENV-restore \
  --restore-time 2026-10-01T03:00:00Z \
  --db-subnet-group-name uptime-$ENV \
  --vpc-security-group-ids $(make -s tf-output env=$ENV stack=security name=db_sg_id) \
  --db-parameter-group-name uptime-$ENV-mysql84 \
  --no-publicly-accessible
aws rds wait db-instance-available --db-instance-identifier uptime-$ENV-restore
```

Connect to `uptime-$ENV-restore` from the debug host and copy back what was lost. Pointing the app at the restored instance for good is a planned change (the `data` stack owns `uptime-$ENV`): do it with a second person, and write down each step. Delete the restore instance when done; it costs as much as the original.

### A zone fails

- prod: two NAT gateways, Multi-AZ RDS, tasks in both zones. RDS fails over by itself (1 to 2 minutes, same address); ECS starts replacement tasks in the healthy zone. Watch; do nothing unless an alarm stays on.
- dev and staging: one NAT gateway. If zone `1a` fails, checks stop everywhere until it returns. Accepted (ADR 0006).

### Terraform state problems

| Problem | Fix |
|---|---|
| `Error acquiring the state lock` and nobody else is running Terraform | a crashed run left `<key>.tflock` in the state bucket. Confirm no job is running, then `aws s3 rm s3://uptime-tfstate-ACCOUNT/$ENV/<stack>.tfstate.tflock` |
| a bad apply corrupted state | the bucket is versioned: `aws s3api list-object-versions --bucket uptime-tfstate-ACCOUNT --prefix $ENV/<stack>.tfstate`, then copy the good version back over the current one |
| someone changed things in the console | `make tf-plan` shows the drift; apply to put the code's version back, or change the code |

### Rebuild an environment from zero

Step 09, section 5: `make tf-up` for the foundation stacks, push and choose an image, `make tf-up` for the rest, `make web-deploy`. About 30 to 40 minutes. Data comes back only from backups.

## Costs look wrong

1. **Billing, Cost Explorer**, group by **Tag: Environment**, then **Service**.
2. The usual suspects: a forgotten environment (`aws ec2 describe-nat-gateways --filter Name=state,Values=available`), an unattached Elastic IP (`aws ec2 describe-addresses`), a restore instance left over (`aws rds describe-db-instances --query 'DBInstances[].DBInstanceIdentifier'`), NAT data processing (big `NatGateway-Bytes` line: something pulls a lot through NAT; check the S3 endpoint exists).
3. Compare with [costs.md](costs.md).
