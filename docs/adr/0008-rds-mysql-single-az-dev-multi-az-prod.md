# 0008. RDS for MySQL 8.4: single-AZ in dev, Multi-AZ in prod, TLS required

- Status: Accepted
- Date: 2026-09-29

## Context

The app uses MySQL through GORM (ADR 0003). Locally it runs the `mysql:8.4` image. On AWS we need a MySQL that someone else patches and backs up, that sits in the isolated subnets (ADR 0005), and that does not cost more than the rest of the app together in dev.

The check job writes to the database every minute, all day. The database is never idle.

## Options

1. **RDS for MySQL**, a single instance. `db.t4g.micro` (2 vCPU burst, 1 GB) costs about $0.025 an hour in Tokyo. Multi-AZ doubles the instance cost and keeps a standby in the second zone that takes over in one to two minutes.
2. **Aurora MySQL, provisioned.** Faster failover and storage that grows by itself, but the smallest instance (`db.t4g.medium`) costs about four times a `db.t4g.micro`, and storage I/O is billed separately.
3. **Aurora Serverless v2.** Scales with load, and can pause to zero when idle. Our check job connects every minute, so it would never pause, and a steady small load costs more than a micro instance.
4. **MySQL on EC2 or in a container.** Cheapest on paper. We would own patching, backups, failover and disk space. That is the work RDS exists to take away.
5. **Keep MySQL 8.0.** Standard support for RDS MySQL 8.0 ended in July 2026. Staying on it now costs an extended-support fee per vCPU-hour on top of the instance.

## Decision

RDS for MySQL **8.4** (the long-term release, same as local). Sizes come from `envs/<env>/data.tfvars`:

| | dev and staging | prod |
|---|---|---|
| instance | `db.t4g.micro` | `db.t4g.small` |
| Multi-AZ | no | yes |
| backups kept | 1 day | 7 days |
| deletion protection | off | on |
| final snapshot on destroy | no | yes |

In every environment:

- storage is gp3, encrypted, starts at 20 GB and grows by itself up to 100 GB
- a parameter group sets `require_secure_transport = 1`, so plain-text connections are refused even from inside the VPC
- the app checks the server certificate against the RDS CA bundle (`DB_TLS_CA`), so it cannot be fooled by something pretending to be the database
- error and slow query logs go to CloudWatch Logs
- backups run at 02:00 Tokyo time, maintenance on Monday at 03:00 Tokyo time

## Consequences

- A dev database costs about $21 a month, prod about $77. See [costs.md](../costs.md).
- In dev, a zone failure or a maintenance reboot means a few minutes without a database. The API keeps answering `/api/health`, and `/api/ready` reports the problem (step 01).
- `db.t4g` instances run on CPU credits. A long heavy load would slow them down. Watch `CPUCreditBalance` (step 07).
- Nobody can reach the database from a laptop. Use the debug host (`enable_debug_host`) or an ECS task.

## When we would change this

- If one instance cannot keep up with writes, or failover must be under 30 seconds: Aurora MySQL.
- If the check job moves to a queue and the database is idle most of the time: Aurora Serverless v2 with auto-pause.
- When MySQL 8.4 nears the end of standard support: plan the next major upgrade (blue/green deployment in RDS makes it one switch-over).
