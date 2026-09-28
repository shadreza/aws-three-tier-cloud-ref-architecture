# 0014. EventBridge Scheduler starts a fresh ECS task for each job run

- Status: Accepted
- Date: 2026-09-29

## Context

`check` must run every minute and `rollup` every hour. Locally, the `dev-scheduler` command runs both on timers inside one long-running container. On AWS we want each run to be visible on its own (did the 03:14 check run? how long did it take? what did it log?), a stuck run not to block the next ones forever, and no servers.

Both jobs are already safe to overlap and to repeat: they take a MySQL lock (`runLocked`) and write with upserts (step 01).

## Options

1. **EventBridge Scheduler, ECS RunTask target.** A managed cron: every minute it starts a new Fargate task from the `check` task definition. The first 14 million runs a month are free. Supports time zones and retries.
2. **EventBridge rules with a schedule.** The older way to do the same. No time zones, fewer options, and AWS points new work to Scheduler.
3. **`dev-scheduler` as an ECS service** (one task that never stops, with timers inside). About the same price: the one-minute Fargate minimum makes a task every minute cost about as much as a task that never stops (about $9 a month at 0.25 vCPU). But runs are just lines in one log stream, a hung run blocks that task's timer, and a deploy restarts the timers.
4. **Lambda.** Cheaper for short runs (roughly $1 to $2 a month for the checks), but the backend would need a second packaging (a Lambda handler), and it would still need the VPC and the NAT gateway to reach the database and the websites.

## Decision

EventBridge Scheduler, one schedule group per environment (`uptime-<env>`), two schedules:

| Schedule | Expression | Retries | Why |
|---|---|---|---|
| `check` | `rate(1 minute)` | 0 | the next run is a minute away |
| `rollup` | `rate(1 hour)` | 2, within an hour | it summarises yesterday and today, so any run catches up |

- Tasks run in the private subnets with the `jobs` security group and no public IP.
- The target is the task definition **without a revision number**, so each run uses the newest revision. A deploy (step 08) only applies the compute stack; the schedules never change.
- The scheduler's IAM role may only `RunTask` those two task definitions in our cluster, and may only pass the execution role and the jobs task role to ECS.
- `schedules_enabled = false` pauses both schedules in an environment without deleting anything.

## Consequences

- Every run is its own task, with its own log stream and exit code, visible in the ECS console and in CloudWatch (step 07).
- Fargate needs 20 to 60 seconds to start a task, so a check starts up to a minute after its scheduled time. For an uptime monitor with one-minute resolution that is fine.
- If a run is slow and the next one starts, the second one sees the lock and exits (`skipping run, previous one still going`).
- Cost: about $9 a month for the checks at 43,800 runs, plus about $0.15 for rollup. Scheduler itself is free at this volume.

## When we would change this

- Checks every few seconds, or thousands of monitors: move to a long-running worker service that pulls work from a queue.
- If the $9 a month matters more than one image for everything: a Lambda wrapper for `check`.
